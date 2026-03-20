//// Runtime: the Elm architecture update loop.
////
//// Owns the app model, executes init/update/view, diffs trees,
//// and sends patches to the bridge. Commands returned from update
//// are executed before the next view render.

import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import toddy/app.{type App}
import toddy/bridge.{
  type BridgeMessage, type RuntimeNotification, InboundEvent, RendererExited,
  Send,
}
import toddy/command.{type Command}
import toddy/event.{type Event}
import toddy/ffi
import toddy/node.{
  type Node, type PropValue, BoolVal, FloatVal, IntVal, StringVal,
}
import toddy/protocol
import toddy/protocol/decode.{EventMessage, Hello}
import toddy/protocol/encode
import toddy/subscription.{type Subscription}
import toddy/tree

// -- Public types ------------------------------------------------------------

/// Messages handled by the runtime.
pub type RuntimeMessage {
  /// Notification from the bridge.
  FromBridge(RuntimeNotification)
  /// Internal event dispatch (SendAfter, Done, timer).
  InternalEvent(Event)
  /// Subscription timer fired.
  TimerFired(tag: String)
  /// Shutdown.
  Shutdown
}

/// Start options for the runtime.
pub type RuntimeOpts {
  RuntimeOpts(format: protocol.Format, session: String, daemon: Bool)
}

/// Default runtime options.
pub fn default_opts() -> RuntimeOpts {
  RuntimeOpts(format: protocol.Msgpack, session: "", daemon: False)
}

/// Start the runtime as a linked process.
///
/// Spawns a child process that:
/// 1. Creates its own Subjects (for correct message ownership)
/// 2. Starts the bridge actor
/// 3. Initializes the app (init -> view -> snapshot)
/// 4. Enters the message loop
///
/// Returns `Ok(runtime_subject)` on success, or an error if bridge
/// startup fails or times out (5 second deadline).
pub fn start(
  app: App(model, Event),
  binary_path: String,
  opts: RuntimeOpts,
) -> Result(Subject(RuntimeMessage), StartError) {
  // Channel for the spawned process to report back its Subject
  let init_channel = process.new_subject()

  process.spawn(fn() {
    // Create Subjects inside this process so we own them and can
    // receive messages delivered to them.
    let runtime_subject = process.new_subject()
    let notification_subject = process.new_subject()

    // Start bridge actor with our notification subject
    case
      bridge.start(binary_path, opts.format, notification_subject, opts.session)
    {
      Ok(bridge_subject) -> {
        // Report success to parent
        process.send(init_channel, Ok(runtime_subject))
        // Run the app
        run(app, bridge_subject, runtime_subject, notification_subject, opts)
      }
      Error(err) -> {
        process.send(init_channel, Error(BridgeStartFailed(err)))
      }
    }
  })

  // Wait for the spawned process to report back (5s timeout)
  case process.receive(init_channel, 5000) {
    Ok(result) -> result
    Error(Nil) -> Error(StartTimeout)
  }
}

/// Errors that can occur when starting the runtime.
pub type StartError {
  /// The bridge actor failed to start.
  BridgeStartFailed(actor.StartError)
  /// Startup timed out (bridge or init took too long).
  StartTimeout
}

import gleam/otp/actor

// -- Internal state ----------------------------------------------------------

type LoopState(model) {
  LoopState(
    app: App(model, Event),
    model: model,
    bridge: Subject(BridgeMessage),
    self: Subject(RuntimeMessage),
    notifications: Subject(RuntimeNotification),
    tree: Option(Node),
    active_subs: Dict(String, SubEntry),
    windows: Set(String),
    opts: RuntimeOpts,
    errors: Int,
  )
}

type SubEntry {
  TimerSub(timer: process.Timer, interval_ms: Int, tag: String)
  RendererSub(kind: String)
}

// -- Process entry point -----------------------------------------------------

fn run(
  app: App(model, Event),
  bridge: Subject(BridgeMessage),
  self: Subject(RuntimeMessage),
  notifications: Subject(RuntimeNotification),
  opts: RuntimeOpts,
) -> Nil {
  // Initialize
  let #(model, init_cmds) = app.get_init(app)()

  // Send settings to bridge
  let settings = app.get_settings(app)()
  send_encoded(
    bridge,
    encode.encode_settings(settings, opts.session, opts.format),
  )

  // Render initial view
  let initial_tree = app.get_view(app)(model) |> tree.normalize()

  // Send initial snapshot
  send_encoded(
    bridge,
    encode.encode_snapshot(initial_tree, opts.session, opts.format),
  )

  // Execute init commands
  let model = execute_commands(init_cmds, model, app, bridge, self, opts)

  // Sync subscriptions
  let active_subs =
    sync_subscriptions(
      app.get_subscribe(app)(model),
      dict.new(),
      bridge,
      self,
      opts,
    )

  // Enter message loop
  let state =
    LoopState(
      app:,
      model:,
      bridge:,
      self:,
      notifications:,
      tree: Some(initial_tree),
      active_subs:,
      windows: detect_windows(initial_tree),
      opts:,
      errors: 0,
    )

  message_loop(state)
}

// -- Message loop ------------------------------------------------------------

fn message_loop(state: LoopState(model)) -> Nil {
  let selector =
    process.new_selector()
    |> process.select(state.self)
    |> process.select_map(state.notifications, FromBridge)

  let msg = process.selector_receive_forever(selector)

  case msg {
    FromBridge(InboundEvent(EventMessage(event))) -> {
      handle_event(state, event) |> message_loop()
    }

    FromBridge(InboundEvent(Hello(protocol: proto, ..))) -> {
      case proto == protocol.protocol_version {
        True -> Nil
        False ->
          io.println(
            "toddy: protocol version mismatch (expected "
            <> int.to_string(protocol.protocol_version)
            <> ", got "
            <> int.to_string(proto)
            <> ")",
          )
      }
      message_loop(state)
    }

    FromBridge(RendererExited(status:)) -> {
      // Check for app-level handler
      case app.get_on_renderer_exit(state.app) {
        Some(handler) -> {
          let new_model = handler(state.model, dynamic.int(status))
          message_loop(LoopState(..state, model: new_model))
        }
        None -> {
          case status {
            0 -> Nil
            _ ->
              io.println(
                "toddy: renderer exited with status " <> int.to_string(status),
              )
          }
          // Renderer is gone -- stop the loop
          Nil
        }
      }
    }

    InternalEvent(event) -> {
      handle_event(state, event) |> message_loop()
    }

    TimerFired(tag:) -> {
      let timestamp = erlang_monotonic_time()
      let new_state = handle_event(state, event.TimerTick(tag:, timestamp:))
      reschedule_timer(new_state, tag) |> message_loop()
    }

    Shutdown -> {
      // Cancel all subscription timers
      dict.each(state.active_subs, fn(_key, entry) {
        case entry {
          TimerSub(timer:, ..) -> {
            process.cancel_timer(timer)
            Nil
          }
          _ -> Nil
        }
      })
      Nil
    }
  }
}

@external(erlang, "erlang", "monotonic_time")
fn erlang_monotonic_time() -> Int

// -- Event handling (the core update cycle) ----------------------------------

fn handle_event(state: LoopState(model), event: Event) -> LoopState(model) {
  let update_fn = app.get_update(state.app)

  case ffi.try_call(fn() { update_fn(state.model, event) }) {
    Ok(#(new_model, commands)) -> {
      // Execute commands (before view, matching Elixir SDK)
      let new_model =
        execute_commands(
          commands,
          new_model,
          state.app,
          state.bridge,
          state.self,
          state.opts,
        )

      // Render view
      let view_fn = app.get_view(state.app)
      case ffi.try_call(fn() { view_fn(new_model) }) {
        Ok(new_tree_raw) -> {
          let new_tree = tree.normalize(new_tree_raw)

          // Diff and send patch
          case state.tree {
            Some(old_tree) -> {
              let ops = tree.diff(old_tree, new_tree)
              case ops {
                [] -> Nil
                _ ->
                  send_encoded(
                    state.bridge,
                    encode.encode_patch(
                      ops,
                      state.opts.session,
                      state.opts.format,
                    ),
                  )
              }
            }
            None ->
              send_encoded(
                state.bridge,
                encode.encode_snapshot(
                  new_tree,
                  state.opts.session,
                  state.opts.format,
                ),
              )
          }

          // Sync subscriptions
          let new_subs =
            sync_subscriptions(
              app.get_subscribe(state.app)(new_model),
              state.active_subs,
              state.bridge,
              state.self,
              state.opts,
            )

          let new_windows = detect_windows(new_tree)

          LoopState(
            ..state,
            model: new_model,
            tree: Some(new_tree),
            active_subs: new_subs,
            windows: new_windows,
            errors: 0,
          )
        }
        Error(reason) -> {
          let err_count = state.errors + 1
          case err_count <= 10 {
            True ->
              io.println("toddy: view error: " <> dynamic.classify(reason))
            False -> Nil
          }
          LoopState(..state, model: new_model, errors: err_count)
        }
      }
    }
    Error(reason) -> {
      let err_count = state.errors + 1
      case err_count <= 10 {
        True -> io.println("toddy: update error: " <> dynamic.classify(reason))
        False -> Nil
      }
      LoopState(..state, errors: err_count)
    }
  }
}

// -- Command execution -------------------------------------------------------

fn execute_commands(
  cmd: Command(Event),
  model: model,
  app: App(model, Event),
  bridge: Subject(BridgeMessage),
  self: Subject(RuntimeMessage),
  opts: RuntimeOpts,
) -> model {
  case cmd {
    command.None -> model

    command.Batch(commands:) ->
      list.fold(commands, model, fn(m, c) {
        execute_commands(c, m, app, bridge, self, opts)
      })

    command.Exit -> {
      process.send(self, Shutdown)
      model
    }

    command.SendAfter(delay_ms:, msg:) -> {
      process.send_after(self, delay_ms, InternalEvent(msg))
      model
    }

    command.Done(value:, mapper:) -> {
      let event = mapper(value)
      process.send(self, InternalEvent(event))
      model
    }

    command.Focus(widget_id:) -> {
      send_widget_op(bridge, "focus", [#("target", StringVal(widget_id))], opts)
      model
    }

    command.FocusNext -> {
      send_widget_op(bridge, "focus_next", [], opts)
      model
    }

    command.FocusPrevious -> {
      send_widget_op(bridge, "focus_previous", [], opts)
      model
    }

    command.SelectAll(widget_id:) -> {
      send_widget_op(
        bridge,
        "select_all",
        [#("target", StringVal(widget_id))],
        opts,
      )
      model
    }

    command.MoveCursorToFront(widget_id:) -> {
      send_widget_op(
        bridge,
        "move_cursor_to_front",
        [#("target", StringVal(widget_id))],
        opts,
      )
      model
    }

    command.MoveCursorToEnd(widget_id:) -> {
      send_widget_op(
        bridge,
        "move_cursor_to_end",
        [#("target", StringVal(widget_id))],
        opts,
      )
      model
    }

    command.MoveCursorTo(widget_id:, position:) -> {
      send_widget_op(
        bridge,
        "move_cursor_to",
        [
          #("target", StringVal(widget_id)),
          #("position", IntVal(position)),
        ],
        opts,
      )
      model
    }

    command.SelectRange(widget_id:, start:, end:) -> {
      send_widget_op(
        bridge,
        "select_range",
        [
          #("target", StringVal(widget_id)),
          #("start", IntVal(start)),
          #("end", IntVal(end)),
        ],
        opts,
      )
      model
    }

    command.ScrollTo(widget_id:, offset: _) -> {
      send_widget_op(
        bridge,
        "scroll_to",
        [#("target", StringVal(widget_id))],
        opts,
      )
      model
    }

    command.SnapTo(widget_id:, x:, y:) -> {
      send_widget_op(
        bridge,
        "snap_to",
        [
          #("target", StringVal(widget_id)),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
        ],
        opts,
      )
      model
    }

    command.SnapToEnd(widget_id:) -> {
      send_widget_op(
        bridge,
        "snap_to_end",
        [#("target", StringVal(widget_id))],
        opts,
      )
      model
    }

    command.ScrollBy(widget_id:, x:, y:) -> {
      send_widget_op(
        bridge,
        "scroll_by",
        [
          #("target", StringVal(widget_id)),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
        ],
        opts,
      )
      model
    }

    command.CloseWindow(window_id:) -> {
      send_window_op(bridge, "close", window_id, [], opts)
      model
    }

    command.ResizeWindow(window_id:, width:, height:) -> {
      send_window_op(
        bridge,
        "resize",
        window_id,
        [#("width", FloatVal(width)), #("height", FloatVal(height))],
        opts,
      )
      model
    }

    command.MoveWindow(window_id:, x:, y:) -> {
      send_window_op(
        bridge,
        "move",
        window_id,
        [#("x", FloatVal(x)), #("y", FloatVal(y))],
        opts,
      )
      model
    }

    command.MaximizeWindow(window_id:, maximized:) -> {
      send_window_op(
        bridge,
        "maximize",
        window_id,
        [#("maximized", BoolVal(maximized))],
        opts,
      )
      model
    }

    command.MinimizeWindow(window_id:, minimized:) -> {
      send_window_op(
        bridge,
        "minimize",
        window_id,
        [#("minimized", BoolVal(minimized))],
        opts,
      )
      model
    }

    command.SetWindowMode(window_id:, mode:) -> {
      send_window_op(
        bridge,
        "set_mode",
        window_id,
        [#("mode", StringVal(mode))],
        opts,
      )
      model
    }

    command.ToggleMaximize(window_id:) -> {
      send_window_op(bridge, "toggle_maximize", window_id, [], opts)
      model
    }

    command.ToggleDecorations(window_id:) -> {
      send_window_op(bridge, "toggle_decorations", window_id, [], opts)
      model
    }

    command.GainFocus(window_id:) -> {
      send_window_op(bridge, "gain_focus", window_id, [], opts)
      model
    }

    command.SetWindowLevel(window_id:, level:) -> {
      send_window_op(
        bridge,
        "set_level",
        window_id,
        [#("level", StringVal(level))],
        opts,
      )
      model
    }

    command.DragWindow(window_id:) -> {
      send_window_op(bridge, "drag", window_id, [], opts)
      model
    }

    command.DragResizeWindow(window_id:, direction:) -> {
      send_window_op(
        bridge,
        "drag_resize",
        window_id,
        [#("direction", StringVal(direction))],
        opts,
      )
      model
    }

    command.RequestUserAttention(window_id:, urgency:) -> {
      let payload = case urgency {
        option.Some(u) -> [#("urgency", StringVal(u))]
        option.None -> []
      }
      send_window_op(bridge, "request_user_attention", window_id, payload, opts)
      model
    }

    command.Screenshot(window_id:, tag:) -> {
      send_window_op(
        bridge,
        "screenshot",
        window_id,
        [#("tag", StringVal(tag))],
        opts,
      )
      model
    }

    command.SetResizable(window_id:, resizable:) -> {
      send_window_op(
        bridge,
        "set_resizable",
        window_id,
        [#("resizable", BoolVal(resizable))],
        opts,
      )
      model
    }

    command.SetMinSize(window_id:, width:, height:) -> {
      send_window_op(
        bridge,
        "set_min_size",
        window_id,
        [#("width", FloatVal(width)), #("height", FloatVal(height))],
        opts,
      )
      model
    }

    command.SetMaxSize(window_id:, width:, height:) -> {
      send_window_op(
        bridge,
        "set_max_size",
        window_id,
        [#("width", FloatVal(width)), #("height", FloatVal(height))],
        opts,
      )
      model
    }

    command.EnableMousePassthrough(window_id:) -> {
      send_window_op(bridge, "enable_mouse_passthrough", window_id, [], opts)
      model
    }

    command.DisableMousePassthrough(window_id:) -> {
      send_window_op(bridge, "disable_mouse_passthrough", window_id, [], opts)
      model
    }

    command.ShowSystemMenu(window_id:) -> {
      send_window_op(bridge, "show_system_menu", window_id, [], opts)
      model
    }

    command.SetResizeIncrements(window_id:, width:, height:) -> {
      let payload = case width, height {
        option.Some(w), option.Some(h) -> [
          #("width", FloatVal(w)),
          #("height", FloatVal(h)),
        ]
        option.Some(w), option.None -> [#("width", FloatVal(w))]
        option.None, option.Some(h) -> [#("height", FloatVal(h))]
        option.None, option.None -> []
      }
      send_window_op(bridge, "set_resize_increments", window_id, payload, opts)
      model
    }

    command.AllowAutomaticTabbing(enabled:) -> {
      send_widget_op(
        bridge,
        "allow_automatic_tabbing",
        [#("enabled", BoolVal(enabled))],
        opts,
      )
      model
    }

    command.SetIcon(window_id:, rgba_data: _, width: _, height: _) -> {
      // Icon data requires binary encoding -- future work
      let _ = window_id
      model
    }

    command.GetWindowSize(window_id:, tag:) -> {
      send_window_query(bridge, "get_size", window_id, tag, opts)
      model
    }

    command.GetWindowPosition(window_id:, tag:) -> {
      send_window_query(bridge, "get_position", window_id, tag, opts)
      model
    }

    command.IsMaximized(window_id:, tag:) -> {
      send_window_query(bridge, "is_maximized", window_id, tag, opts)
      model
    }

    command.IsMinimized(window_id:, tag:) -> {
      send_window_query(bridge, "is_minimized", window_id, tag, opts)
      model
    }

    command.GetMode(window_id:, tag:) -> {
      send_window_query(bridge, "get_mode", window_id, tag, opts)
      model
    }

    command.GetScaleFactor(window_id:, tag:) -> {
      send_window_query(bridge, "get_scale_factor", window_id, tag, opts)
      model
    }

    command.RawWindowId(window_id:, tag:) -> {
      send_window_query(bridge, "raw_id", window_id, tag, opts)
      model
    }

    command.MonitorSize(window_id:, tag:) -> {
      send_window_query(bridge, "monitor_size", window_id, tag, opts)
      model
    }

    command.GetSystemTheme(tag:) -> {
      send_window_query(bridge, "get_system_theme", "_system", tag, opts)
      model
    }

    command.GetSystemInfo(tag:) -> {
      send_window_query(bridge, "get_system_info", "_system", tag, opts)
      model
    }

    command.Announce(text:) -> {
      send_widget_op(bridge, "announce", [#("text", StringVal(text))], opts)
      model
    }

    command.AdvanceFrame(timestamp:) -> {
      send_encoded(
        bridge,
        encode.encode_advance_frame(timestamp, opts.session, opts.format),
      )
      model
    }

    command.Effect(id:, kind:, payload:) -> {
      send_encoded(
        bridge,
        encode.encode_effect(id, kind, payload, opts.session, opts.format),
      )
      model
    }

    command.ExtensionCommand(node_id:, op:, payload:) -> {
      send_encoded(
        bridge,
        encode.encode_extension_command(
          node_id,
          op,
          payload,
          opts.session,
          opts.format,
        ),
      )
      model
    }

    command.ExtensionCommands(commands:) -> {
      list.each(commands, fn(cmd_tuple) {
        let #(node_id, op, payload) = cmd_tuple
        send_encoded(
          bridge,
          encode.encode_extension_command(
            node_id,
            op,
            payload,
            opts.session,
            opts.format,
          ),
        )
      })
      model
    }

    command.CreateImage(handle:, data:) -> {
      send_image_op(
        bridge,
        "create",
        [
          #("handle", StringVal(handle)),
          #("data", StringVal(encode_base64(data))),
        ],
        opts,
      )
      model
    }

    command.CreateImageRgba(handle:, width:, height:, pixels:) -> {
      send_image_op(
        bridge,
        "create_rgba",
        [
          #("handle", StringVal(handle)),
          #("width", IntVal(width)),
          #("height", IntVal(height)),
          #("pixels", StringVal(encode_base64(pixels))),
        ],
        opts,
      )
      model
    }

    command.UpdateImage(handle:, data:) -> {
      send_image_op(
        bridge,
        "update",
        [
          #("handle", StringVal(handle)),
          #("data", StringVal(encode_base64(data))),
        ],
        opts,
      )
      model
    }

    command.UpdateImageRgba(handle:, width:, height:, pixels:) -> {
      send_image_op(
        bridge,
        "update_rgba",
        [
          #("handle", StringVal(handle)),
          #("width", IntVal(width)),
          #("height", IntVal(height)),
          #("pixels", StringVal(encode_base64(pixels))),
        ],
        opts,
      )
      model
    }

    command.DeleteImage(handle:) -> {
      send_image_op(bridge, "delete", [#("handle", StringVal(handle))], opts)
      model
    }

    command.ListImages(tag:) -> {
      send_image_op(bridge, "list", [#("tag", StringVal(tag))], opts)
      model
    }

    command.ClearImages -> {
      send_image_op(bridge, "clear", [], opts)
      model
    }

    command.TreeHashQuery(tag:) -> {
      send_widget_op(bridge, "tree_hash", [#("tag", StringVal(tag))], opts)
      model
    }

    command.FindFocused(tag:) -> {
      send_widget_op(bridge, "find_focused", [#("tag", StringVal(tag))], opts)
      model
    }

    command.LoadFont(data: _) -> {
      // Font loading requires binary encoding -- future work
      model
    }

    command.PaneSplit(pane_grid_id: _, pane_id: _, axis: _, new_pane_id: _) -> {
      // Pane operations use Dynamic pane IDs -- future work
      model
    }

    command.PaneClose(pane_grid_id: _, pane_id: _) -> model

    command.PaneSwap(pane_grid_id: _, pane_a: _, pane_b: _) -> model

    command.PaneMaximize(pane_grid_id: _, pane_id: _) -> model

    command.PaneRestore(pane_grid_id: _) -> model

    command.Async(work: _, tag: _) -> {
      // Async task spawning -- future work
      model
    }

    command.Stream(work: _, tag: _) -> {
      // Stream task spawning -- future work
      model
    }

    command.Cancel(tag: _) -> {
      // Task cancellation -- future work
      model
    }
  }
}

// -- Wire helpers ------------------------------------------------------------

fn send_encoded(
  bridge: Subject(BridgeMessage),
  result: Result(BitArray, protocol.EncodeError),
) -> Nil {
  case result {
    Ok(bytes) -> process.send(bridge, Send(data: bytes))
    Error(_) -> Nil
  }
}

fn send_widget_op(
  bridge: Subject(BridgeMessage),
  op: String,
  payload: List(#(String, PropValue)),
  opts: RuntimeOpts,
) -> Nil {
  send_encoded(
    bridge,
    encode.encode_widget_op(
      op,
      dict.from_list(payload),
      opts.session,
      opts.format,
    ),
  )
}

fn send_window_op(
  bridge: Subject(BridgeMessage),
  op: String,
  window_id: String,
  settings: List(#(String, PropValue)),
  opts: RuntimeOpts,
) -> Nil {
  send_encoded(
    bridge,
    encode.encode_window_op(
      op,
      window_id,
      dict.from_list(settings),
      opts.session,
      opts.format,
    ),
  )
}

/// Window queries are sent as window_op with an op name and tag.
/// Results arrive as op_query_response events.
fn send_window_query(
  bridge: Subject(BridgeMessage),
  op: String,
  window_id: String,
  tag: String,
  opts: RuntimeOpts,
) -> Nil {
  send_encoded(
    bridge,
    encode.encode_window_op(
      op,
      window_id,
      dict.from_list([#("tag", StringVal(tag))]),
      opts.session,
      opts.format,
    ),
  )
}

fn send_image_op(
  bridge: Subject(BridgeMessage),
  op: String,
  payload: List(#(String, PropValue)),
  opts: RuntimeOpts,
) -> Nil {
  send_encoded(
    bridge,
    encode.encode_image_op(
      op,
      dict.from_list(payload),
      opts.session,
      opts.format,
    ),
  )
}

@external(erlang, "base64", "encode")
fn encode_base64(data: BitArray) -> String

// -- Subscription management -------------------------------------------------

fn sync_subscriptions(
  desired: List(Subscription),
  current: Dict(String, SubEntry),
  bridge: Subject(BridgeMessage),
  self: Subject(RuntimeMessage),
  opts: RuntimeOpts,
) -> Dict(String, SubEntry) {
  let desired_by_key =
    list.fold(desired, dict.new(), fn(acc, sub) {
      let k = subscription_key_string(sub)
      dict.insert(acc, k, sub)
    })

  // Stop removed subscriptions
  let current =
    dict.fold(current, current, fn(acc, key, entry) {
      case dict.has_key(desired_by_key, key) {
        True -> acc
        False -> {
          stop_subscription(entry, bridge, opts)
          dict.delete(acc, key)
        }
      }
    })

  // Start new subscriptions
  dict.fold(desired_by_key, current, fn(acc, key, sub) {
    case dict.has_key(acc, key) {
      True -> acc
      False -> {
        let entry = start_subscription(sub, bridge, self, opts)
        dict.insert(acc, key, entry)
      }
    }
  })
}

fn subscription_key_string(sub: Subscription) -> String {
  let key = subscription.key(sub)
  case key {
    subscription.TimerKey(interval_ms:, tag:) ->
      "timer:" <> int.to_string(interval_ms) <> ":" <> tag
    subscription.RendererKey(kind:, tag:) -> "renderer:" <> kind <> ":" <> tag
  }
}

fn start_subscription(
  sub: Subscription,
  bridge: Subject(BridgeMessage),
  self: Subject(RuntimeMessage),
  opts: RuntimeOpts,
) -> SubEntry {
  case sub {
    subscription.Every(interval_ms:, tag:) -> {
      let timer = process.send_after(self, interval_ms, TimerFired(tag:))
      TimerSub(timer:, interval_ms:, tag:)
    }
    _ -> {
      let kind = subscription.wire_kind(sub)
      let tag = subscription.tag(sub)
      send_encoded(
        bridge,
        encode.encode_subscribe(kind, tag, opts.session, opts.format),
      )
      RendererSub(kind:)
    }
  }
}

fn stop_subscription(
  entry: SubEntry,
  bridge: Subject(BridgeMessage),
  opts: RuntimeOpts,
) -> Nil {
  case entry {
    TimerSub(timer:, ..) -> {
      process.cancel_timer(timer)
      Nil
    }
    RendererSub(kind:) -> {
      send_encoded(
        bridge,
        encode.encode_unsubscribe(kind, opts.session, opts.format),
      )
    }
  }
}

/// Reschedule a timer subscription after it fires.
/// Matches by the tag stored in the SubEntry (not string matching).
fn reschedule_timer(state: LoopState(model), tag: String) -> LoopState(model) {
  let new_subs =
    dict.fold(state.active_subs, state.active_subs, fn(acc, key, entry) {
      case entry {
        TimerSub(interval_ms:, tag: entry_tag, ..) if entry_tag == tag -> {
          let new_timer =
            process.send_after(state.self, interval_ms, TimerFired(tag:))
          dict.insert(acc, key, TimerSub(timer: new_timer, interval_ms:, tag:))
        }
        _ -> acc
      }
    })
  LoopState(..state, active_subs: new_subs)
}

// -- Window detection --------------------------------------------------------

/// Detect window nodes in the tree. Only checks:
/// 1. If the root node itself is a window
/// 2. Direct children of the root that are windows
///
/// Does NOT recurse deeper -- matches the Elixir SDK behavior where
/// only top-level windows are tracked for lifecycle management.
fn detect_windows(tree_node: Node) -> Set(String) {
  case tree_node.kind {
    "window" -> set.from_list([tree_node.id])
    _ ->
      tree_node.children
      |> list.filter(fn(child) { child.kind == "window" })
      |> list.map(fn(child) { child.id })
      |> set.from_list()
  }
}
