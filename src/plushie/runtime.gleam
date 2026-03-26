//// Runtime: the Elm architecture update loop.
////
//// Owns the app model, executes init/update/view, diffs trees,
//// and sends patches to the bridge. Commands returned from update
//// are executed before the next view render.

import gleam/dict.{type Dict}
@target(erlang)
import gleam/dynamic.{type Dynamic}
@target(erlang)
import gleam/erlang/process.{type Pid, type Subject}
@target(erlang)
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
@target(erlang)
import gleam/otp/actor
import gleam/set.{type Set}
@target(erlang)
import gleam/string
@target(erlang)
import plushie/app.{type App}
@target(erlang)
import plushie/bridge.{
  type BridgeMessage, type RuntimeNotification, InboundEvent, RendererExited,
  Send,
}
@target(erlang)
import plushie/canvas_widget
@target(erlang)
import plushie/command.{type Command}
@target(erlang)
import plushie/command_encode
@target(erlang)
import plushie/effects
@target(erlang)
import plushie/event.{type Event}
import plushie/node.{type Node, type PropValue, StringVal}
@target(erlang)
import plushie/platform
import plushie/runtime_core

@target(erlang)
import plushie/protocol
@target(erlang)
import plushie/protocol/decode.{
  EffectStubAck, EventMessage, Hello, InteractResponse, InteractStep,
}
@target(erlang)
import plushie/protocol/encode
@target(erlang)
import plushie/subscription.{type Subscription}
@target(erlang)
import plushie/tree

// -- Public types ------------------------------------------------------------

@target(erlang)
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
  /// Query the current model (replies with dynamic model value).
  GetModel(reply: Subject(Dynamic))
  /// Query the current tree (replies with the latest normalized tree).
  GetTree(reply: Subject(Option(Node)))
  /// Register an effect stub with the renderer. The renderer sends
  /// an ack after storing the stub; the reply Subject is notified.
  RegisterEffectStub(
    kind: String,
    response: node.PropValue,
    reply: Subject(Nil),
  )
  /// Remove a previously registered effect stub. The renderer sends
  /// an ack after removing the stub; the reply Subject is notified.
  UnregisterEffectStub(kind: String, reply: Subject(Nil))
  /// Query accumulated prop validation warnings and clear them.
  GetPropWarnings(reply: Subject(List(#(String, String, List(String)))))
  /// Wait for an async task to complete. Replies when the task with
  /// the given tag finishes, or immediately if already done.
  AwaitAsync(tag: String, reply: Subject(Nil))
  /// Synchronous interact request (click, type_text, press, etc.).
  /// Sends the interact to the renderer and replies when complete.
  Interact(
    action: String,
    selector: Dict(String, node.PropValue),
    payload: Dict(String, node.PropValue),
    reply: Subject(Result(Nil, String)),
  )
}

@target(erlang)
/// Start options for the runtime.
pub type RuntimeOpts {
  RuntimeOpts(
    format: protocol.Format,
    session: String,
    daemon: Bool,
    app_opts: Dynamic,
    renderer_args: List(String),
    token: Option(String),
  )
}

@target(erlang)
/// Default runtime options.
pub fn default_opts() -> RuntimeOpts {
  RuntimeOpts(
    format: protocol.Msgpack,
    session: "",
    daemon: False,
    app_opts: dynamic.nil(),
    renderer_args: [],
    token: None,
  )
}

@target(erlang)
/// Start the runtime as an OTP actor under a supervisor.
///
/// The bridge is already running. The runtime registers its notification
/// subject with the bridge, initializes the app (settings, snapshot,
/// subscriptions, windows), and enters the actor message loop.
pub fn start_supervised(
  app: App(model, msg),
  bridge_subject: Subject(BridgeMessage),
  opts: RuntimeOpts,
  binary_path: String,
  name: process.Name(RuntimeMessage),
) -> Result(actor.Started(Subject(RuntimeMessage)), actor.StartError) {
  actor.new_with_initialiser(10_000, fn(subject) {
    let notification_subject = process.new_subject()

    // Register with the bridge so it forwards renderer events to us
    process.send(bridge_subject, bridge.RegisterRuntime(notification_subject))

    // Initialize the app
    let state =
      init_runtime(
        app,
        bridge_subject,
        subject,
        notification_subject,
        opts,
        binary_path,
      )

    // Build the selector for all message sources
    let selector = build_selector(subject, notification_subject)

    actor.initialised(state)
    |> actor.selecting(selector)
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.named(name)
  |> actor.start
}

// -- Internal state ----------------------------------------------------------

@target(erlang)
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
    // Pending effect stub ack replies, keyed by kind
    pending_stub_acks: Dict(String, Subject(Nil)),
    // Accumulated prop validation warnings from the renderer
    prop_warnings: List(#(String, String, List(String))),
    // Canvas widget state registry (scoped ID -> entry)
    cw_registry: canvas_widget.Registry,
    // Callers waiting for async task completion, keyed by tag
    pending_await_async: Dict(String, Subject(Nil)),
    // Pending interact: (caller_reply, request_id)
    pending_interact: Option(#(Subject(Result(Nil, String)), String)),
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

@target(erlang)
type SubEntry {
  TimerSub(timer: process.Timer, interval_ms: Int, tag: String)
  RendererSub(kind: String, max_rate: option.Option(Int))
}

// -- Actor init ---------------------------------------------------------------

@target(erlang)
/// Build the selector that unifies all message sources.
fn build_selector(
  self: Subject(RuntimeMessage),
  notifications: Subject(RuntimeNotification),
) -> process.Selector(RuntimeMessage) {
  process.new_selector()
  |> process.select(self)
  |> process.select_map(notifications, FromBridge)
  |> process.select_monitors(ProcessDown)
}

@target(erlang)
/// Initialize the runtime state: send settings, render initial view,
/// send snapshot, sync subscriptions and windows. Returns the initial
/// LoopState ready for the actor message loop.
fn init_runtime(
  app: App(model, msg),
  bridge: Subject(BridgeMessage),
  self: Subject(RuntimeMessage),
  notifications: Subject(RuntimeNotification),
  opts: RuntimeOpts,
  binary_path: String,
) -> LoopState(model, msg) {
  // Initialize
  let #(model, init_cmds) = app.get_init(app)(opts.app_opts)

  // Send settings to bridge
  let settings = app.get_settings(app)()
  send_encoded(
    bridge,
    encode.encode_settings(settings, opts.session, opts.format, opts.token),
  )

  // Render initial view
  let initial_tree =
    app.get_view(app)(model)
    |> tree.normalize_with_registry(canvas_widget.empty_registry())
  let initial_cw_registry = canvas_widget.derive_registry(initial_tree)

  // Send initial snapshot
  send_encoded(
    bridge,
    encode.encode_snapshot(initial_tree, opts.session, opts.format),
  )

  // Detect initial windows
  let initial_windows = runtime_core.detect_windows(initial_tree)

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
      pending_stub_acks: dict.new(),
      prop_warnings: [],
      cw_registry: initial_cw_registry,
      pending_await_async: dict.new(),
      pending_interact: None,
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

  // Sync subscriptions (timers, renderer event sources, canvas widget subs)
  let app_subs = safe_subscribe(state.app, state.model)
  let cw_subs = canvas_widget.collect_subscriptions(state.cw_registry)
  let state =
    LoopState(
      ..state,
      active_subs: sync_subscriptions(
        list.append(app_subs, cw_subs),
        state.active_subs,
        state.bridge,
        state.self,
        state.opts,
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

  state
}

// -- Actor message handler ----------------------------------------------------

@target(erlang)
fn handle_message(
  state: LoopState(model, msg),
  msg: RuntimeMessage,
) -> actor.Next(LoopState(model, msg), RuntimeMessage) {
  case msg {
    FromBridge(InboundEvent(EventMessage(event.PropValidation(
      node_id:,
      node_type:,
      warnings:,
    )))) -> {
      // Prop validation warnings are SDK bugs, not app events.
      // Log and accumulate -- never dispatch to the app.
      let warning_text =
        "plushie: prop validation warning on "
        <> node_type
        <> " \""
        <> node_id
        <> "\": "
        <> string.join(warnings, "; ")
      platform.log_warning(warning_text)
      let new_warnings = [
        #(node_id, node_type, warnings),
        ..state.prop_warnings
      ]
      LoopState(..state, prop_warnings: new_warnings)
      |> actor.continue()
    }

    FromBridge(InboundEvent(EventMessage(ev))) -> {
      // Reset restart count on successful communication
      let state = LoopState(..state, restart_count: 0)
      case runtime_core.coalesce_key(ev) {
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
          |> actor.continue()
        }
        None -> {
          // Non-coalescable: flush pending first, then process
          let state = flush_coalesced(state)
          let state = maybe_cancel_effect_timeout(state, ev)
          let new_state = handle_event(state, ev)
          // Stop runtime on AllWindowsClosed in non-daemon mode
          case ev, state.opts.daemon {
            event.AllWindowsClosed, False -> actor.stop()
            _, _ -> actor.continue(new_state)
          }
        }
      }
    }

    FromBridge(InboundEvent(Hello(protocol: proto, ..))) -> {
      case proto == protocol.protocol_version {
        True -> {
          let state = LoopState(..state, restart_count: 0)
          actor.continue(state)
        }
        False -> {
          platform.log_error(
            "plushie: protocol version mismatch (expected "
            <> int.to_string(protocol.protocol_version)
            <> ", got "
            <> int.to_string(proto)
            <> ") -- stopping runtime",
          )
          actor.stop()
        }
      }
    }

    FromBridge(InboundEvent(InteractStep(_id, events))) -> {
      // Process events through update+commands WITHOUT rendering after
      // each one. Matches Elixir's apply_event which defers view/render.
      let state =
        list.fold(events, state, fn(state, ev) { apply_event(state, ev) })
      // Render once and send a single snapshot (headless step protocol).
      let state = rerender(state)
      actor.continue(state)
    }

    FromBridge(InboundEvent(InteractResponse(_id, events))) -> {
      // Process any final events from the interact response.
      let state =
        list.fold(events, state, fn(state, ev) { handle_event(state, ev) })
      // Reply to the waiting caller
      let state = case state.pending_interact {
        Some(#(reply, _)) -> {
          process.send(reply, Ok(Nil))
          LoopState(..state, pending_interact: None)
        }
        None -> state
      }
      actor.continue(state)
    }

    FromBridge(InboundEvent(EffectStubAck(kind:))) -> {
      case dict.get(state.pending_stub_acks, kind) {
        Ok(reply) -> {
          process.send(reply, Nil)
          LoopState(
            ..state,
            pending_stub_acks: dict.delete(state.pending_stub_acks, kind),
          )
          |> actor.continue()
        }
        Error(_) -> actor.continue(state)
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
          actor.stop()
        }
        _ -> {
          // Crash -- attempt restart with exponential backoff
          case state.restart_count < state.max_restarts {
            True -> {
              let delay =
                calculate_backoff(state.restart_delay_base, state.restart_count)
              platform.log_warning(
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
              actor.continue(state)
            }
            False -> {
              platform.log_error(
                "plushie: renderer crashed "
                <> int.to_string(state.max_restarts)
                <> " times, giving up",
              )
              actor.stop()
            }
          }
        }
      }
    }

    InternalEvent(event) -> {
      // Remove delivered timer entry (SendAfter deduplication)
      let timer_key = platform.stable_hash_key(event)
      let state =
        LoopState(
          ..state,
          pending_timers: dict.delete(state.pending_timers, timer_key),
        )
      let new_state = handle_event(state, event)
      // D-033: stop runtime on AllWindowsClosed in non-daemon mode
      case event, state.opts.daemon {
        event.AllWindowsClosed, False -> actor.stop()
        _, _ -> actor.continue(new_state)
      }
    }

    InternalMsg(dyn_msg) -> {
      // Done/SendAfter deliver msg values wrapped as Dynamic.
      // Remove delivered timer entry for deduplication.
      let timer_key = platform.stable_hash_key(dyn_msg)
      let state =
        LoopState(
          ..state,
          pending_timers: dict.delete(state.pending_timers, timer_key),
        )
      // Unsafe coerce: the Dynamic contains a value of type msg
      let msg = unsafe_coerce_dynamic(dyn_msg)
      let new_state = handle_msg(state, msg)
      actor.continue(new_state)
    }

    TimerFired(tag:) -> {
      // Drain any queued ticks for the same tag to coalesce rapid-fire
      // timer events (only the latest tick matters).
      drain_matching_ticks(state.self, tag)
      let timestamp = erlang_monotonic_time()
      // Check if this timer belongs to a canvas widget
      let new_state = case canvas_widget.is_widget_tag(tag) {
        True -> {
          let #(maybe_event, new_registry) =
            canvas_widget.handle_widget_timer(state.cw_registry, tag, timestamp)
          let state = LoopState(..state, cw_registry: new_registry)
          case maybe_event {
            Some(ev) -> handle_event(state, ev)
            None -> rerender(state)
          }
        }
        False -> handle_event(state, event.TimerTick(tag:, timestamp:))
      }
      reschedule_timer(new_state, tag) |> actor.continue()
    }

    AsyncComplete(tag:, nonce:, result:) -> {
      // Validate nonce matches current task -- discard stale results
      case dict.get(state.async_tasks, tag) {
        Ok(#(_, current_nonce, monitor)) if current_nonce == nonce -> {
          process.demonitor_process(monitor)
          let new_state = handle_event(state, event.AsyncResult(tag:, result:))
          let new_state =
            LoopState(
              ..new_state,
              async_tasks: dict.delete(new_state.async_tasks, tag),
            )
          notify_await_async(new_state, tag)
          |> actor.continue()
        }
        _ -> actor.continue(state)
      }
    }

    StreamEmit(tag:, nonce:, value:) -> {
      // Validate nonce matches current stream -- discard stale emissions
      case dict.get(state.async_tasks, tag) {
        Ok(#(_, current_nonce, _)) if current_nonce == nonce -> {
          handle_event(state, event.StreamValue(tag:, value:))
          |> actor.continue()
        }
        _ -> actor.continue(state)
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
          |> actor.continue()
        }
        Error(_) -> actor.continue(state)
      }
    }

    CoalesceFlush -> {
      flush_coalesced(state) |> actor.continue()
    }

    ProcessDown(process.ProcessDown(monitor: _, pid: down_pid, reason: reason)) -> {
      // Check if this is the bridge actor dying (D-039)
      let is_bridge = case state.bridge_pid {
        Some(bpid) -> bpid == down_pid
        None -> False
      }
      case is_bridge {
        True -> {
          platform.log_warning(
            "plushie: bridge process died unexpectedly: "
            <> string.inspect(reason),
          )
          // Treat it like a renderer exit -- attempt restart
          case state.restart_count < state.max_restarts {
            True -> {
              let delay =
                calculate_backoff(state.restart_delay_base, state.restart_count)
              process.send_after(state.self, delay, RestartRenderer)
              actor.continue(LoopState(..state, bridge_pid: None))
            }
            False -> {
              platform.log_error(
                "plushie: bridge crashed too many times, giving up",
              )
              actor.stop()
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
              let state = notify_await_async(state, tag)
              case reason {
                process.Normal -> actor.continue(state)
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
                  |> actor.continue()
                }
              }
            }
            None -> actor.continue(state)
          }
        }
      }
    }

    // PortDown is not expected but handle gracefully
    ProcessDown(process.PortDown(..)) -> actor.continue(state)

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

          platform.log_info(
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
            actor.stop()
          })
          let state = LoopState(..state, pending_timers: dict.new())

          // Flush pending effects with error (old renderer is gone).
          // Commands from the app's error handlers go to new_bridge.
          let state = flush_pending_effects_on_restart(state)

          // Flush pending stub acks (old renderer is gone, stubs lost).
          dict.each(state.pending_stub_acks, fn(_kind, reply) {
            process.send(reply, Nil)
          })
          let state = LoopState(..state, pending_stub_acks: dict.new())

          // Fail pending interact (old renderer is gone).
          let state = case state.pending_interact {
            Some(#(reply, _)) -> {
              process.send(reply, Error("renderer_restarted"))
              LoopState(..state, pending_interact: None)
            }
            None -> state
          }

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
              state.opts.token,
            ),
          )

          // Re-render view and send fresh snapshot
          let view_fn = app.get_view(state.app)
          let #(tree, cw_registry) = case
            platform.try_call(fn() { view_fn(state.model) })
          {
            Ok(t) -> {
              let normalized =
                tree.normalize_with_registry(t, state.cw_registry)
              #(Some(normalized), canvas_widget.derive_registry(normalized))
            }
            Error(_) -> #(state.tree, state.cw_registry)
          }
          case tree {
            Some(t) ->
              send_encoded(
                new_bridge,
                encode.encode_snapshot(t, state.opts.session, state.opts.format),
              )
            None -> Nil
          }

          // Re-sync subscriptions with new renderer (incl. canvas widget subs)
          let restart_app_subs = safe_subscribe(state.app, state.model)
          let restart_cw_subs = canvas_widget.collect_subscriptions(cw_registry)
          let new_subs =
            sync_subscriptions(
              list.append(restart_app_subs, restart_cw_subs),
              dict.new(),
              new_bridge,
              state.self,
              state.opts,
            )

          // Re-open all windows
          let windows = case tree {
            Some(t) -> {
              let new_windows = runtime_core.detect_windows(t)
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
              cw_registry:,
              restart_count: new_count,
            )
          // Update the selector to use the new notification subject
          let new_selector = build_selector(state.self, state.notifications)
          actor.continue(state)
          |> actor.with_selector(new_selector)
        }
        Error(_) -> {
          platform.log_error("plushie: failed to restart renderer, giving up")
          actor.stop()
        }
      }
    }

    ForceRerender -> {
      platform.log_info("plushie runtime: force re-render (code reload)")
      // Re-render view and diff/patch
      let view_fn = app.get_view(state.app)
      case platform.try_call(fn() { view_fn(state.model) }) {
        Ok(new_tree_raw) -> {
          let new_tree =
            tree.normalize_with_registry(new_tree_raw, state.cw_registry)
          let new_cw_registry = canvas_widget.derive_registry(new_tree)
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
          // Re-sync subscriptions (including canvas widget subscriptions)
          let app_subs = safe_subscribe(state.app, state.model)
          let cw_subs = canvas_widget.collect_subscriptions(new_cw_registry)
          let new_subs =
            sync_subscriptions(
              list.append(app_subs, cw_subs),
              state.active_subs,
              state.bridge,
              state.self,
              state.opts,
            )
          // Re-sync windows
          let new_windows = runtime_core.detect_windows(new_tree)
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
            cw_registry: new_cw_registry,
          )
          |> actor.continue()
        }
        Error(reason) -> {
          platform.log_error(
            "plushie runtime: force re-render view crashed: "
            <> string.inspect(reason),
          )
          actor.continue(state)
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
      // Flush pending stub acks
      dict.each(state.pending_stub_acks, fn(_kind, reply) {
        process.send(reply, Nil)
      })
      // Stop the bridge actor
      process.send(state.bridge, bridge.Shutdown)
      actor.stop()
    }

    GetModel(reply:) -> {
      process.send(reply, to_dynamic(state.model))
      actor.continue(state)
    }

    GetTree(reply:) -> {
      process.send(reply, state.tree)
      actor.continue(state)
    }

    GetPropWarnings(reply:) -> {
      process.send(reply, state.prop_warnings)
      LoopState(..state, prop_warnings: [])
      |> actor.continue()
    }

    AwaitAsync(tag:, reply:) -> {
      case dict.has_key(state.async_tasks, tag) {
        True -> {
          // Task still running -- store caller and reply when done
          let pending = dict.insert(state.pending_await_async, tag, reply)
          LoopState(..state, pending_await_async: pending)
          |> actor.continue()
        }
        False -> {
          // Task already completed (or never existed)
          process.send(reply, Nil)
          actor.continue(state)
        }
      }
    }

    Interact(action:, selector:, payload:, reply:) -> {
      let req_id = "interact_" <> int.to_string(state.nonce_counter)
      let state =
        LoopState(
          ..state,
          nonce_counter: state.nonce_counter + 1,
          pending_interact: Some(#(reply, req_id)),
        )
      send_encoded(
        state.bridge,
        encode.encode_interact(
          req_id,
          action,
          selector,
          payload,
          state.opts.session,
          state.opts.format,
        ),
      )
      actor.continue(state)
    }

    RegisterEffectStub(kind:, response:, reply:) -> {
      send_encoded(
        state.bridge,
        encode.encode_register_effect_stub(
          kind,
          response,
          state.opts.session,
          state.opts.format,
        ),
      )
      let pending = dict.insert(state.pending_stub_acks, kind, reply)
      LoopState(..state, pending_stub_acks: pending)
      |> actor.continue()
    }

    UnregisterEffectStub(kind:, reply:) -> {
      send_encoded(
        state.bridge,
        encode.encode_unregister_effect_stub(
          kind,
          state.opts.session,
          state.opts.format,
        ),
      )
      let pending = dict.insert(state.pending_stub_acks, kind, reply)
      LoopState(..state, pending_stub_acks: pending)
      |> actor.continue()
    }
  }
}

@external(erlang, "erlang", "monotonic_time")
fn erlang_monotonic_time() -> Int

@target(erlang)
/// Widen a generic value to Dynamic for the GetModel reply.
/// The model type parameter is erased at the RuntimeMessage boundary,
/// so this identity function bridges the gap at zero runtime cost.
@external(erlang, "plushie_ffi", "identity")
fn to_dynamic(value: a) -> Dynamic

// -- Event coalescing --------------------------------------------------------

@target(erlang)
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

@target(erlang)
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

@target(erlang)
const max_backoff_ms = 5000

@target(erlang)
fn calculate_backoff(base: Int, attempt: Int) -> Int {
  let delay = base * pow2(attempt)
  case delay > max_backoff_ms {
    True -> max_backoff_ms
    False -> delay
  }
}

@target(erlang)
fn pow2(n: Int) -> Int {
  case n {
    0 -> 1
    _ -> 2 * pow2(n - 1)
  }
}

@target(erlang)
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

@external(erlang, "erlang", "element")
fn erlang_element(n: Int, tuple: a) -> b

@target(erlang)
/// Coerce a Dynamic back to the msg type. Safe because we only store
/// msg values as Dynamic in InternalMsg, and the type parameter is
/// consistent within a single runtime instance.
fn unsafe_coerce_dynamic(dyn: Dynamic) -> msg {
  let boxed = #(dyn)
  erlang_element(1, boxed)
}

@target(erlang)
/// Coerce any value to Dynamic for transport through RuntimeMessage.
fn coerce_to_dynamic(value: a) -> Dynamic {
  let boxed = #(value)
  erlang_element(1, boxed)
}

@target(erlang)
/// Handle a message that is already the app's msg type (from Done/SendAfter).
/// Runs the full update cycle without event mapping.
fn handle_msg(state: LoopState(model, msg), msg: msg) -> LoopState(model, msg) {
  dispatch_update(state, msg)
}

@target(erlang)
/// Re-render the view without going through update. Used when
/// canvas_widget state changes internally (event consumed or
/// timer handled by widget) but the app model hasn't changed.
fn rerender(state: LoopState(model, msg)) -> LoopState(model, msg) {
  let view_fn = app.get_view(state.app)
  case platform.try_call(fn() { view_fn(state.model) }) {
    Ok(new_tree_raw) -> {
      let new_tree =
        tree.normalize_with_registry(new_tree_raw, state.cw_registry)
      let new_cw_registry = canvas_widget.derive_registry(new_tree)

      // Diff and send patch
      case state.tree {
        Some(old_tree) -> {
          let ops = tree.diff(old_tree, new_tree)
          case ops {
            [] -> Nil
            _ ->
              send_encoded(
                state.bridge,
                encode.encode_patch(ops, state.opts.session, state.opts.format),
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

      // Sync subscriptions (including canvas widget subscriptions)
      let app_subs = safe_subscribe(state.app, state.model)
      let cw_subs = canvas_widget.collect_subscriptions(new_cw_registry)
      let new_subs =
        sync_subscriptions(
          list.append(app_subs, cw_subs),
          state.active_subs,
          state.bridge,
          state.self,
          state.opts,
        )

      let new_windows = runtime_core.detect_windows(new_tree)
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
        cw_registry: new_cw_registry,
      )
    }
    Error(reason) -> {
      platform.log_warning(
        "plushie: view error during rerender: " <> dynamic.classify(reason),
      )
      state
    }
  }
}

@target(erlang)
/// Process an event through update + commands WITHOUT rendering.
/// Used by interact_step to batch events before a single render.
/// Matches Elixir's apply_event (runtime.ex lines 972-987).
fn apply_event(
  state: LoopState(model, msg),
  event: Event,
) -> LoopState(model, msg) {
  // Route through canvas_widget scope chain
  let #(maybe_event, new_registry) =
    canvas_widget.dispatch_through_widgets(state.cw_registry, event)
  let state = LoopState(..state, cw_registry: new_registry)
  case maybe_event {
    Some(ev) -> {
      let mapped_msg = runtime_core.map_event(state.app, ev)
      let update_fn = app.get_update(state.app)
      case platform.try_call(fn() { update_fn(state.model, mapped_msg) }) {
        Ok(#(new_model, commands)) -> {
          let state = LoopState(..state, model: new_model)
          execute_commands(commands, state)
        }
        Error(_) -> state
      }
    }
    None -> state
  }
}

@target(erlang)
/// Handle a wire event by routing through canvas_widget handlers
/// first, then mapping to the app's msg type.
fn handle_event(
  state: LoopState(model, msg),
  event: Event,
) -> LoopState(model, msg) {
  // Route through canvas_widget scope chain
  let #(maybe_event, new_registry) =
    canvas_widget.dispatch_through_widgets(state.cw_registry, event)
  let state = LoopState(..state, cw_registry: new_registry)
  case maybe_event {
    Some(ev) -> {
      let mapped_msg = runtime_core.map_event(state.app, ev)
      dispatch_update(state, mapped_msg)
    }
    None -> {
      // Event was consumed by a canvas_widget. Still need to re-render
      // since widget state may have changed.
      rerender(state)
    }
  }
}

@target(erlang)
/// Core update cycle: call update -> execute commands -> render view ->
/// diff -> patch -> sync subscriptions -> sync windows.
fn dispatch_update(
  state: LoopState(model, msg),
  msg: msg,
) -> LoopState(model, msg) {
  let update_fn = app.get_update(state.app)

  case platform.try_call(fn() { update_fn(state.model, msg) }) {
    Ok(#(new_model, commands)) -> {
      // Execute commands (before view, matching Elixir SDK)
      let state_after_cmds =
        execute_commands(commands, LoopState(..state, model: new_model))
      let new_model = state_after_cmds.model

      // Render view
      let view_fn = app.get_view(state.app)
      case platform.try_call(fn() { view_fn(new_model) }) {
        Ok(new_tree_raw) -> {
          let new_tree =
            tree.normalize_with_registry(
              new_tree_raw,
              state_after_cmds.cw_registry,
            )
          let new_cw_registry = canvas_widget.derive_registry(new_tree)

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
            None -> {
              send_encoded(
                state.bridge,
                encode.encode_snapshot(
                  new_tree,
                  state.opts.session,
                  state.opts.format,
                ),
              )
            }
          }

          // Sync subscriptions (including canvas widget subscriptions)
          let app_subs = safe_subscribe(state.app, new_model)
          let cw_subs = canvas_widget.collect_subscriptions(new_cw_registry)
          let new_subs =
            sync_subscriptions(
              list.append(app_subs, cw_subs),
              state.active_subs,
              state.bridge,
              state.self,
              state.opts,
            )

          let new_windows = runtime_core.detect_windows(new_tree)

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
            cw_registry: new_cw_registry,
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
              platform.log_warning(
                "plushie: view error: " <> dynamic.classify(reason),
              )
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
          platform.log_warning(
            "plushie: update error: " <> dynamic.classify(reason),
          )
        False -> Nil
      }
      LoopState(..state, errors: err_count)
    }
  }
}

// -- Command execution -------------------------------------------------------

@target(erlang)
fn execute_commands(
  cmd: Command(msg),
  state: LoopState(model, msg),
) -> LoopState(model, msg) {
  case command_encode.classify(cmd) {
    command_encode.NoOp -> state

    command_encode.RunBatch(commands) ->
      list.fold(commands, state, fn(s, c) { execute_commands(c, s) })

    command_encode.Exit -> {
      process.send(state.self, Shutdown)
      state
    }

    command_encode.ScheduleTimer(delay_ms, msg) -> {
      let timer_key = platform.stable_hash_key(msg)
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

    command_encode.DoneImmediate(value, mapper) -> {
      let mapped_msg = mapper(value)
      process.send(state.self, InternalMsg(coerce_to_dynamic(mapped_msg)))
      state
    }

    command_encode.SpawnAsync(tag, work) -> {
      // Kill existing task for same tag before starting a new one
      let state = cancel_existing_task(state, tag)
      let nonce = state.nonce_counter + 1
      let runtime_self = state.self
      let pid =
        process.spawn(fn() {
          let result = case platform.try_call(work) {
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

    command_encode.SpawnStream(tag, work) -> {
      // Kill existing task for same tag before starting a new one
      let state = cancel_existing_task(state, tag)
      let nonce = state.nonce_counter + 1
      let runtime_self = state.self
      let emit = fn(value) {
        process.send(runtime_self, StreamEmit(tag:, nonce:, value:))
      }
      let pid =
        process.spawn(fn() {
          let result = case platform.try_call(fn() { work(emit) }) {
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

    command_encode.CancelTask(tag) -> cancel_existing_task(state, tag)

    command_encode.WidgetOp(op, payload) -> {
      send_widget_op(state.bridge, op, payload, state.opts)
      state
    }

    command_encode.WindowOp(op, window_id, settings) -> {
      send_window_op(state.bridge, op, window_id, settings, state.opts)
      state
    }

    command_encode.WindowQuery(op, window_id, tag) -> {
      send_window_query(state.bridge, op, window_id, tag, state.opts)
      state
    }

    command_encode.ImageOp(op, payload) -> {
      send_image_op(state.bridge, op, payload, state.opts)
      state
    }

    command_encode.EffectRequest(id, kind, payload) -> {
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

    command_encode.ExtensionCmd(node_id, op, payload) -> {
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

    command_encode.ExtensionBatch(commands) -> {
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

    command_encode.AdvanceFrame(timestamp) -> {
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
  }
}

@target(erlang)
/// Kill an existing async task with the given tag and clean up its monitor.
fn cancel_existing_task(
  state: LoopState(model, msg),
  tag: String,
) -> LoopState(model, msg) {
  case dict.get(state.async_tasks, tag) {
    Ok(#(pid, _nonce, monitor)) -> {
      process.demonitor_process(monitor)
      process.kill(pid)
      let state =
        LoopState(..state, async_tasks: dict.delete(state.async_tasks, tag))
      notify_await_async(state, tag)
    }
    Error(_) -> state
  }
}

// -- Await async notification ------------------------------------------------

@target(erlang)
/// Notify any caller waiting on an async task via AwaitAsync.
fn notify_await_async(
  state: LoopState(model, msg),
  tag: String,
) -> LoopState(model, msg) {
  case dict.get(state.pending_await_async, tag) {
    Ok(reply) -> {
      process.send(reply, Nil)
      LoopState(
        ..state,
        pending_await_async: dict.delete(state.pending_await_async, tag),
      )
    }
    Error(_) -> state
  }
}

// -- Wire helpers ------------------------------------------------------------

@target(erlang)
fn send_encoded(
  bridge: Subject(BridgeMessage),
  result: Result(BitArray, protocol.EncodeError),
) -> Nil {
  case result {
    Ok(bytes) -> process.send(bridge, Send(data: bytes))
    Error(err) -> {
      platform.log_error(
        "plushie: encode error: " <> protocol.encode_error_to_string(err),
      )
      Nil
    }
  }
}

@target(erlang)
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

@target(erlang)
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

@target(erlang)
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

@target(erlang)
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

// -- Subscription management -------------------------------------------------

@target(erlang)
/// Call the app's subscribe callback wrapped in try_call.
/// On error, log and return an empty list so the runtime stays alive.
fn safe_subscribe(
  application: App(model, msg),
  model: model,
) -> List(Subscription) {
  let subscribe_fn = app.get_subscribe(application)
  case platform.try_call(fn() { subscribe_fn(model) }) {
    Ok(subs) -> subs
    Error(reason) -> {
      platform.log_warning(
        "plushie runtime: subscribe/1 raised: " <> string.inspect(reason),
      )
      []
    }
  }
}

@target(erlang)
fn sync_subscriptions(
  desired: List(Subscription),
  current: Dict(String, SubEntry),
  bridge: Subject(BridgeMessage),
  self: Subject(RuntimeMessage),
  opts: RuntimeOpts,
) -> Dict(String, SubEntry) {
  let desired_by_key =
    list.fold(desired, dict.new(), fn(acc, sub) {
      let k = runtime_core.subscription_key_string(sub)
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

@target(erlang)
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

@target(erlang)
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

@target(erlang)
/// Drain queued TimerFired messages for the same tag from the mailbox.
/// Uses Erlang selective receive (via FFI) with zero timeout to consume
/// only matching messages without disturbing other mailbox contents.
/// This coalesces rapid-fire timer ticks so the runtime only processes
/// the latest one.
@external(erlang, "plushie_ffi", "drain_timer_ticks")
fn drain_matching_ticks(subject: Subject(RuntimeMessage), tag: String) -> Nil

@target(erlang)
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

@target(erlang)
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
    let per_window = runtime_core.extract_window_props(new_tree, window_id)
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
        let old_props = runtime_core.extract_window_props(old, window_id)
        let new_props = runtime_core.extract_window_props(new_tree, window_id)
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
