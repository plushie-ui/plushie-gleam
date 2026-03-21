//// Runtime: the Elm architecture update loop.
////
//// Owns the app model, executes init/update/view, diffs trees,
//// and sends patches to the bridge. Commands returned from update
//// are executed before the next view render.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dyn_decode
import gleam/erlang/process.{type Pid, type Subject}
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
  /// Async task completed with nonce for freshness validation.
  AsyncComplete(tag: String, nonce: Int, result: Result(Dynamic, Dynamic))
  /// Stream emitted a value with nonce for freshness validation.
  StreamEmit(tag: String, nonce: Int, value: Dynamic)
  /// Effect request timed out.
  EffectTimeout(request_id: String)
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
    // tag -> (pid, nonce) for stale-result protection
    async_tasks: Dict(String, #(Pid, Int)),
    // Monotonically increasing counter for async nonces
    nonce_counter: Int,
    // request_id -> timeout timer for pending platform effects
    pending_effects: Dict(String, process.Timer),
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

  // Detect initial windows
  let initial_windows = detect_windows(initial_tree)

  // Build initial state (before init commands so execute_commands can
  // thread the full LoopState, enabling async task PID tracking)
  let state =
    LoopState(
      app:,
      model:,
      bridge:,
      self:,
      notifications:,
      tree: Some(initial_tree),
      active_subs: dict.new(),
      windows: initial_windows,
      opts:,
      errors: 0,
      async_tasks: dict.new(),
      nonce_counter: 0,
      pending_effects: dict.new(),
    )

  // Execute init commands (threads full state for PID tracking)
  let state = execute_commands(init_cmds, state)

  // Sync subscriptions
  let state =
    LoopState(
      ..state,
      active_subs: sync_subscriptions(
        app.get_subscribe(app)(state.model),
        state.active_subs,
        bridge,
        self,
        opts,
      ),
    )

  // Sync initial windows (open all detected windows)
  sync_windows(
    initial_tree,
    set.new(),
    initial_windows,
    None,
    bridge,
    app,
    state.model,
    opts,
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
      // Cancel effect timeout if this is an EffectResponse
      let state = case event {
        event.EffectResponse(request_id:, ..) ->
          case dict.get(state.pending_effects, request_id) {
            Ok(timer) -> {
              process.cancel_timer(timer)
              LoopState(
                ..state,
                pending_effects: dict.delete(state.pending_effects, request_id),
              )
            }
            Error(_) -> state
          }
        _ -> state
      }
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

    AsyncComplete(tag:, nonce:, result:) -> {
      // Validate nonce matches current task -- discard stale results
      case dict.get(state.async_tasks, tag) {
        Ok(#(_, current_nonce)) if current_nonce == nonce -> {
          let new_state = handle_event(state, event.AsyncResult(tag:, result:))
          LoopState(
            ..new_state,
            async_tasks: dict.delete(new_state.async_tasks, tag),
          )
          |> message_loop()
        }
        _ -> message_loop(state)
      }
    }

    StreamEmit(tag:, nonce:, value:) -> {
      // Validate nonce matches current stream -- discard stale emissions
      case dict.get(state.async_tasks, tag) {
        Ok(#(_, current_nonce)) if current_nonce == nonce -> {
          handle_event(state, event.StreamValue(tag:, value:))
          |> message_loop()
        }
        _ -> message_loop(state)
      }
    }

    EffectTimeout(request_id:) -> {
      case dict.get(state.pending_effects, request_id) {
        Ok(_) -> {
          let timeout_event =
            event.EffectResponse(
              request_id:,
              result: event.EffectError(dynamic.string("timeout")),
            )
          let new_state = handle_event(state, timeout_event)
          LoopState(
            ..new_state,
            pending_effects: dict.delete(new_state.pending_effects, request_id),
          )
          |> message_loop()
        }
        Error(_) -> message_loop(state)
      }
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
      // Cancel all pending effect timeout timers
      dict.each(state.pending_effects, fn(_id, timer) {
        process.cancel_timer(timer)
        Nil
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
      let state_after_cmds =
        execute_commands(commands, LoopState(..state, model: new_model))
      let new_model = state_after_cmds.model

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

          // Sync window lifecycle (open/close/update ops)
          sync_windows(
            new_tree,
            state.windows,
            new_windows,
            state.tree,
            state.bridge,
            state.app,
            new_model,
            state.opts,
          )

          // Dispatch AllWindowsClosed if appropriate
          maybe_dispatch_all_windows_closed(
            state.windows,
            new_windows,
            state.self,
            state.opts.daemon,
          )

          LoopState(
            ..state,
            model: new_model,
            tree: Some(new_tree),
            active_subs: new_subs,
            windows: new_windows,
            errors: 0,
            async_tasks: state_after_cmds.async_tasks,
            nonce_counter: state_after_cmds.nonce_counter,
            pending_effects: state_after_cmds.pending_effects,
          )
        }
        Error(reason) -> {
          // View crashed -- revert to previous model and tree.
          // Keeping new_model would leave state and tree out of sync
          // since we can't render a valid tree from a model that crashes
          // the view function.
          let err_count = state.errors + 1
          case err_count <= 10 {
            True ->
              io.println("toddy: view error: " <> dynamic.classify(reason))
            False -> Nil
          }
          LoopState(..state, errors: err_count)
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
  state: LoopState(model),
) -> LoopState(model) {
  case cmd {
    command.None -> state

    command.Batch(commands:) ->
      list.fold(commands, state, fn(s, c) { execute_commands(c, s) })

    command.Exit -> {
      process.send(state.self, Shutdown)
      state
    }

    command.SendAfter(delay_ms:, msg:) -> {
      process.send_after(state.self, delay_ms, InternalEvent(msg))
      state
    }

    command.Done(value:, mapper:) -> {
      let event = mapper(value)
      process.send(state.self, InternalEvent(event))
      state
    }

    command.Focus(widget_id:) -> {
      send_widget_op(
        state.bridge,
        "focus",
        [#("target", StringVal(widget_id))],
        state.opts,
      )
      state
    }

    command.FocusNext -> {
      send_widget_op(state.bridge, "focus_next", [], state.opts)
      state
    }

    command.FocusPrevious -> {
      send_widget_op(state.bridge, "focus_previous", [], state.opts)
      state
    }

    command.SelectAll(widget_id:) -> {
      send_widget_op(
        state.bridge,
        "select_all",
        [#("target", StringVal(widget_id))],
        state.opts,
      )
      state
    }

    command.MoveCursorToFront(widget_id:) -> {
      send_widget_op(
        state.bridge,
        "move_cursor_to_front",
        [#("target", StringVal(widget_id))],
        state.opts,
      )
      state
    }

    command.MoveCursorToEnd(widget_id:) -> {
      send_widget_op(
        state.bridge,
        "move_cursor_to_end",
        [#("target", StringVal(widget_id))],
        state.opts,
      )
      state
    }

    command.MoveCursorTo(widget_id:, position:) -> {
      send_widget_op(
        state.bridge,
        "move_cursor_to",
        [
          #("target", StringVal(widget_id)),
          #("position", IntVal(position)),
        ],
        state.opts,
      )
      state
    }

    command.SelectRange(widget_id:, start:, end:) -> {
      send_widget_op(
        state.bridge,
        "select_range",
        [
          #("target", StringVal(widget_id)),
          #("start", IntVal(start)),
          #("end", IntVal(end)),
        ],
        state.opts,
      )
      state
    }

    command.ScrollTo(widget_id:, offset: _) -> {
      send_widget_op(
        state.bridge,
        "scroll_to",
        [#("target", StringVal(widget_id))],
        state.opts,
      )
      state
    }

    command.SnapTo(widget_id:, x:, y:) -> {
      send_widget_op(
        state.bridge,
        "snap_to",
        [
          #("target", StringVal(widget_id)),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
        ],
        state.opts,
      )
      state
    }

    command.SnapToEnd(widget_id:) -> {
      send_widget_op(
        state.bridge,
        "snap_to_end",
        [#("target", StringVal(widget_id))],
        state.opts,
      )
      state
    }

    command.ScrollBy(widget_id:, x:, y:) -> {
      send_widget_op(
        state.bridge,
        "scroll_by",
        [
          #("target", StringVal(widget_id)),
          #("x", FloatVal(x)),
          #("y", FloatVal(y)),
        ],
        state.opts,
      )
      state
    }

    command.CloseWindow(window_id:) -> {
      send_window_op(state.bridge, "close", window_id, [], state.opts)
      state
    }

    command.ResizeWindow(window_id:, width:, height:) -> {
      send_window_op(
        state.bridge,
        "resize",
        window_id,
        [#("width", FloatVal(width)), #("height", FloatVal(height))],
        state.opts,
      )
      state
    }

    command.MoveWindow(window_id:, x:, y:) -> {
      send_window_op(
        state.bridge,
        "move",
        window_id,
        [#("x", FloatVal(x)), #("y", FloatVal(y))],
        state.opts,
      )
      state
    }

    command.MaximizeWindow(window_id:, maximized:) -> {
      send_window_op(
        state.bridge,
        "maximize",
        window_id,
        [#("maximized", BoolVal(maximized))],
        state.opts,
      )
      state
    }

    command.MinimizeWindow(window_id:, minimized:) -> {
      send_window_op(
        state.bridge,
        "minimize",
        window_id,
        [#("minimized", BoolVal(minimized))],
        state.opts,
      )
      state
    }

    command.SetWindowMode(window_id:, mode:) -> {
      send_window_op(
        state.bridge,
        "set_mode",
        window_id,
        [#("mode", StringVal(mode))],
        state.opts,
      )
      state
    }

    command.ToggleMaximize(window_id:) -> {
      send_window_op(state.bridge, "toggle_maximize", window_id, [], state.opts)
      state
    }

    command.ToggleDecorations(window_id:) -> {
      send_window_op(
        state.bridge,
        "toggle_decorations",
        window_id,
        [],
        state.opts,
      )
      state
    }

    command.GainFocus(window_id:) -> {
      send_window_op(state.bridge, "gain_focus", window_id, [], state.opts)
      state
    }

    command.SetWindowLevel(window_id:, level:) -> {
      send_window_op(
        state.bridge,
        "set_level",
        window_id,
        [#("level", StringVal(level))],
        state.opts,
      )
      state
    }

    command.DragWindow(window_id:) -> {
      send_window_op(state.bridge, "drag", window_id, [], state.opts)
      state
    }

    command.DragResizeWindow(window_id:, direction:) -> {
      send_window_op(
        state.bridge,
        "drag_resize",
        window_id,
        [#("direction", StringVal(direction))],
        state.opts,
      )
      state
    }

    command.RequestUserAttention(window_id:, urgency:) -> {
      let payload = case urgency {
        option.Some(u) -> [#("urgency", StringVal(u))]
        option.None -> []
      }
      send_window_op(
        state.bridge,
        "request_user_attention",
        window_id,
        payload,
        state.opts,
      )
      state
    }

    command.Screenshot(window_id:, tag:) -> {
      send_window_op(
        state.bridge,
        "screenshot",
        window_id,
        [#("tag", StringVal(tag))],
        state.opts,
      )
      state
    }

    command.SetResizable(window_id:, resizable:) -> {
      send_window_op(
        state.bridge,
        "set_resizable",
        window_id,
        [#("resizable", BoolVal(resizable))],
        state.opts,
      )
      state
    }

    command.SetMinSize(window_id:, width:, height:) -> {
      send_window_op(
        state.bridge,
        "set_min_size",
        window_id,
        [#("width", FloatVal(width)), #("height", FloatVal(height))],
        state.opts,
      )
      state
    }

    command.SetMaxSize(window_id:, width:, height:) -> {
      send_window_op(
        state.bridge,
        "set_max_size",
        window_id,
        [#("width", FloatVal(width)), #("height", FloatVal(height))],
        state.opts,
      )
      state
    }

    command.EnableMousePassthrough(window_id:) -> {
      send_window_op(
        state.bridge,
        "enable_mouse_passthrough",
        window_id,
        [],
        state.opts,
      )
      state
    }

    command.DisableMousePassthrough(window_id:) -> {
      send_window_op(
        state.bridge,
        "disable_mouse_passthrough",
        window_id,
        [],
        state.opts,
      )
      state
    }

    command.ShowSystemMenu(window_id:) -> {
      send_window_op(
        state.bridge,
        "show_system_menu",
        window_id,
        [],
        state.opts,
      )
      state
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
      send_window_op(
        state.bridge,
        "set_resize_increments",
        window_id,
        payload,
        state.opts,
      )
      state
    }

    command.AllowAutomaticTabbing(enabled:) -> {
      send_widget_op(
        state.bridge,
        "allow_automatic_tabbing",
        [#("enabled", BoolVal(enabled))],
        state.opts,
      )
      state
    }

    command.SetIcon(window_id:, rgba_data:, width:, height:) -> {
      send_window_op(
        state.bridge,
        "set_icon",
        window_id,
        [
          #("data", StringVal(encode_base64(rgba_data))),
          #("width", IntVal(width)),
          #("height", IntVal(height)),
        ],
        state.opts,
      )
      state
    }

    command.GetWindowSize(window_id:, tag:) -> {
      send_window_query(state.bridge, "get_size", window_id, tag, state.opts)
      state
    }

    command.GetWindowPosition(window_id:, tag:) -> {
      send_window_query(
        state.bridge,
        "get_position",
        window_id,
        tag,
        state.opts,
      )
      state
    }

    command.IsMaximized(window_id:, tag:) -> {
      send_window_query(
        state.bridge,
        "is_maximized",
        window_id,
        tag,
        state.opts,
      )
      state
    }

    command.IsMinimized(window_id:, tag:) -> {
      send_window_query(
        state.bridge,
        "is_minimized",
        window_id,
        tag,
        state.opts,
      )
      state
    }

    command.GetMode(window_id:, tag:) -> {
      send_window_query(state.bridge, "get_mode", window_id, tag, state.opts)
      state
    }

    command.GetScaleFactor(window_id:, tag:) -> {
      send_window_query(
        state.bridge,
        "get_scale_factor",
        window_id,
        tag,
        state.opts,
      )
      state
    }

    command.RawWindowId(window_id:, tag:) -> {
      send_window_query(state.bridge, "raw_id", window_id, tag, state.opts)
      state
    }

    command.MonitorSize(window_id:, tag:) -> {
      send_window_query(
        state.bridge,
        "monitor_size",
        window_id,
        tag,
        state.opts,
      )
      state
    }

    command.GetSystemTheme(tag:) -> {
      send_window_query(
        state.bridge,
        "get_system_theme",
        "_system",
        tag,
        state.opts,
      )
      state
    }

    command.GetSystemInfo(tag:) -> {
      send_window_query(
        state.bridge,
        "get_system_info",
        "_system",
        tag,
        state.opts,
      )
      state
    }

    command.Announce(text:) -> {
      send_widget_op(
        state.bridge,
        "announce",
        [#("text", StringVal(text))],
        state.opts,
      )
      state
    }

    command.AdvanceFrame(timestamp:) -> {
      send_encoded(
        state.bridge,
        encode.encode_advance_frame(
          timestamp,
          state.opts.session,
          state.opts.format,
        ),
      )
      state
    }

    command.Effect(id:, kind:, payload:) -> {
      send_encoded(
        state.bridge,
        encode.encode_effect(
          id,
          kind,
          payload,
          state.opts.session,
          state.opts.format,
        ),
      )
      // Start a 30-second timeout timer for this effect
      let timeout_timer =
        process.send_after(state.self, 30_000, EffectTimeout(request_id: id))
      LoopState(
        ..state,
        pending_effects: dict.insert(state.pending_effects, id, timeout_timer),
      )
    }

    command.ExtensionCommand(node_id:, op:, payload:) -> {
      send_encoded(
        state.bridge,
        encode.encode_extension_command(
          node_id,
          op,
          payload,
          state.opts.session,
          state.opts.format,
        ),
      )
      state
    }

    command.ExtensionCommands(commands:) -> {
      list.each(commands, fn(cmd_tuple) {
        let #(node_id, op, payload) = cmd_tuple
        send_encoded(
          state.bridge,
          encode.encode_extension_command(
            node_id,
            op,
            payload,
            state.opts.session,
            state.opts.format,
          ),
        )
      })
      state
    }

    command.CreateImage(handle:, data:) -> {
      send_image_op(
        state.bridge,
        "create",
        [
          #("handle", StringVal(handle)),
          #("data", StringVal(encode_base64(data))),
        ],
        state.opts,
      )
      state
    }

    command.CreateImageRgba(handle:, width:, height:, pixels:) -> {
      send_image_op(
        state.bridge,
        "create_rgba",
        [
          #("handle", StringVal(handle)),
          #("width", IntVal(width)),
          #("height", IntVal(height)),
          #("pixels", StringVal(encode_base64(pixels))),
        ],
        state.opts,
      )
      state
    }

    command.UpdateImage(handle:, data:) -> {
      send_image_op(
        state.bridge,
        "update",
        [
          #("handle", StringVal(handle)),
          #("data", StringVal(encode_base64(data))),
        ],
        state.opts,
      )
      state
    }

    command.UpdateImageRgba(handle:, width:, height:, pixels:) -> {
      send_image_op(
        state.bridge,
        "update_rgba",
        [
          #("handle", StringVal(handle)),
          #("width", IntVal(width)),
          #("height", IntVal(height)),
          #("pixels", StringVal(encode_base64(pixels))),
        ],
        state.opts,
      )
      state
    }

    command.DeleteImage(handle:) -> {
      send_image_op(
        state.bridge,
        "delete",
        [#("handle", StringVal(handle))],
        state.opts,
      )
      state
    }

    command.ListImages(tag:) -> {
      send_image_op(
        state.bridge,
        "list",
        [#("tag", StringVal(tag))],
        state.opts,
      )
      state
    }

    command.ClearImages -> {
      send_image_op(state.bridge, "clear", [], state.opts)
      state
    }

    command.TreeHashQuery(tag:) -> {
      send_widget_op(
        state.bridge,
        "tree_hash",
        [#("tag", StringVal(tag))],
        state.opts,
      )
      state
    }

    command.FindFocused(tag:) -> {
      send_widget_op(
        state.bridge,
        "find_focused",
        [#("tag", StringVal(tag))],
        state.opts,
      )
      state
    }

    command.LoadFont(data:) -> {
      send_widget_op(
        state.bridge,
        "load_font",
        [#("data", StringVal(encode_base64(data)))],
        state.opts,
      )
      state
    }

    command.PaneSplit(pane_grid_id:, pane_id:, axis:, new_pane_id:) -> {
      send_widget_op(
        state.bridge,
        "pane_split",
        [
          #("pane_grid_id", StringVal(pane_grid_id)),
          #("pane_id", dynamic_to_prop_value(pane_id)),
          #("axis", StringVal(axis)),
          #("new_pane_id", dynamic_to_prop_value(new_pane_id)),
        ],
        state.opts,
      )
      state
    }

    command.PaneClose(pane_grid_id:, pane_id:) -> {
      send_widget_op(
        state.bridge,
        "pane_close",
        [
          #("pane_grid_id", StringVal(pane_grid_id)),
          #("pane_id", dynamic_to_prop_value(pane_id)),
        ],
        state.opts,
      )
      state
    }

    command.PaneSwap(pane_grid_id:, pane_a:, pane_b:) -> {
      send_widget_op(
        state.bridge,
        "pane_swap",
        [
          #("pane_grid_id", StringVal(pane_grid_id)),
          #("pane_a", dynamic_to_prop_value(pane_a)),
          #("pane_b", dynamic_to_prop_value(pane_b)),
        ],
        state.opts,
      )
      state
    }

    command.PaneMaximize(pane_grid_id:, pane_id:) -> {
      send_widget_op(
        state.bridge,
        "pane_maximize",
        [
          #("pane_grid_id", StringVal(pane_grid_id)),
          #("pane_id", dynamic_to_prop_value(pane_id)),
        ],
        state.opts,
      )
      state
    }

    command.PaneRestore(pane_grid_id:) -> {
      send_widget_op(
        state.bridge,
        "pane_restore",
        [#("pane_grid_id", StringVal(pane_grid_id))],
        state.opts,
      )
      state
    }

    command.Async(work:, tag:) -> {
      let nonce = state.nonce_counter + 1
      let runtime_self = state.self
      let pid =
        process.spawn(fn() {
          let result = case ffi.try_call(work) {
            Ok(value) -> Ok(value)
            Error(reason) -> Error(reason)
          }
          process.send(runtime_self, AsyncComplete(tag:, nonce:, result:))
        })
      LoopState(
        ..state,
        async_tasks: dict.insert(state.async_tasks, tag, #(pid, nonce)),
        nonce_counter: nonce,
      )
    }

    command.Stream(work:, tag:) -> {
      let nonce = state.nonce_counter + 1
      let runtime_self = state.self
      let emit = fn(value) {
        process.send(runtime_self, StreamEmit(tag:, nonce:, value:))
      }
      let pid =
        process.spawn(fn() {
          let result = case ffi.try_call(fn() { work(emit) }) {
            Ok(value) -> Ok(value)
            Error(reason) -> Error(reason)
          }
          process.send(runtime_self, AsyncComplete(tag:, nonce:, result:))
        })
      LoopState(
        ..state,
        async_tasks: dict.insert(state.async_tasks, tag, #(pid, nonce)),
        nonce_counter: nonce,
      )
    }

    command.Cancel(tag:) -> {
      case dict.get(state.async_tasks, tag) {
        Ok(#(pid, _nonce)) -> {
          process.kill(pid)
          LoopState(..state, async_tasks: dict.delete(state.async_tasks, tag))
        }
        Error(_) -> state
      }
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
    Error(err) -> {
      io.println(
        "toddy: encode error: " <> protocol.encode_error_to_string(err),
      )
      Nil
    }
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

/// Convert a Dynamic value to a PropValue for wire encoding.
/// Tries string, then int, then float; falls back to classifying the type.
fn dynamic_to_prop_value(d: Dynamic) -> PropValue {
  case dyn_decode.run(d, dyn_decode.string) {
    Ok(s) -> StringVal(s)
    Error(_) ->
      case dyn_decode.run(d, dyn_decode.int) {
        Ok(n) -> IntVal(n)
        Error(_) ->
          case dyn_decode.run(d, dyn_decode.float) {
            Ok(f) -> FloatVal(f)
            Error(_) -> StringVal(dynamic.classify(d))
          }
      }
  }
}

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

// -- Window detection and lifecycle ------------------------------------------

/// Detect window nodes in the tree. Only checks:
/// 1. If the root node itself is a window
/// 2. Direct children of the root that are windows
///
/// Does NOT recurse deeper -- matches the Elixir SDK behavior where
/// only top-level windows are tracked for lifecycle management.
pub fn detect_windows(tree_node: Node) -> Set(String) {
  case tree_node.kind {
    "window" -> set.from_list([tree_node.id])
    _ ->
      tree_node.children
      |> list.filter(fn(child) { child.kind == "window" })
      |> list.map(fn(child) { child.id })
      |> set.from_list()
  }
}

/// Window prop keys tracked for lifecycle sync. When a window node
/// has any of these props and they change, an update op is sent.
const window_prop_keys = [
  "title", "width", "height", "maximized", "fullscreen", "visible", "resizable",
  "closeable", "minimizable", "decorations", "transparent", "blur", "level",
  "exit_on_close_request",
]

/// Synchronize window lifecycle: open new windows, close removed ones,
/// and send update ops for windows whose tracked props changed.
///
/// When all windows close and daemon mode is off, dispatches
/// AllWindowsClosed through update so the app can handle it.
fn sync_windows(
  new_tree: Node,
  old_windows: Set(String),
  new_windows: Set(String),
  old_tree: Option(Node),
  bridge: Subject(BridgeMessage),
  app: App(model, Event),
  model: model,
  opts: RuntimeOpts,
) -> Nil {
  // Open new windows
  let opened = set.difference(new_windows, old_windows)
  set.each(opened, fn(window_id) {
    let base_config = app.get_window_config(app)(model)
    let per_window = extract_window_props(new_tree, window_id)
    let merged = dict.merge(base_config, per_window)
    send_window_op(bridge, "open", window_id, dict.to_list(merged), opts)
  })

  // Close removed windows
  let closed = set.difference(old_windows, new_windows)
  set.each(closed, fn(window_id) {
    send_window_op(bridge, "close", window_id, [], opts)
  })

  // Update surviving windows whose props changed
  case old_tree {
    Some(old) -> {
      let surviving = set.intersection(old_windows, new_windows)
      set.each(surviving, fn(window_id) {
        let old_props = extract_window_props(old, window_id)
        let new_props = extract_window_props(new_tree, window_id)
        case old_props == new_props {
          True -> Nil
          False ->
            send_window_op(
              bridge,
              "update",
              window_id,
              dict.to_list(new_props),
              opts,
            )
        }
      })
    }
    None -> Nil
  }

  Nil
}

/// Check if all windows just closed (non-daemon mode) and dispatch
/// AllWindowsClosed if so.
fn maybe_dispatch_all_windows_closed(
  old_windows: Set(String),
  new_windows: Set(String),
  self: Subject(RuntimeMessage),
  daemon: Bool,
) -> Nil {
  case daemon {
    True -> Nil
    False ->
      case set.is_empty(old_windows), set.is_empty(new_windows) {
        // old was non-empty, new is empty -> all closed
        False, True -> process.send(self, InternalEvent(event.AllWindowsClosed))
        _, _ -> Nil
      }
  }
}

/// Extract the tracked window props from a window node found in the tree.
pub fn extract_window_props(
  tree_node: Node,
  window_id: String,
) -> Dict(String, PropValue) {
  case find_window_node(tree_node, window_id) {
    Some(win) ->
      dict.filter(win.props, fn(key, _val) {
        list.contains(window_prop_keys, key)
      })
    None -> dict.new()
  }
}

/// Find a window node at root level or as a direct child.
pub fn find_window_node(tree_node: Node, window_id: String) -> Option(Node) {
  case tree_node.kind, tree_node.id {
    "window", id if id == window_id -> Some(tree_node)
    _, _ ->
      list.find(tree_node.children, fn(child) {
        child.kind == "window" && child.id == window_id
      })
      |> option.from_result()
  }
}
