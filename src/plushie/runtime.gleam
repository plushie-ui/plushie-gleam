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
import gleam/string
import plushie/app.{type App}
import plushie/bridge.{
  type BridgeMessage, type RuntimeNotification, InboundEvent, RendererExited,
  Send,
}
import plushie/command.{type Command}
import plushie/effects
import plushie/event.{type Event}
import plushie/ffi
import plushie/node.{
  type Node, type PropValue, BinaryVal, BoolVal, FloatVal, IntVal, StringVal,
}
import plushie/protocol
import plushie/protocol/decode.{EventMessage, Hello}
import plushie/protocol/encode
import plushie/subscription.{type Subscription}
import plushie/tree

// -- Public types ------------------------------------------------------------

/// Messages handled by the runtime.
pub type RuntimeMessage {
  /// Notification from the bridge.
  FromBridge(RuntimeNotification)
  /// Internal event dispatch (timer ticks, etc.).
  InternalEvent(Event)
  /// Internal msg dispatch (Done, SendAfter -- already mapped to msg).
  InternalMsg(Dynamic)
  /// Subscription timer fired.
  TimerFired(tag: String)
  /// Async task completed with nonce for freshness validation.
  AsyncComplete(tag: String, nonce: Int, result: Result(Dynamic, Dynamic))
  /// Stream emitted a value with nonce for freshness validation.
  StreamEmit(tag: String, nonce: Int, value: Dynamic)
  /// Effect request timed out.
  EffectTimeout(request_id: String)
  /// Flush deferred coalescable events (zero-delay timer).
  CoalesceFlush
  /// Monitored async task process exited.
  ProcessDown(process.Down)
  /// Delayed renderer restart attempt.
  RestartRenderer
  /// Force a re-render without resetting state (dev-mode live reload).
  ForceRerender
  /// Shutdown.
  Shutdown
}

/// Start options for the runtime.
pub type RuntimeOpts {
  RuntimeOpts(
    format: protocol.Format,
    session: String,
    daemon: Bool,
    app_opts: Dynamic,
    renderer_args: List(String),
  )
}

/// Default runtime options.
pub fn default_opts() -> RuntimeOpts {
  RuntimeOpts(
    format: protocol.Msgpack,
    session: "",
    daemon: False,
    app_opts: dynamic.nil(),
    renderer_args: [],
  )
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
  app: App(model, msg),
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
      bridge.start(
        binary_path,
        opts.format,
        notification_subject,
        opts.session,
        opts.renderer_args,
      )
    {
      Ok(bridge_subject) -> {
        // Report success to parent
        process.send(init_channel, Ok(runtime_subject))
        // Run the app
        run(
          app,
          bridge_subject,
          runtime_subject,
          notification_subject,
          opts,
          binary_path,
        )
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

type LoopState(model, msg) {
  LoopState(
    app: App(model, msg),
    model: model,
    bridge: Subject(BridgeMessage),
    bridge_pid: Option(Pid),
    self: Subject(RuntimeMessage),
    notifications: Subject(RuntimeNotification),
    tree: Option(Node),
    active_subs: Dict(String, SubEntry),
    windows: Set(String),
    opts: RuntimeOpts,
    errors: Int,
    // tag -> (pid, nonce, monitor) for stale-result protection
    async_tasks: Dict(String, #(Pid, Int, process.Monitor)),
    // Monotonically increasing counter for async nonces
    nonce_counter: Int,
    // request_id -> timeout timer for pending platform effects
    pending_effects: Dict(String, process.Timer),
    // event key -> timer for SendAfter deduplication
    pending_timers: Dict(String, process.Timer),
    // Deferred coalescable events, keyed by coalesce identity
    pending_coalesce: Dict(String, Event),
    // Timer for flushing deferred events (zero-delay)
    coalesce_timer: Option(process.Timer),
    // Bridge restart tracking
    binary_path: String,
    restart_count: Int,
    max_restarts: Int,
    restart_delay_base: Int,
  )
}

type SubEntry {
  TimerSub(timer: process.Timer, interval_ms: Int, tag: String)
  RendererSub(kind: String, max_rate: option.Option(Int))
}

// -- Process entry point -----------------------------------------------------

fn run(
  app: App(model, msg),
  bridge: Subject(BridgeMessage),
  self: Subject(RuntimeMessage),
  notifications: Subject(RuntimeNotification),
  opts: RuntimeOpts,
  binary_path: String,
) -> Nil {
  // Initialize
  let #(model, init_cmds) = app.get_init(app)(opts.app_opts)

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

  // Get the bridge actor's PID for monitoring (D-039)
  let bridge_pid = case process.subject_owner(bridge) {
    Ok(pid) -> Some(pid)
    Error(_) -> None
  }

  // Monitor the bridge process so we can detect unexpected crashes
  case bridge_pid {
    Some(pid) -> {
      process.monitor(pid)
      Nil
    }
    None -> Nil
  }

  // Build initial state (before init commands so execute_commands can
  // thread the full LoopState, enabling async task PID tracking)
  let state =
    LoopState(
      app:,
      model:,
      bridge:,
      bridge_pid:,
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
      pending_timers: dict.new(),
      pending_coalesce: dict.new(),
      coalesce_timer: None,
      binary_path:,
      restart_count: 0,
      max_restarts: 5,
      restart_delay_base: 100,
    )

  // Execute init commands (threads full state for PID tracking)
  let state = execute_commands(init_cmds, state)

  // Sync subscriptions
  let state =
    LoopState(
      ..state,
      active_subs: sync_subscriptions(
        safe_subscribe(app, state.model),
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

fn message_loop(state: LoopState(model, msg)) -> Nil {
  let selector =
    process.new_selector()
    |> process.select(state.self)
    |> process.select_map(state.notifications, FromBridge)
    |> process.select_monitors(ProcessDown)

  let msg = process.selector_receive_forever(selector)

  case msg {
    FromBridge(InboundEvent(EventMessage(ev))) -> {
      // Reset restart count on successful communication
      let state = LoopState(..state, restart_count: 0)
      case coalesce_key(ev) {
        Some(key) -> {
          // Defer this event -- latest value wins
          let new_coalesce = dict.insert(state.pending_coalesce, key, ev)
          // Start flush timer if not already running
          let timer = case state.coalesce_timer {
            Some(_) -> state.coalesce_timer
            None -> Some(process.send_after(state.self, 0, CoalesceFlush))
          }
          LoopState(
            ..state,
            pending_coalesce: new_coalesce,
            coalesce_timer: timer,
          )
          |> message_loop()
        }
        None -> {
          // Non-coalescable: flush pending first, then process
          let state = flush_coalesced(state)
          let state = maybe_cancel_effect_timeout(state, ev)
          let new_state = handle_event(state, ev)
          // Stop runtime on AllWindowsClosed in non-daemon mode
          case ev, state.opts.daemon {
            event.AllWindowsClosed, False -> Nil
            _, _ -> message_loop(new_state)
          }
        }
      }
    }

    FromBridge(InboundEvent(Hello(protocol: proto, ..))) -> {
      case proto == protocol.protocol_version {
        True -> {
          // Reset restart count on successful handshake
          let state = LoopState(..state, restart_count: 0)
          message_loop(state)
        }
        False -> {
          io.println(
            "plushie: protocol version mismatch (expected "
            <> int.to_string(protocol.protocol_version)
            <> ", got "
            <> int.to_string(proto)
            <> ") -- stopping runtime",
          )
          // Stop the runtime loop on protocol mismatch
          Nil
        }
      }
    }

    FromBridge(RendererExited(status:)) -> {
      // Call app handler if defined, otherwise keep current model
      let model = case app.get_on_renderer_exit(state.app) {
        Some(handler) -> handler(state.model, dynamic.int(status))
        None -> state.model
      }
      let state = LoopState(..state, model: model)

      case status {
        0 -> {
          // Clean exit (user closed window) -- stop bridge and exit
          process.send(state.bridge, bridge.Shutdown)
          Nil
        }
        _ -> {
          // Crash -- attempt restart with exponential backoff
          case state.restart_count < state.max_restarts {
            True -> {
              let delay =
                calculate_backoff(state.restart_delay_base, state.restart_count)
              io.println(
                "plushie: renderer crashed (status "
                <> int.to_string(status)
                <> "), restarting in "
                <> int.to_string(delay)
                <> "ms (attempt "
                <> int.to_string(state.restart_count + 1)
                <> "/"
                <> int.to_string(state.max_restarts)
                <> ")",
              )
              process.send_after(state.self, delay, RestartRenderer)
              message_loop(state)
            }
            False -> {
              io.println(
                "plushie: renderer crashed "
                <> int.to_string(state.max_restarts)
                <> " times, giving up",
              )
              Nil
            }
          }
        }
      }
    }

    InternalEvent(event) -> {
      // Remove delivered timer entry (SendAfter deduplication)
      let timer_key = ffi.stable_hash_key(coerce_to_dynamic(event))
      let state =
        LoopState(
          ..state,
          pending_timers: dict.delete(state.pending_timers, timer_key),
        )
      let new_state = handle_event(state, event)
      // D-033: stop runtime on AllWindowsClosed in non-daemon mode
      case event, state.opts.daemon {
        event.AllWindowsClosed, False -> Nil
        _, _ -> message_loop(new_state)
      }
    }

    InternalMsg(dyn_msg) -> {
      // Done/SendAfter deliver msg values wrapped as Dynamic.
      // Remove delivered timer entry for deduplication.
      let timer_key = ffi.stable_hash_key(dyn_msg)
      let state =
        LoopState(
          ..state,
          pending_timers: dict.delete(state.pending_timers, timer_key),
        )
      // Unsafe coerce: the Dynamic contains a value of type msg
      let msg = unsafe_coerce_dynamic(dyn_msg)
      let new_state = handle_msg(state, msg)
      message_loop(new_state)
    }

    TimerFired(tag:) -> {
      // Drain any queued ticks for the same tag to coalesce rapid-fire
      // timer events (only the latest tick matters).
      drain_matching_ticks(state.self, tag)
      let timestamp = erlang_monotonic_time()
      let new_state = handle_event(state, event.TimerTick(tag:, timestamp:))
      reschedule_timer(new_state, tag) |> message_loop()
    }

    AsyncComplete(tag:, nonce:, result:) -> {
      // Validate nonce matches current task -- discard stale results
      case dict.get(state.async_tasks, tag) {
        Ok(#(_, current_nonce, monitor)) if current_nonce == nonce -> {
          process.demonitor_process(monitor)
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
        Ok(#(_, current_nonce, _)) if current_nonce == nonce -> {
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

    CoalesceFlush -> {
      flush_coalesced(state) |> message_loop()
    }

    ProcessDown(process.ProcessDown(monitor: _, pid: down_pid, reason: reason)) -> {
      // Check if this is the bridge actor dying (D-039)
      let is_bridge = case state.bridge_pid {
        Some(bpid) -> bpid == down_pid
        None -> False
      }
      case is_bridge {
        True -> {
          io.println(
            "plushie: bridge process died unexpectedly: "
            <> string.inspect(reason),
          )
          // Treat it like a renderer exit -- attempt restart
          case state.restart_count < state.max_restarts {
            True -> {
              let delay =
                calculate_backoff(state.restart_delay_base, state.restart_count)
              process.send_after(state.self, delay, RestartRenderer)
              message_loop(LoopState(..state, bridge_pid: None))
            }
            False -> {
              io.println("plushie: bridge crashed too many times, giving up")
              Nil
            }
          }
        }
        False -> {
          // Find which async task this pid belongs to
          let found =
            dict.fold(state.async_tasks, None, fn(acc, tag, entry) {
              case acc {
                Some(_) -> acc
                None -> {
                  let #(task_pid, _nonce, _monitor) = entry
                  case task_pid == down_pid {
                    True -> Some(tag)
                    False -> None
                  }
                }
              }
            })
          case found {
            Some(tag) -> {
              let state =
                LoopState(
                  ..state,
                  async_tasks: dict.delete(state.async_tasks, tag),
                )
              case reason {
                process.Normal -> message_loop(state)
                _ -> {
                  let crash_reason = case reason {
                    process.Killed -> dynamic.string("killed")
                    process.Abnormal(r) -> r
                    process.Normal -> dynamic.string("normal")
                  }
                  handle_event(
                    state,
                    event.AsyncResult(tag:, result: Error(crash_reason)),
                  )
                  |> message_loop()
                }
              }
            }
            None -> message_loop(state)
          }
        }
      }
    }

    // PortDown is not expected but handle gracefully
    ProcessDown(process.PortDown(..)) -> message_loop(state)

    RestartRenderer -> {
      // Send Shutdown to old bridge actor so it doesn't linger
      process.send(state.bridge, bridge.Shutdown)

      let notification_subject = process.new_subject()
      case
        bridge.start(
          state.binary_path,
          state.opts.format,
          notification_subject,
          state.opts.session,
          state.opts.renderer_args,
        )
      {
        Ok(new_bridge) -> {
          let new_count = state.restart_count + 1

          // Monitor the new bridge process (D-039)
          let new_bridge_pid = case process.subject_owner(new_bridge) {
            Ok(pid) -> {
              process.monitor(pid)
              Some(pid)
            }
            Error(_) -> None
          }

          io.println(
            "plushie: renderer restarted (attempt "
            <> int.to_string(new_count)
            <> ")",
          )

          // Point state.bridge to new bridge BEFORE flushing effects,
          // so any commands issued by the app's update handler during
          // effect error dispatch go to the live bridge, not the dead one.
          let state =
            LoopState(
              ..state,
              bridge: new_bridge,
              bridge_pid: new_bridge_pid,
              notifications: notification_subject,
            )

          // Cancel coalesce timer and discard stale coalescable events
          let state = case state.coalesce_timer {
            Some(timer) -> {
              process.cancel_timer(timer)
              LoopState(
                ..state,
                coalesce_timer: None,
                pending_coalesce: dict.new(),
              )
            }
            None -> LoopState(..state, pending_coalesce: dict.new())
          }

          // Cancel all pending send_after timers
          dict.each(state.pending_timers, fn(_key, timer) {
            process.cancel_timer(timer)
            Nil
          })
          let state = LoopState(..state, pending_timers: dict.new())

          // Flush pending effects with error (old renderer is gone).
          // Commands from the app's error handlers go to new_bridge.
          let state = flush_pending_effects_on_restart(state)

          // Stop old subscription timers (sync_subscriptions won't
          // see them since we pass dict.new() as current)
          dict.each(state.active_subs, fn(_key, entry) {
            case entry {
              TimerSub(timer:, ..) -> {
                process.cancel_timer(timer)
                Nil
              }
              _ -> Nil
            }
          })

          // Re-send settings
          let settings = app.get_settings(state.app)()
          send_encoded(
            new_bridge,
            encode.encode_settings(
              settings,
              state.opts.session,
              state.opts.format,
            ),
          )

          // Re-render view and send fresh snapshot
          let view_fn = app.get_view(state.app)
          let tree = case ffi.try_call(fn() { view_fn(state.model) }) {
            Ok(t) -> Some(tree.normalize(t))
            Error(_) -> state.tree
          }
          case tree {
            Some(t) ->
              send_encoded(
                new_bridge,
                encode.encode_snapshot(t, state.opts.session, state.opts.format),
              )
            None -> Nil
          }

          // Re-sync subscriptions with new renderer
          let new_subs =
            sync_subscriptions(
              safe_subscribe(state.app, state.model),
              dict.new(),
              new_bridge,
              state.self,
              state.opts,
            )

          // Re-open all windows
          let windows = case tree {
            Some(t) -> {
              let new_windows = detect_windows(t)
              sync_windows(
                t,
                set.new(),
                new_windows,
                None,
                new_bridge,
                state.app,
                state.model,
                state.opts,
              )
              new_windows
            }
            None -> state.windows
          }

          // Update remaining state fields (bridge and notifications
          // were already updated before effect flushing above)
          let state =
            LoopState(
              ..state,
              tree:,
              active_subs: new_subs,
              windows:,
              restart_count: new_count,
            )
          message_loop(state)
        }
        Error(_) -> {
          io.println("plushie: failed to restart renderer, giving up")
          Nil
        }
      }
    }

    ForceRerender -> {
      io.println("plushie runtime: force re-render (code reload)")
      // Re-render view and diff/patch
      let view_fn = app.get_view(state.app)
      case ffi.try_call(fn() { view_fn(state.model) }) {
        Ok(new_tree_raw) -> {
          let new_tree = tree.normalize(new_tree_raw)
          // Diff and send patch (or snapshot if no previous tree)
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
          // Re-sync subscriptions
          let new_subs =
            sync_subscriptions(
              safe_subscribe(state.app, state.model),
              state.active_subs,
              state.bridge,
              state.self,
              state.opts,
            )
          // Re-sync windows
          let new_windows = detect_windows(new_tree)
          sync_windows(
            new_tree,
            state.windows,
            new_windows,
            state.tree,
            state.bridge,
            state.app,
            state.model,
            state.opts,
          )
          LoopState(
            ..state,
            tree: Some(new_tree),
            active_subs: new_subs,
            windows: new_windows,
          )
          |> message_loop()
        }
        Error(reason) -> {
          io.println(
            "plushie runtime: force re-render view crashed: "
            <> string.inspect(reason),
          )
          message_loop(state)
        }
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
      // Cancel all pending send_after timers
      dict.each(state.pending_timers, fn(_key, timer) {
        process.cancel_timer(timer)
        Nil
      })
      // Cancel coalesce timer if running
      case state.coalesce_timer {
        Some(timer) -> {
          process.cancel_timer(timer)
          Nil
        }
        None -> Nil
      }
      // Stop the bridge actor
      process.send(state.bridge, bridge.Shutdown)
      Nil
    }
  }
}

@external(erlang, "erlang", "monotonic_time")
fn erlang_monotonic_time() -> Int

// -- Event coalescing --------------------------------------------------------

/// Determine which events are coalescable and return their dedup key.
/// High-frequency events like mouse moves and sensor resizes are deferred
/// so only the latest value is processed, preventing update storms.
fn coalesce_key(ev: Event) -> Option(String) {
  case ev {
    event.MouseMoved(..) -> Some("mouse_moved")
    event.SensorResize(id:, ..) -> Some("sensor_resize:" <> id)
    _ -> None
  }
}

/// Flush all pending coalescable events, processing each through handle_event.
/// Cancels the coalesce timer and clears the pending map.
fn flush_coalesced(state: LoopState(model, msg)) -> LoopState(model, msg) {
  let state = case state.coalesce_timer {
    Some(timer) -> {
      process.cancel_timer(timer)
      LoopState(..state, coalesce_timer: None)
    }
    None -> state
  }
  let state =
    dict.fold(state.pending_coalesce, state, fn(st, _key, ev) {
      handle_event(st, ev)
    })
  LoopState(..state, pending_coalesce: dict.new())
}

/// Cancel an effect timeout timer if the event is an EffectResponse.
fn maybe_cancel_effect_timeout(
  state: LoopState(model, msg),
  ev: Event,
) -> LoopState(model, msg) {
  case ev {
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
}

// -- Bridge restart helpers --------------------------------------------------

const max_backoff_ms = 5000

fn calculate_backoff(base: Int, attempt: Int) -> Int {
  let delay = base * pow2(attempt)
  case delay > max_backoff_ms {
    True -> max_backoff_ms
    False -> delay
  }
}

fn pow2(n: Int) -> Int {
  case n {
    0 -> 1
    _ -> 2 * pow2(n - 1)
  }
}

/// Fail all pending effects with a "renderer_restarted" error and cancel
/// their timeout timers. The old renderer can no longer respond.
fn flush_pending_effects_on_restart(
  state: LoopState(model, msg),
) -> LoopState(model, msg) {
  // Cancel all effect timeout timers
  dict.each(state.pending_effects, fn(_id, timer) {
    process.cancel_timer(timer)
    Nil
  })
  // Dispatch error events for each pending effect
  let state =
    dict.fold(state.pending_effects, state, fn(st, id, _timer) {
      let timeout_event =
        event.EffectResponse(
          request_id: id,
          result: event.EffectError(dynamic.string("renderer_restarted")),
        )
      handle_event(st, timeout_event)
    })
  LoopState(..state, pending_effects: dict.new())
}

// -- Event handling (the core update cycle) ----------------------------------

/// Map a wire Event to the app's msg type using on_event, if defined.
/// For simple() apps (on_event=None), we use an unsafe coerce because
/// msg is known to be Event at the type level.
fn map_event(app: App(model, msg), event: Event) -> msg {
  case app.get_on_event(app) {
    Some(mapper) -> mapper(event)
    None -> coerce_event(event)
  }
}

@external(erlang, "erlang", "element")
fn erlang_element(n: Int, tuple: a) -> b

/// Unsafe coerce: for simple() apps where msg = Event, bypass the type
/// system since Gleam doesn't have type equality witnesses.
fn coerce_event(event: Event) -> msg {
  // At runtime, Event IS msg for simple() apps. This is safe because
  // the only code path that reaches here is when on_event is None,
  // which only happens via simple() where msg = Event.
  let boxed = #(event)
  erlang_element(1, boxed)
}

/// Coerce a Dynamic back to the msg type. Safe because we only store
/// msg values as Dynamic in InternalMsg, and the type parameter is
/// consistent within a single runtime instance.
fn unsafe_coerce_dynamic(dyn: Dynamic) -> msg {
  let boxed = #(dyn)
  erlang_element(1, boxed)
}

/// Coerce any value to Dynamic for transport through RuntimeMessage.
fn coerce_to_dynamic(value: a) -> Dynamic {
  let boxed = #(value)
  erlang_element(1, boxed)
}

/// Handle a message that is already the app's msg type (from Done/SendAfter).
/// Runs the full update cycle without event mapping.
fn handle_msg(state: LoopState(model, msg), msg: msg) -> LoopState(model, msg) {
  dispatch_update(state, msg)
}

/// Handle a wire event by mapping it to the app's msg type first.
fn handle_event(
  state: LoopState(model, msg),
  event: Event,
) -> LoopState(model, msg) {
  let mapped_msg = map_event(state.app, event)
  dispatch_update(state, mapped_msg)
}

/// Core update cycle: call update -> execute commands -> render view ->
/// diff -> patch -> sync subscriptions -> sync windows.
fn dispatch_update(
  state: LoopState(model, msg),
  msg: msg,
) -> LoopState(model, msg) {
  let update_fn = app.get_update(state.app)

  case ffi.try_call(fn() { update_fn(state.model, msg) }) {
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
              safe_subscribe(state.app, new_model),
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
          // View crashed -- preserve model and command-side state
          // (async_tasks, nonce_counter, pending_effects) but keep old tree.
          // This matches the Elixir SDK: model and commands persist through
          // view crashes, only the tree stays at its previous value.
          let err_count = state_after_cmds.errors + 1
          case err_count <= 10 {
            True ->
              io.println("plushie: view error: " <> dynamic.classify(reason))
            False -> Nil
          }
          LoopState(..state_after_cmds, tree: state.tree, errors: err_count)
        }
      }
    }
    Error(reason) -> {
      let err_count = state.errors + 1
      case err_count <= 10 {
        True ->
          io.println("plushie: update error: " <> dynamic.classify(reason))
        False -> Nil
      }
      LoopState(..state, errors: err_count)
    }
  }
}

// -- Command execution -------------------------------------------------------

fn execute_commands(
  cmd: Command(msg),
  state: LoopState(model, msg),
) -> LoopState(model, msg) {
  case cmd {
    command.None -> state

    command.Batch(commands:) ->
      list.fold(commands, state, fn(s, c) { execute_commands(c, s) })

    command.Exit -> {
      process.send(state.self, Shutdown)
      state
    }

    command.SendAfter(delay_ms:, msg:) -> {
      let timer_key = ffi.stable_hash_key(coerce_to_dynamic(msg))
      // Cancel any existing timer for the same event key
      let state = case dict.get(state.pending_timers, timer_key) {
        Ok(old_timer) -> {
          process.cancel_timer(old_timer)
          state
        }
        Error(_) -> state
      }
      // Wrap msg as Dynamic since RuntimeMessage is not parameterized
      let timer =
        process.send_after(
          state.self,
          delay_ms,
          InternalMsg(coerce_to_dynamic(msg)),
        )
      LoopState(
        ..state,
        pending_timers: dict.insert(state.pending_timers, timer_key, timer),
      )
    }

    command.Done(value:, mapper:) -> {
      let mapped_msg = mapper(value)
      process.send(state.self, InternalMsg(coerce_to_dynamic(mapped_msg)))
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

    command.ScrollTo(widget_id:, offset:) -> {
      send_widget_op(
        state.bridge,
        "scroll_to",
        [
          #("target", StringVal(widget_id)),
          #("offset_y", dynamic_to_prop_value(offset)),
        ],
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
      send_widget_op(
        state.bridge,
        "close_window",
        [#("window_id", StringVal(window_id))],
        state.opts,
      )
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
        "request_attention",
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
        "mouse_passthrough",
        window_id,
        [#("enabled", BoolVal(True))],
        state.opts,
      )
      state
    }

    command.DisableMousePassthrough(window_id:) -> {
      send_window_op(
        state.bridge,
        "mouse_passthrough",
        window_id,
        [#("enabled", BoolVal(False))],
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
      send_window_op(
        state.bridge,
        "allow_automatic_tabbing",
        "_global",
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
      // Start a per-kind timeout timer for this effect
      let timeout_timer =
        process.send_after(
          state.self,
          effects.default_timeout(kind),
          EffectTimeout(request_id: id),
        )
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
        "create_image",
        [#("handle", StringVal(handle)), #("data", BinaryVal(data))],
        state.opts,
      )
      state
    }

    command.CreateImageRgba(handle:, width:, height:, pixels:) -> {
      send_image_op(
        state.bridge,
        "create_image",
        [
          #("handle", StringVal(handle)),
          #("width", IntVal(width)),
          #("height", IntVal(height)),
          #("pixels", BinaryVal(pixels)),
        ],
        state.opts,
      )
      state
    }

    command.UpdateImage(handle:, data:) -> {
      send_image_op(
        state.bridge,
        "update_image",
        [#("handle", StringVal(handle)), #("data", BinaryVal(data))],
        state.opts,
      )
      state
    }

    command.UpdateImageRgba(handle:, width:, height:, pixels:) -> {
      send_image_op(
        state.bridge,
        "update_image",
        [
          #("handle", StringVal(handle)),
          #("width", IntVal(width)),
          #("height", IntVal(height)),
          #("pixels", BinaryVal(pixels)),
        ],
        state.opts,
      )
      state
    }

    command.DeleteImage(handle:) -> {
      send_image_op(
        state.bridge,
        "delete_image",
        [#("handle", StringVal(handle))],
        state.opts,
      )
      state
    }

    command.ListImages(tag:) -> {
      send_widget_op(
        state.bridge,
        "list_images",
        [#("tag", StringVal(tag))],
        state.opts,
      )
      state
    }

    command.ClearImages -> {
      send_widget_op(state.bridge, "clear_images", [], state.opts)
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
          #("target", StringVal(pane_grid_id)),
          #("pane", dynamic_to_prop_value(pane_id)),
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
          #("target", StringVal(pane_grid_id)),
          #("pane", dynamic_to_prop_value(pane_id)),
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
          #("target", StringVal(pane_grid_id)),
          #("a", dynamic_to_prop_value(pane_a)),
          #("b", dynamic_to_prop_value(pane_b)),
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
          #("target", StringVal(pane_grid_id)),
          #("pane", dynamic_to_prop_value(pane_id)),
        ],
        state.opts,
      )
      state
    }

    command.PaneRestore(pane_grid_id:) -> {
      send_widget_op(
        state.bridge,
        "pane_restore",
        [#("target", StringVal(pane_grid_id))],
        state.opts,
      )
      state
    }

    command.Async(work:, tag:) -> {
      // Kill existing task for same tag before starting a new one
      let state = cancel_existing_task(state, tag)
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
      let monitor = process.monitor(pid)
      LoopState(
        ..state,
        async_tasks: dict.insert(state.async_tasks, tag, #(pid, nonce, monitor)),
        nonce_counter: nonce,
      )
    }

    command.Stream(work:, tag:) -> {
      // Kill existing task for same tag before starting a new one
      let state = cancel_existing_task(state, tag)
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
      let monitor = process.monitor(pid)
      LoopState(
        ..state,
        async_tasks: dict.insert(state.async_tasks, tag, #(pid, nonce, monitor)),
        nonce_counter: nonce,
      )
    }

    command.Cancel(tag:) -> {
      cancel_existing_task(state, tag)
    }
  }
}

/// Kill an existing async task with the given tag and clean up its monitor.
fn cancel_existing_task(
  state: LoopState(model, msg),
  tag: String,
) -> LoopState(model, msg) {
  case dict.get(state.async_tasks, tag) {
    Ok(#(pid, _nonce, monitor)) -> {
      process.demonitor_process(monitor)
      process.kill(pid)
      LoopState(..state, async_tasks: dict.delete(state.async_tasks, tag))
    }
    Error(_) -> state
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
        "plushie: encode error: " <> protocol.encode_error_to_string(err),
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

/// Call the app's subscribe callback wrapped in try_call.
/// On error, log and return an empty list so the runtime stays alive.
fn safe_subscribe(
  application: App(model, msg),
  model: model,
) -> List(Subscription) {
  let subscribe_fn = app.get_subscribe(application)
  case ffi.try_call(fn() { subscribe_fn(model) }) {
    Ok(subs) -> subs
    Error(reason) -> {
      io.println(
        "plushie runtime: subscribe/1 raised: " <> string.inspect(reason),
      )
      []
    }
  }
}

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

  // Start new subscriptions and update max_rate on kept renderer subs
  dict.fold(desired_by_key, current, fn(acc, key, sub) {
    case dict.get(acc, key) {
      Error(_) -> {
        let entry = start_subscription(sub, bridge, self, opts)
        dict.insert(acc, key, entry)
      }
      Ok(RendererSub(kind:, max_rate: old_rate)) -> {
        let new_rate = subscription.get_max_rate(sub)
        case old_rate == new_rate {
          True -> acc
          False -> {
            let tag = subscription.tag(sub)
            send_encoded(
              bridge,
              encode.encode_subscribe(
                kind,
                tag,
                new_rate,
                opts.session,
                opts.format,
              ),
            )
            dict.insert(acc, key, RendererSub(kind:, max_rate: new_rate))
          }
        }
      }
      Ok(_) -> acc
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
      let max_rate = subscription.get_max_rate(sub)
      send_encoded(
        bridge,
        encode.encode_subscribe(kind, tag, max_rate, opts.session, opts.format),
      )
      RendererSub(kind:, max_rate:)
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
    RendererSub(kind:, ..) -> {
      send_encoded(
        bridge,
        encode.encode_unsubscribe(kind, opts.session, opts.format),
      )
    }
  }
}

/// Drain queued TimerFired messages for the same tag from the mailbox.
/// Uses Erlang selective receive (via FFI) with zero timeout to consume
/// only matching messages without disturbing other mailbox contents.
/// This coalesces rapid-fire timer ticks so the runtime only processes
/// the latest one.
@external(erlang, "plushie_ffi", "drain_timer_ticks")
fn drain_matching_ticks(subject: Subject(RuntimeMessage), tag: String) -> Nil

/// Reschedule a timer subscription after it fires.
/// Matches by the tag stored in the SubEntry (not string matching).
fn reschedule_timer(
  state: LoopState(model, msg),
  tag: String,
) -> LoopState(model, msg) {
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
  "title", "size", "width", "height", "position", "min_size", "max_size",
  "maximized", "fullscreen", "visible", "resizable", "closeable", "minimizable",
  "decorations", "transparent", "blur", "level", "exit_on_close_request",
]

/// Synchronize window lifecycle: open new windows, close removed ones,
/// and send update ops for windows whose tracked props changed.
fn sync_windows(
  new_tree: Node,
  old_windows: Set(String),
  new_windows: Set(String),
  old_tree: Option(Node),
  bridge: Subject(BridgeMessage),
  app: App(model, msg),
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
