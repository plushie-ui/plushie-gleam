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
  RendererRestarted, Send,
}
@target(erlang)
import plushie/command.{type Command}
@target(erlang)
import plushie/command_encode
@target(erlang)
import plushie/effect
@target(erlang)
import plushie/event.{type Event}
import plushie/node.{type Node, type PropValue, StringVal}
@target(erlang)
import plushie/platform
@target(erlang)
import plushie/renderer_exit
import plushie/runtime_core
@target(erlang)
import plushie/widget

@target(erlang)
import plushie/protocol
@target(erlang)
import plushie/protocol/decode.{
  EffectResponseRaw, EffectStubAck, EventMessage, Hello, InteractResponse,
  InteractStep,
}
@target(erlang)
import plushie/protocol/encode
@target(erlang)
import plushie/subscription.{type Subscription}
@target(erlang)
import plushie/telemetry
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
  /// Internal msg dispatch (Done, SendAfter, already mapped to msg).
  /// The nonce distinguishes current from stale timer deliveries.
  InternalMsg(Dynamic, Int)
  /// Subscription timer fired.
  TimerFired(tag: String)
  /// Async task completed with nonce for freshness validation.
  AsyncComplete(tag: String, nonce: Int, result: Result(Dynamic, Dynamic))
  /// Stream emitted a value with nonce for freshness validation.
  StreamEmit(tag: String, nonce: Int, value: Dynamic)
  /// Effect request timed out.
  EffectTimeout(request_id: String)
  /// Interact request timed out.
  InteractTimeout(request_id: String)
  /// Flush deferred coalescable events (zero-delay timer).
  CoalesceFlush
  /// Monitored async task process exited.
  ProcessDown(process.Down)
  /// Force a re-render without resetting state (dev-mode live reload).
  ForceRerender
  /// Shutdown.
  Shutdown
  /// Query the current model (replies with dynamic model value).
  GetModel(reply: Subject(Dynamic))
  /// Query the current tree (replies with the latest normalized tree).
  GetTree(reply: Subject(Option(Node)))
  /// Query the currently focused widget ID.
  GetFocused(reply: Subject(Option(String)))
  /// Check if the tree is stale due to consecutive view errors.
  IsViewDesynced(reply: Subject(Bool))
  /// Register an effect stub with the renderer. The renderer sends
  /// an ack after storing the stub; the reply Subject is notified.
  RegisterEffectStub(
    kind: String,
    response: node.PropValue,
    reply: Subject(Result(Nil, String)),
  )
  /// Remove a previously registered effect stub. The renderer sends
  /// an ack after removing the stub; the reply Subject is notified.
  UnregisterEffectStub(kind: String, reply: Subject(Result(Nil, String)))
  /// Query accumulated prop validation warnings and clear them.
  GetPropWarnings(reply: Subject(List(PropWarning)))
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
  /// Query runtime health status.
  GetHealth(reply: Subject(HealthStatus))
  /// Set or clear the dev overlay message. Sent by the dev server
  /// to show rebuild status, or by view error tracking for frozen UI.
  SetDevOverlay(message: Option(String))
}

@target(erlang)
/// Start options for the runtime.
pub type RuntimeOpts {
  RuntimeOpts(
    format: protocol.Format,
    session: String,
    daemon: Bool,
    app_opts: Dynamic,
    required_native_widgets: List(String),
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
    required_native_widgets: [],
    renderer_args: [],
    token: None,
  )
}

fn missing_native_widgets(
  required: List(String),
  available: List(String),
) -> List(String) {
  list.filter(required, fn(key) { !list.contains(available, key) })
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
  _binary_path: String,
  name: process.Name(RuntimeMessage),
) -> Result(actor.Started(Subject(RuntimeMessage)), actor.StartError) {
  actor.new_with_initialiser(10_000, fn(subject) {
    let notification_subject = process.new_subject()

    // Register with the bridge so it forwards renderer events to us
    process.send(bridge_subject, bridge.RegisterRuntime(notification_subject))

    // Initialize the app
    let state =
      init_runtime(app, bridge_subject, subject, notification_subject, opts)

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

// Named record types replace anonymous tuples for clarity.

@target(erlang)
type AsyncTask {
  AsyncTask(pid: Pid, nonce: Int, monitor: process.Monitor)
}

@target(erlang)
type PendingEffect {
  PendingEffect(tag: String, timer: process.Timer)
}

@target(erlang)
type PendingTimer {
  PendingTimer(timer: process.Timer, nonce: Int)
}

@target(erlang)
type PendingInteract {
  PendingInteract(
    reply: Subject(Result(Nil, String)),
    request_id: String,
    monitor: process.Monitor,
    timer: process.Timer,
  )
}

/// Prop validation warning from the renderer for a specific node.
pub type PropWarning {
  PropWarning(node_id: String, node_type: String, warnings: List(String))
}

/// Health status snapshot from a running runtime.
pub type HealthStatus {
  HealthStatus(
    /// Consecutive update/view errors since the last successful update
    /// cycle or renderer restart. Resets to zero on either.
    errors: Int,
    /// Number of consecutive view failures without a successful render.
    /// Resets to zero on successful view render.
    consecutive_view_errors: Int,
    /// Number of accumulated prop validation warnings from the renderer.
    prop_warning_count: Int,
    /// True when the UI is stale due to repeated view failures
    /// (consecutive_view_errors > 0).
    view_desynced: Bool,
  )
}

// Sub-manager types group related fields from LoopState.

@target(erlang)
type AsyncTracker {
  AsyncTracker(
    tasks: Dict(String, AsyncTask),
    nonce_counter: Int,
    await_callers: Dict(String, Subject(Nil)),
  )
}

@target(erlang)
type EffectTracker {
  EffectTracker(
    pending: Dict(String, PendingEffect),
    stub_acks: Dict(String, Subject(Result(Nil, String))),
  )
}

@target(erlang)
type CoalesceState {
  CoalesceState(
    events: Dict(String, Event),
    order: List(String),
    timer: Option(process.Timer),
  )
}

@target(erlang)
type FocusState {
  FocusState(
    widget_statuses: Dict(String, String),
    focused_widget_id: Option(String),
  )
}

@target(erlang)
type ErrorState {
  ErrorState(
    errors: Int,
    consecutive_view_errors: Int,
    prop_warnings: List(PropWarning),
  )
}

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
    sub_keys_cache: List(String),
    windows: Set(String),
    opts: RuntimeOpts,
    cw_registry: widget.Registry,
    memo_cache: tree.MemoCache,
    async: AsyncTracker,
    effects: EffectTracker,
    timers: Dict(String, PendingTimer),
    coalesce: CoalesceState,
    interact: Option(PendingInteract),
    focus: FocusState,
    error_state: ErrorState,
    dev_overlay: Option(String),
  )
}

@target(erlang)
type SubEntry {
  TimerSub(timer: process.Timer, interval_ms: Int, tag: String)
  RendererSub(
    kind: String,
    wire_tag: String,
    max_rate: option.Option(Int),
    window_id: option.Option(String),
  )
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
) -> LoopState(model, msg) {
  // Initialize
  let #(model, init_cmds) = app.get_init(app)(opts.app_opts)

  // Send settings to bridge (protected: a crashing settings callback
  // should not prevent startup; fall back to default settings)
  let settings = case platform.try_call(fn() { app.get_settings(app)() }) {
    Ok(s) -> s
    Error(reason) -> {
      platform.log_error(
        "plushie: settings() callback crashed: " <> string.inspect(reason),
      )
      app.default_settings()
    }
  }
  send_encoded(
    bridge,
    encode.encode_settings(settings, opts.session, opts.format, opts.token),
  )

  // Render initial view (panic on failure: no old tree to fall back to)
  let assert Ok(tree.NormalizeResult(
    tree: initial_tree,
    memo_cache: initial_memo_cache,
    registry: initial_cw_registry,
    windows: initial_windows,
  )) =
    try_normalize_view(
      app.get_view(app)(model),
      widget.empty_registry(),
      tree.empty_memo_cache(),
    )

  // Send initial snapshot
  send_encoded(
    bridge,
    encode.encode_snapshot(initial_tree, opts.session, opts.format),
  )

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
      sub_keys_cache: [],
      windows: initial_windows,
      opts:,
      cw_registry: initial_cw_registry,
      memo_cache: initial_memo_cache,
      async: AsyncTracker(
        tasks: dict.new(),
        nonce_counter: 0,
        await_callers: dict.new(),
      ),
      effects: EffectTracker(pending: dict.new(), stub_acks: dict.new()),
      timers: dict.new(),
      coalesce: CoalesceState(events: dict.new(), order: [], timer: None),
      interact: None,
      focus: FocusState(widget_statuses: dict.new(), focused_widget_id: None),
      error_state: ErrorState(
        errors: 0,
        consecutive_view_errors: 0,
        prop_warnings: [],
      ),
      dev_overlay: None,
    )

  // Execute init commands (threads full state for PID tracking)
  let state = execute_commands(init_cmds, state)

  // Sync subscriptions (timers, renderer event sources, widget subs)
  let app_subs = safe_subscribe(state.app, state.model)
  let cw_subs = widget.collect_subscriptions(state.cw_registry)
  let #(new_subs, new_sub_keys_cache) =
    sync_subscriptions(
      list.append(app_subs, cw_subs),
      state.active_subs,
      state.sub_keys_cache,
      state.bridge,
      state.self,
      state.opts,
    )
  let state =
    LoopState(
      ..state,
      active_subs: new_subs,
      sub_keys_cache: new_sub_keys_cache,
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
    FromBridge(InboundEvent(EventMessage(event.Error(event.PropValidation(
      node_id:,
      node_type:,
      warnings:,
    ))))) -> {
      // Prop validation warnings are SDK bugs, not app events.
      // Log and accumulate; never dispatch to the app.
      let warning_text =
        "plushie: prop validation warning on "
        <> node_type
        <> " \""
        <> node_id
        <> "\": "
        <> string.join(warnings, "; ")
      platform.log_warning(warning_text)
      let new_warnings = [
        PropWarning(node_id:, node_type:, warnings:),
        ..state.error_state.prop_warnings
      ]
      LoopState(
        ..state,
        error_state: ErrorState(
          ..state.error_state,
          prop_warnings: new_warnings,
        ),
      )
      |> actor.continue()
    }

    // Intercept diagnostic events: emit as telemetry, don't dispatch to update.
    FromBridge(InboundEvent(EventMessage(event.Error(event.Diagnostic(
      level:,
      element_id:,
      code:,
      message:,
    ))))) -> {
      let prefix = case element_id {
        "" -> ""
        id -> " [" <> id <> "]"
      }
      let log_msg = "plushie:" <> prefix <> " " <> code <> ": " <> message
      case level {
        "error" -> platform.log_error(log_msg)
        "info" -> platform.log_info(log_msg)
        _ -> platform.log_warning(log_msg)
      }
      actor.continue(state)
    }

    // Intercept duplicate node ID warnings: these are SDK-level issues,
    // not app events. Log and consume without dispatching to update.
    FromBridge(InboundEvent(EventMessage(event.Error(event.DuplicateNodeIds(
      _details,
    ))))) -> {
      platform.log_warning(
        "plushie: renderer reported duplicate node IDs in the tree",
      )
      actor.continue(state)
    }

    // Intercept and consume status events for internal focus tracking.
    // These are SDK-internal; they do not reach the app's update function.
    FromBridge(InboundEvent(EventMessage(event.Widget(event.Status(
      target:,
      value: status_value,
    ))))) -> {
      let state = track_focus_from_status(state, target, status_value)
      actor.continue(state)
    }

    FromBridge(InboundEvent(EventMessage(ev))) -> {
      case runtime_core.coalesce_key(ev) {
        Some(key) -> {
          // Defer this event; latest value wins
          // Track insertion order so flush processes events in arrival order.
          let coal = state.coalesce
          let new_order = case dict.has_key(coal.events, key) {
            True -> coal.order
            False -> [key, ..coal.order]
          }
          let new_events = dict.insert(coal.events, key, ev)
          let new_timer = case coal.timer {
            Some(_) -> coal.timer
            None -> Some(process.send_after(state.self, 0, CoalesceFlush))
          }
          LoopState(
            ..state,
            coalesce: CoalesceState(
              events: new_events,
              order: new_order,
              timer: new_timer,
            ),
          )
          |> actor.continue()
        }
        None -> {
          // Non-coalescable: flush pending first, then process
          let state = flush_coalesced(state)
          let new_state = handle_event(state, ev)
          // Stop runtime on AllWindowsClosed in non-daemon mode
          case ev, state.opts.daemon {
            event.System(event.AllWindowsClosed), False -> actor.stop()
            _, _ -> actor.continue(new_state)
          }
        }
      }
    }

    FromBridge(InboundEvent(Hello(
      protocol: proto,
      version:,
      native_widgets:,
      ..,
    ))) -> {
      // Warn on renderer binary version mismatch (non-fatal)
      case version != "" && version != protocol.expected_renderer_version {
        True ->
          platform.log_warning(
            "plushie: renderer version mismatch (SDK expects "
            <> protocol.expected_renderer_version
            <> ", renderer reports "
            <> version
            <> ")",
          )
        False -> Nil
      }
      case proto == protocol.protocol_version {
        True ->
          case
            missing_native_widgets(
              state.opts.required_native_widgets,
              native_widgets,
            )
          {
            [] -> {
              actor.continue(state)
            }
            missing -> {
              platform.log_error(
                "plushie: renderer is missing required native widgets "
                <> string.inspect(missing)
                <> " (reported "
                <> string.inspect(native_widgets)
                <> "); stopping runtime",
              )
              actor.stop()
            }
          }
        False -> {
          platform.log_error(
            "plushie: protocol version mismatch (expected "
            <> int.to_string(protocol.protocol_version)
            <> ", got "
            <> int.to_string(proto)
            <> "); stopping runtime",
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
      // Render once and diff/patch after processing all step events.
      let state = rerender(state)
      actor.continue(state)
    }

    FromBridge(InboundEvent(InteractResponse(resp_id, events))) -> {
      // Process any final events from the interact response.
      let state =
        list.fold(events, state, fn(state, ev) { handle_event(state, ev) })
      // Reply to the waiting caller and demonitor. Pin-match the
      // response ID against the pending request ID to guard against
      // stale responses from a previous interaction.
      let state = case state.interact {
        Some(PendingInteract(reply:, request_id:, monitor:, timer:))
          if request_id == resp_id
        -> {
          process.demonitor_process(monitor)
          process.cancel_timer(timer)
          process.send(reply, Ok(Nil))
          LoopState(..state, interact: None)
        }
        _ -> state
      }
      actor.continue(state)
    }

    FromBridge(InboundEvent(EffectResponseRaw(wire_id:, result:))) -> {
      case dict.get(state.effects.pending, wire_id) {
        Ok(PendingEffect(tag:, timer:)) -> {
          process.cancel_timer(timer)
          let ev = event.Effect(event.EffectEvent(tag:, result:))
          let new_state = handle_event(state, ev)
          LoopState(
            ..new_state,
            effects: EffectTracker(
              ..new_state.effects,
              pending: dict.delete(new_state.effects.pending, wire_id),
            ),
          )
          |> actor.continue()
        }
        Error(_) -> actor.continue(state)
      }
    }

    FromBridge(InboundEvent(EffectStubAck(kind:))) -> {
      case dict.get(state.effects.stub_acks, kind) {
        Ok(reply) -> {
          process.send(reply, Ok(Nil))
          LoopState(
            ..state,
            effects: EffectTracker(
              ..state.effects,
              stub_acks: dict.delete(state.effects.stub_acks, kind),
            ),
          )
          |> actor.continue()
        }
        Error(_) -> actor.continue(state)
      }
    }

    FromBridge(RendererExited(exit:)) -> {
      let #(model, recovery_error) = case app.get_on_renderer_exit(state.app) {
        Some(handler) ->
          case platform.try_call(fn() { handler(state.model, exit) }) {
            Ok(new_model) -> #(new_model, option.None)
            Error(reason) -> {
              platform.log_error(
                "plushie: on_renderer_exit callback crashed: "
                <> string.inspect(reason),
              )
              #(state.model, option.Some(reason))
            }
          }
        None -> #(state.model, option.None)
      }
      let state = LoopState(..state, model: model)

      let state = case recovery_error {
        option.Some(err) -> {
          let recovery_event =
            event.System(event.RecoveryFailed(
              kind: "error",
              error: string.inspect(err),
              renderer_exit: exit,
            ))
          case
            platform.try_call(fn() {
              runtime_core.map_event(state.app, recovery_event)
            })
          {
            Ok(mapped_msg) -> dispatch_update(state, mapped_msg)
            Error(_) -> state
          }
        }
        option.None -> state
      }

      case exit.reason {
        renderer_exit.Shutdown -> {
          let state = fail_pending_interact(state, "renderer_exit_normal")
          process.send(state.bridge, bridge.Shutdown)
          actor.stop()
        }
        _ -> {
          let reason = "renderer_exit_" <> string.inspect(exit.reason)
          let state = fail_pending_interact(state, reason)
          actor.continue(state)
        }
      }
    }

    InternalEvent(event) -> {
      // Externally injected event (plushie.dispatch_event). Dispatch
      // through the normal widget handler chain and update cycle.
      let new_state = handle_event(state, event)
      // D-033: stop runtime on AllWindowsClosed in non-daemon mode
      case event, state.opts.daemon {
        event.System(event.AllWindowsClosed), False -> actor.stop()
        _, _ -> actor.continue(new_state)
      }
    }

    InternalMsg(dyn_msg, nonce) -> {
      // Done/SendAfter deliver msg values wrapped as Dynamic.
      // Nonce -1 means "always deliver" (from Done, not a timer).
      // Otherwise, check nonce against the pending timer entry to
      // detect stale deliveries from cancelled timers.
      let timer_key = platform.stable_hash_key(dyn_msg)
      let is_current = case nonce {
        -1 -> True
        _ ->
          case dict.get(state.timers, timer_key) {
            Ok(PendingTimer(nonce: expected_nonce, ..)) ->
              expected_nonce == nonce
            Error(_) -> True
          }
      }
      case is_current {
        True -> {
          let state =
            LoopState(..state, timers: dict.delete(state.timers, timer_key))
          let msg = unsafe_coerce_dynamic(dyn_msg)
          let new_state = handle_msg(state, msg)
          actor.continue(new_state)
        }
        // Stale delivery from a cancelled timer; discard silently
        False -> actor.continue(state)
      }
    }

    TimerFired(tag:) -> {
      // Drain any queued ticks for the same tag to coalesce rapid-fire
      // timer events (only the latest tick matters).
      drain_matching_ticks(state.self, tag)
      let timestamp = erlang_monotonic_time()
      // Check if this timer belongs to a widget
      let new_state = case widget.is_widget_tag(tag) {
        True -> {
          let #(maybe_event, new_registry) =
            widget.handle_widget_timer(state.cw_registry, tag, timestamp)
          let state = LoopState(..state, cw_registry: new_registry)
          case maybe_event {
            Some(ev) -> handle_event(state, ev)
            None -> rerender(state)
          }
        }
        False ->
          handle_event(state, event.Timer(event.TimerEvent(tag:, timestamp:)))
      }
      reschedule_timer(new_state, tag) |> actor.continue()
    }

    AsyncComplete(tag:, nonce:, result:) -> {
      // Validate nonce matches current task; discard stale results
      case dict.get(state.async.tasks, tag) {
        Ok(AsyncTask(nonce: current_nonce, monitor:, ..))
          if current_nonce == nonce
        -> {
          process.demonitor_process(monitor)
          // Remove the old entry BEFORE dispatching. If update starts a
          // new task with the same tag, the new entry must not be wiped.
          let state =
            LoopState(
              ..state,
              async: AsyncTracker(
                ..state.async,
                tasks: dict.delete(state.async.tasks, tag),
              ),
            )
          let state =
            handle_event(state, event.Async(event.AsyncEvent(tag:, result:)))
          notify_await_async(state, tag)
          |> actor.continue()
        }
        _ -> actor.continue(state)
      }
    }

    StreamEmit(tag:, nonce:, value:) -> {
      // Validate nonce matches current stream; discard stale emissions
      case dict.get(state.async.tasks, tag) {
        Ok(AsyncTask(nonce: current_nonce, ..)) if current_nonce == nonce -> {
          handle_event(state, event.Stream(event.StreamEvent(tag:, value:)))
          |> actor.continue()
        }
        _ -> actor.continue(state)
      }
    }

    EffectTimeout(request_id:) -> {
      case dict.get(state.effects.pending, request_id) {
        Ok(PendingEffect(tag:, ..)) -> {
          let timeout_event =
            event.Effect(event.EffectEvent(
              tag:,
              result: event.EffectError(dynamic.string("timeout")),
            ))
          let new_state = handle_event(state, timeout_event)
          LoopState(
            ..new_state,
            effects: EffectTracker(
              ..new_state.effects,
              pending: dict.delete(new_state.effects.pending, request_id),
            ),
          )
          |> actor.continue()
        }
        Error(_) -> actor.continue(state)
      }
    }

    InteractTimeout(request_id:) -> {
      case state.interact {
        Some(PendingInteract(reply:, request_id: req_id, monitor:, ..))
          if req_id == request_id
        -> {
          process.demonitor_process(monitor)
          platform.log_error(
            "plushie: interact '" <> req_id <> "' timed out after 10s",
          )
          process.send(reply, Error("timeout"))
          LoopState(..state, interact: None) |> actor.continue()
        }
        _ -> actor.continue(state)
      }
    }

    CoalesceFlush -> {
      flush_coalesced(state) |> actor.continue()
    }

    ProcessDown(process.ProcessDown(
      monitor: down_mon,
      pid: down_pid,
      reason: reason,
    )) -> {
      // Check if this is the bridge actor dying (D-039)
      let is_bridge = case state.bridge_pid {
        Some(bpid) -> bpid == down_pid
        None -> False
      }
      case is_bridge {
        True -> {
          platform.log_error(
            "plushie: bridge process died unexpectedly: "
            <> string.inspect(reason)
            <> "; stopping runtime",
          )
          actor.stop()
        }
        False -> {
          // Check if this is the interact caller dying (timeout/crash).
          // Clear pending_interact so future interactions aren't blocked.
          let state = case state.interact {
            Some(PendingInteract(monitor: mon, timer:, ..)) if mon == down_mon -> {
              process.cancel_timer(timer)
              platform.log_info(
                "plushie: interact caller exited, clearing pending interaction",
              )
              LoopState(..state, interact: None)
            }
            _ -> state
          }

          // Find which async task this pid belongs to
          let found =
            dict.fold(state.async.tasks, None, fn(acc, tag, entry) {
              case acc {
                Some(_) -> acc
                None -> {
                  case entry.pid == down_pid {
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
                  async: AsyncTracker(
                    ..state.async,
                    tasks: dict.delete(state.async.tasks, tag),
                  ),
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
                    event.Async(event.AsyncEvent(
                      tag:,
                      result: Error(crash_reason),
                    )),
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

    FromBridge(RendererRestarted) -> {
      // Bridge reopened the port. Resync state then tell the bridge
      // to flush queued transient messages.

      // Cancel coalesce timer and discard stale coalescable events
      let state = case state.coalesce.timer {
        Some(timer) -> {
          process.cancel_timer(timer)
          LoopState(
            ..state,
            coalesce: CoalesceState(events: dict.new(), order: [], timer: None),
          )
        }
        None ->
          LoopState(
            ..state,
            coalesce: CoalesceState(events: dict.new(), order: [], timer: None),
          )
      }

      // Cancel all pending send_after timers
      dict.each(state.timers, fn(_key, entry) {
        process.cancel_timer(entry.timer)
        Nil
      })
      let state = LoopState(..state, timers: dict.new(), sub_keys_cache: [])

      // Reset error counters and stale focus/status state
      let state =
        LoopState(
          ..state,
          focus: FocusState(
            widget_statuses: dict.new(),
            focused_widget_id: None,
          ),
          error_state: ErrorState(
            errors: 0,
            consecutive_view_errors: 0,
            prop_warnings: state.error_state.prop_warnings,
          ),
        )

      // Flush pending effects with error (old renderer is gone).
      let state = flush_pending_effects_on_restart(state)

      // Flush pending stub acks with error (old renderer's stubs are lost).
      dict.each(state.effects.stub_acks, fn(_kind, reply) {
        process.send(reply, Error("renderer_restarted"))
      })
      let state =
        LoopState(
          ..state,
          effects: EffectTracker(..state.effects, stub_acks: dict.new()),
        )

      // Fail pending interact (old renderer is gone).
      let state = fail_pending_interact(state, "renderer_restarted")

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

      // Re-send settings (protected: a crash here should not block restart)
      let settings = case
        platform.try_call(fn() { app.get_settings(state.app)() })
      {
        Ok(s) -> s
        Error(reason) -> {
          platform.log_error(
            "plushie: settings() callback crashed on restart: "
            <> string.inspect(reason),
          )
          app.default_settings()
        }
      }
      send_encoded(
        state.bridge,
        encode.encode_settings(
          settings,
          state.opts.session,
          state.opts.format,
          state.opts.token,
        ),
      )

      // Re-render view and send fresh snapshot, then sync subs/windows.
      // On view failure, fall back to the existing tree so the renderer
      // still receives a snapshot and subscriptions are re-registered.
      let view_fn = app.get_view(state.app)
      let restart_result = case
        platform.try_call(fn() { view_fn(state.model) })
      {
        Ok(t) ->
          case try_normalize_view(t, state.cw_registry, state.memo_cache) {
            Ok(result) -> Ok(result)
            Error(msg) -> {
              platform.log_error(
                "plushie: normalization failed on restart: " <> msg,
              )
              Error(Nil)
            }
          }
        Error(_) -> Error(Nil)
      }
      let state = case restart_result, state.tree {
        Ok(result), _ -> {
          send_encoded(
            state.bridge,
            encode.encode_snapshot(
              result.tree,
              state.opts.session,
              state.opts.format,
            ),
          )
          sync_after_render(
            state,
            result,
            state.model,
            dict.new(),
            set.new(),
            None,
            False,
          )
        }
        Error(_), Some(old_tree) -> {
          // View failed but we have a previous tree. Send it as a
          // snapshot and re-sync subs/windows so the fresh renderer
          // has consistent state.
          send_encoded(
            state.bridge,
            encode.encode_snapshot(
              old_tree,
              state.opts.session,
              state.opts.format,
            ),
          )
          let fallback =
            tree.NormalizeResult(
              tree: old_tree,
              memo_cache: state.memo_cache,
              registry: state.cw_registry,
              windows: state.windows,
            )
          sync_after_render(
            state,
            fallback,
            state.model,
            dict.new(),
            set.new(),
            None,
            False,
          )
        }
        Error(_), None -> state
      }

      // Tell the bridge resync is done. It will flush queued
      // transient messages.
      process.send(state.bridge, bridge.ResyncComplete)
      actor.continue(state)
    }

    ForceRerender -> {
      platform.log_info("plushie runtime: force re-render (code reload)")
      // Re-render view and diff/patch
      let view_fn = app.get_view(state.app)
      case platform.try_call(fn() { view_fn(state.model) }) {
        Ok(new_tree_raw) -> {
          case
            try_normalize_view(
              new_tree_raw,
              state.cw_registry,
              state.memo_cache,
            )
          {
            Ok(result) -> {
              // Clear the dev overlay on successful re-render (rebuild succeeded)
              let state = LoopState(..state, dev_overlay: None)
              sync_after_render(
                state,
                result,
                state.model,
                state.active_subs,
                state.windows,
                state.tree,
                True,
              )
              |> actor.continue()
            }
            Error(msg) -> {
              platform.log_error(
                "plushie: normalization failed on force re-render: " <> msg,
              )
              actor.continue(state)
            }
          }
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
      dict.each(state.effects.pending, fn(_id, entry) {
        process.cancel_timer(entry.timer)
        Nil
      })
      // Cancel all pending send_after timers
      dict.each(state.timers, fn(_key, entry) {
        process.cancel_timer(entry.timer)
        Nil
      })
      // Cancel coalesce timer if running
      case state.coalesce.timer {
        Some(timer) -> {
          process.cancel_timer(timer)
          Nil
        }
        None -> Nil
      }
      // Flush pending stub acks with error
      dict.each(state.effects.stub_acks, fn(_kind, reply) {
        process.send(reply, Error("runtime_shutdown"))
      })
      // Fail pending interact
      let _state = fail_pending_interact(state, "runtime_shutdown")
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

    GetFocused(reply:) -> {
      process.send(reply, state.focus.focused_widget_id)
      actor.continue(state)
    }

    IsViewDesynced(reply:) -> {
      process.send(reply, state.error_state.consecutive_view_errors > 0)
      actor.continue(state)
    }

    GetPropWarnings(reply:) -> {
      process.send(reply, state.error_state.prop_warnings)
      LoopState(
        ..state,
        error_state: ErrorState(..state.error_state, prop_warnings: []),
      )
      |> actor.continue()
    }

    AwaitAsync(tag:, reply:) -> {
      case dict.has_key(state.async.await_callers, tag) {
        True -> {
          // Another caller is already waiting on this tag.
          // Reply immediately so the caller doesn't hang.
          platform.log_warning(
            "plushie: await_async rejected: another caller is already "
            <> "waiting for tag \""
            <> tag
            <> "\"",
          )
          process.send(reply, Nil)
          actor.continue(state)
        }
        False ->
          case dict.has_key(state.async.tasks, tag) {
            True -> {
              // Task still running; store caller and reply when done
              let callers = dict.insert(state.async.await_callers, tag, reply)
              LoopState(
                ..state,
                async: AsyncTracker(..state.async, await_callers: callers),
              )
              |> actor.continue()
            }
            False -> {
              // Task already completed (or never existed)
              process.send(reply, Nil)
              actor.continue(state)
            }
          }
      }
    }

    Interact(action:, selector:, payload:, reply:) -> {
      // Fail any existing pending interact (prevents caller leak)
      let state = fail_pending_interact(state, "superseded")
      let req_id = "interact_" <> int.to_string(state.async.nonce_counter)
      // Monitor the caller so we can clean up if it dies (timeout/crash).
      // If the caller is already dead, reply with error and skip.
      case process.subject_owner(reply) {
        Error(_) -> {
          process.send(reply, Error("caller_exited"))
          actor.continue(state)
        }
        Ok(caller_pid) -> {
          let caller_monitor = process.monitor(caller_pid)
          // Timeout after 10 seconds (interact should be near-instant)
          let timer =
            process.send_after(state.self, 10_000, InteractTimeout(req_id))
          let state =
            LoopState(
              ..state,
              async: AsyncTracker(
                ..state.async,
                nonce_counter: state.async.nonce_counter + 1,
              ),
              interact: Some(PendingInteract(
                reply:,
                request_id: req_id,
                monitor: caller_monitor,
                timer:,
              )),
            )
          send_transient(
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
      }
    }

    RegisterEffectStub(kind:, response:, reply:) -> {
      case dict.has_key(state.effects.stub_acks, kind) {
        True -> {
          // Another register/unregister for this kind is already pending.
          // Reply immediately so the caller doesn't hang.
          platform.log_warning(
            "plushie: register_effect_stub rejected: "
            <> kind
            <> " already has a pending ack",
          )
          process.send(reply, Error("stub_ack_pending"))
          actor.continue(state)
        }
        False -> {
          send_transient(
            state.bridge,
            encode.encode_register_effect_stub(
              kind,
              response,
              state.opts.session,
              state.opts.format,
            ),
          )
          let new_acks = dict.insert(state.effects.stub_acks, kind, reply)
          LoopState(
            ..state,
            effects: EffectTracker(..state.effects, stub_acks: new_acks),
          )
          |> actor.continue()
        }
      }
    }

    UnregisterEffectStub(kind:, reply:) -> {
      case dict.has_key(state.effects.stub_acks, kind) {
        True -> {
          platform.log_warning(
            "plushie: unregister_effect_stub rejected: "
            <> kind
            <> " already has a pending ack",
          )
          process.send(reply, Error("stub_ack_pending"))
          actor.continue(state)
        }
        False -> {
          send_transient(
            state.bridge,
            encode.encode_unregister_effect_stub(
              kind,
              state.opts.session,
              state.opts.format,
            ),
          )
          let new_acks = dict.insert(state.effects.stub_acks, kind, reply)
          LoopState(
            ..state,
            effects: EffectTracker(..state.effects, stub_acks: new_acks),
          )
          |> actor.continue()
        }
      }
    }

    GetHealth(reply:) -> {
      let health =
        HealthStatus(
          errors: state.error_state.errors,
          consecutive_view_errors: state.error_state.consecutive_view_errors,
          prop_warning_count: list.length(state.error_state.prop_warnings),
          view_desynced: state.error_state.consecutive_view_errors > 0,
        )
      process.send(reply, health)
      actor.continue(state)
    }

    SetDevOverlay(message:) -> {
      let state = LoopState(..state, dev_overlay: message)
      // Re-render to inject or clear the overlay in the tree
      rerender(state) |> actor.continue()
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

@external(erlang, "plushie_ffi", "identity")
fn coerce_to_string(value: Dynamic) -> String

// -- Event coalescing --------------------------------------------------------

@target(erlang)
/// Track widget focus state from renderer status events.
/// Updates widget_statuses and focused_widget_id.
fn track_focus_from_status(
  state: LoopState(model, msg),
  target: event.EventTarget,
  status_value: Dynamic,
) -> LoopState(model, msg) {
  let id = target.id
  // Status events carry a string value. If the coercion fails (non-string
  // value), treat as empty status to avoid crashing.
  let status = case dynamic.classify(status_value) {
    "String" -> coerce_to_string(status_value)
    _ -> ""
  }
  let prev_status = case dict.get(state.focus.widget_statuses, id) {
    Ok(s) -> s
    Error(_) -> ""
  }
  let widget_statuses = dict.insert(state.focus.widget_statuses, id, status)

  let focused_widget_id = case status {
    "focused" -> Some(id)
    _ ->
      case
        prev_status == "focused" && state.focus.focused_widget_id == Some(id)
      {
        True -> None
        False -> state.focus.focused_widget_id
      }
  }

  LoopState(..state, focus: FocusState(widget_statuses:, focused_widget_id:))
}

/// Message used for the frozen-UI dev overlay. Compared by value
/// in sync_after_render to auto-clear on successful view render.
const frozen_ui_message = "UI frozen: view() is failing"

/// Inject a frozen UI error indicator into the stale tree.
/// Sets the dev overlay and sends a snapshot with the overlay node
/// prepended to the tree. Called after consecutive view failures
/// reach the threshold to make the frozen state visible.
fn inject_frozen_indicator(
  state: LoopState(model, msg),
) -> LoopState(model, msg) {
  let message = frozen_ui_message
  let state = LoopState(..state, dev_overlay: Some(message))
  case state.tree {
    Some(tree) -> {
      let patched = inject_dev_overlay_node(tree, message)
      send_encoded(
        state.bridge,
        encode.encode_snapshot(patched, state.opts.session, state.opts.format),
      )
      state
    }
    None -> state
  }
}

/// Build a dev overlay node with the given message text.
fn build_dev_overlay_node(message: String) -> Node {
  let overlay_node = node.new("__plushie_dev_overlay__", "text")
  node.Node(
    ..overlay_node,
    props: dict.from_list([
      #("content", StringVal("[plushie] " <> message)),
      #("size", node.FloatVal(14.0)),
    ]),
  )
}

/// Inject a dev overlay node at the root of the tree.
fn inject_dev_overlay_node(tree: Node, message: String) -> Node {
  let overlay_node = build_dev_overlay_node(message)
  node.Node(..tree, children: [overlay_node, ..tree.children])
}

/// If a dev overlay is active, inject it into the tree before diffing.
fn maybe_inject_dev_overlay(tree: Node, dev_overlay: Option(String)) -> Node {
  case dev_overlay {
    Some(message) -> inject_dev_overlay_node(tree, message)
    None -> tree
  }
}

/// Flush all pending coalescable events, processing each through handle_event.
/// Cancels the coalesce timer and clears the pending map.
fn flush_coalesced(state: LoopState(model, msg)) -> LoopState(model, msg) {
  let state = case state.coalesce.timer {
    Some(timer) -> {
      process.cancel_timer(timer)
      LoopState(..state, coalesce: CoalesceState(..state.coalesce, timer: None))
    }
    None -> state
  }
  let events = state.coalesce.events
  let state =
    list.fold(list.reverse(state.coalesce.order), state, fn(st, key) {
      case dict.get(events, key) {
        Ok(ev) -> handle_event(st, ev)
        Error(_) -> st
      }
    })
  LoopState(
    ..state,
    coalesce: CoalesceState(events: dict.new(), order: [], timer: None),
  )
}

// -- Bridge restart helpers --------------------------------------------------

@target(erlang)
/// Fail the pending interact request with the given reason. Cancels its
/// timeout timer and demonitors the caller.
fn fail_pending_interact(
  state: LoopState(model, msg),
  reason: String,
) -> LoopState(model, msg) {
  case state.interact {
    Some(PendingInteract(reply:, monitor:, timer:, ..)) -> {
      process.demonitor_process(monitor)
      process.cancel_timer(timer)
      process.send(reply, Error(reason))
      LoopState(..state, interact: None)
    }
    None -> state
  }
}

fn flush_pending_effects_on_restart(
  state: LoopState(model, msg),
) -> LoopState(model, msg) {
  // Snapshot the current pending effects, then remove and dispatch each
  // individually. This ensures effects started by handle_event during
  // the flush are not wiped by an unconditional dict.new().
  let snapshot = dict.to_list(state.effects.pending)
  list.fold(snapshot, state, fn(st, entry) {
    let #(wire_id, PendingEffect(tag:, timer:)) = entry
    process.cancel_timer(timer)
    let st =
      LoopState(
        ..st,
        effects: EffectTracker(
          ..st.effects,
          pending: dict.delete(st.effects.pending, wire_id),
        ),
      )
    let timeout_event =
      event.Effect(event.EffectEvent(
        tag:,
        result: event.EffectError(dynamic.string("renderer_restarted")),
      ))
    handle_event(st, timeout_event)
  })
}

@target(erlang)
/// Cancel a pending effect by its app-facing tag. If an effect with the
/// given tag is already in flight, cancel its timeout timer and remove it
/// from the effects tracker. This enforces one-effect-per-tag.
fn cancel_pending_effect_by_tag(
  state: LoopState(model, msg),
  tag: String,
) -> LoopState(model, msg) {
  let found =
    dict.fold(state.effects.pending, None, fn(acc, wire_id, entry) {
      case entry.tag == tag {
        True -> Some(wire_id)
        False -> acc
      }
    })
  case found {
    Some(wire_id) -> {
      let assert Ok(PendingEffect(timer:, ..)) =
        dict.get(state.effects.pending, wire_id)
      process.cancel_timer(timer)
      LoopState(
        ..state,
        effects: EffectTracker(
          ..state.effects,
          pending: dict.delete(state.effects.pending, wire_id),
        ),
      )
    }
    None -> state
  }
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
/// Perform post-render synchronization: derive widget registry, optionally
/// send tree diff/patch to the bridge, sync subscriptions, and sync windows.
///
/// Call sites pass `current_subs` and `old_windows` explicitly because the
/// restart handler uses `dict.new()` / `set.new()` (fresh renderer state)
/// while normal renders diff against the live state.
///
/// When `send_tree` is False, the caller has already sent the tree update
/// (e.g. the restart handler sends a full snapshot before calling this).
fn sync_after_render(
  state: LoopState(model, msg),
  result: tree.NormalizeResult,
  model: model,
  current_subs: Dict(String, SubEntry),
  old_windows: Set(String),
  old_tree: Option(Node),
  send_tree: Bool,
) -> LoopState(model, msg) {
  let new_tree = result.tree
  let new_cw_registry = result.registry
  let new_windows = result.windows

  // Inject dev overlay into the tree sent to the renderer (if active)
  let wire_tree = maybe_inject_dev_overlay(new_tree, state.dev_overlay)

  // Send tree diff/patch (or snapshot) to the bridge
  case send_tree {
    True ->
      case old_tree {
        Some(old) -> {
          let ops =
            telemetry.span(["plushie", "diff"], dict.new(), fn() {
              tree.diff(old, wire_tree)
            })
          telemetry.execute(
            ["plushie", "diff", "complete"],
            dict.from_list([
              #("op_count", to_dynamic(list.length(ops))),
            ]),
            dict.new(),
          )
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
              wire_tree,
              state.opts.session,
              state.opts.format,
            ),
          )
      }
    False -> Nil
  }

  // Sync subscriptions (app + widget)
  let app_subs = safe_subscribe(state.app, model)
  let cw_subs = widget.collect_subscriptions(new_cw_registry)
  let #(new_subs, new_sub_keys_cache) =
    sync_subscriptions(
      list.append(app_subs, cw_subs),
      current_subs,
      state.sub_keys_cache,
      state.bridge,
      state.self,
      state.opts,
    )

  // Sync windows
  sync_windows(
    new_tree,
    old_windows,
    new_windows,
    old_tree,
    state.bridge,
    state.app,
    model,
    state.opts,
  )

  // Clear frozen-UI overlay on successful view render (view errors reset to 0)
  let dev_overlay = case state.dev_overlay {
    Some(msg) if msg == frozen_ui_message -> None
    other -> other
  }

  LoopState(
    ..state,
    tree: Some(wire_tree),
    active_subs: new_subs,
    sub_keys_cache: new_sub_keys_cache,
    windows: new_windows,
    cw_registry: new_cw_registry,
    memo_cache: result.memo_cache,
    error_state: ErrorState(..state.error_state, consecutive_view_errors: 0),
    dev_overlay:,
  )
}

@target(erlang)
/// Re-render the view without going through update. Used when
/// widget state changes internally (event consumed or
/// timer handled by widget) but the app model hasn't changed.
fn rerender(state: LoopState(model, msg)) -> LoopState(model, msg) {
  let view_fn = app.get_view(state.app)
  let meta = dict.new()
  case
    telemetry.span(["plushie", "view"], meta, fn() {
      platform.try_call(fn() { view_fn(state.model) })
    })
  {
    Ok(new_tree_raw) -> {
      case
        telemetry.span(["plushie", "normalize"], meta, fn() {
          try_normalize_view(new_tree_raw, state.cw_registry, state.memo_cache)
        })
      {
        Error(msg) -> {
          platform.log_error(
            "plushie: normalization failed during rerender: " <> msg,
          )
          LoopState(
            ..state,
            error_state: ErrorState(
              ..state.error_state,
              consecutive_view_errors: state.error_state.consecutive_view_errors
                + 1,
            ),
          )
        }
        Ok(result) ->
          sync_after_render(
            state,
            result,
            state.model,
            state.active_subs,
            state.windows,
            state.tree,
            True,
          )
      }
    }
    Error(reason) -> {
      let view_err_count = state.error_state.consecutive_view_errors + 1
      platform.log_warning(
        "plushie: view error during rerender: " <> dynamic.classify(reason),
      )
      let state = case view_err_count == 5 {
        True -> {
          platform.log_warning(
            "plushie: view has failed "
            <> int.to_string(view_err_count)
            <> " consecutive times, the UI is frozen",
          )
          inject_frozen_indicator(state)
        }
        False -> state
      }
      LoopState(
        ..state,
        error_state: ErrorState(
          ..state.error_state,
          consecutive_view_errors: view_err_count,
        ),
      )
    }
  }
}

@target(erlang)
/// Re-render with rollback: if the view function fails, revert the
/// widget registry to the pre-dispatch state. This prevents a desync
/// where the registry reflects a widget state update that the tree
/// never rendered.
fn rerender_with_rollback(
  state: LoopState(model, msg),
  registry_before: widget.Registry,
) -> LoopState(model, msg) {
  let new_state = rerender(state)
  case
    new_state.error_state.consecutive_view_errors
    > state.error_state.consecutive_view_errors
  {
    // View failed: revert widget registry to prevent state-tree desync
    True -> LoopState(..new_state, cw_registry: registry_before)
    False -> new_state
  }
}

@target(erlang)
/// Process an event through update + commands WITHOUT rendering.
/// Used by interact_step to batch events before a single render.
fn apply_event(state: LoopState(model, msg), ev: Event) -> LoopState(model, msg) {
  let #(result, new_registry) =
    widget.dispatch_through_widgets(state.cw_registry, ev)
  let state = LoopState(..state, cw_registry: new_registry)
  case runtime_core.resolve_dispatch(result) {
    Some(resolved) -> {
      case
        platform.try_call(fn() { runtime_core.map_event(state.app, resolved) })
      {
        Error(reason) -> {
          platform.log_warning(
            "plushie: on_event mapper crashed: " <> dynamic.classify(reason),
          )
          state
        }
        Ok(mapped_msg) -> {
          let update_fn = app.get_update(state.app)
          case platform.try_call(fn() { update_fn(state.model, mapped_msg) }) {
            Ok(#(new_model, commands)) -> {
              let state = LoopState(..state, model: new_model)
              execute_commands(commands, state)
            }
            Error(reason) -> {
              platform.log_warning(
                "plushie: update error during interact step: "
                <> dynamic.classify(reason),
              )
              state
            }
          }
        }
      }
    }
    None -> state
  }
}

@target(erlang)
/// Handle a wire event by routing through widget handlers
/// first, then mapping to the app's msg type.
fn handle_event(
  state: LoopState(model, msg),
  ev: Event,
) -> LoopState(model, msg) {
  let registry_before = state.cw_registry
  let #(result, new_registry) =
    widget.dispatch_through_widgets(state.cw_registry, ev)
  let state = LoopState(..state, cw_registry: new_registry)
  case runtime_core.resolve_dispatch(result) {
    Some(resolved) -> {
      case
        platform.try_call(fn() { runtime_core.map_event(state.app, resolved) })
      {
        Ok(mapped_msg) -> dispatch_update(state, mapped_msg)
        Error(reason) -> {
          platform.log_warning(
            "plushie: on_event mapper crashed: " <> dynamic.classify(reason),
          )
          state
        }
      }
    }
    None -> {
      // Event was consumed by a widget handler. Re-render since widget
      // state may have changed. Pass the pre-dispatch registry so we
      // can revert on view error (prevent state-tree desync).
      rerender_with_rollback(state, registry_before)
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
  let meta = dict.new()

  case
    telemetry.span(["plushie", "update"], meta, fn() {
      platform.try_call(fn() { update_fn(state.model, msg) })
    })
  {
    Ok(#(new_model, commands)) -> {
      // Execute commands (before view, matching Elixir SDK)
      let state_after_cmds =
        execute_commands(commands, LoopState(..state, model: new_model))
      let new_model = state_after_cmds.model

      // Render view
      let view_fn = app.get_view(state.app)
      case
        telemetry.span(["plushie", "view"], meta, fn() {
          platform.try_call(fn() { view_fn(new_model) })
        })
      {
        Ok(new_tree_raw) -> {
          case
            telemetry.span(["plushie", "normalize"], meta, fn() {
              try_normalize_view(
                new_tree_raw,
                state_after_cmds.cw_registry,
                state_after_cmds.memo_cache,
              )
            })
          {
            Error(msg) -> {
              platform.log_error(
                "plushie: normalization failed during update: " <> msg,
              )
              LoopState(
                ..state_after_cmds,
                error_state: ErrorState(
                  ..state_after_cmds.error_state,
                  consecutive_view_errors: state_after_cmds.error_state.consecutive_view_errors
                    + 1,
                ),
              )
            }
            Ok(result) -> {
              let synced =
                sync_after_render(
                  state_after_cmds,
                  result,
                  new_model,
                  state.active_subs,
                  state.windows,
                  state.tree,
                  True,
                )
              LoopState(
                ..synced,
                error_state: ErrorState(..synced.error_state, errors: 0),
              )
            }
          }
        }
        Error(reason) -> {
          // View crashed. Preserve model and command-side state
          // (async, effects) but keep old tree.
          // This matches the Elixir SDK: model and commands persist through
          // view crashes, only the tree stays at its previous value.
          let err_count = state_after_cmds.error_state.errors + 1
          let view_err_count =
            state_after_cmds.error_state.consecutive_view_errors + 1
          case err_count <= 10 {
            True ->
              platform.log_warning(
                "plushie: view error: " <> dynamic.classify(reason),
              )
            False -> Nil
          }
          let state_after_cmds = case view_err_count == 5 {
            True -> {
              platform.log_warning(
                "plushie: view has failed "
                <> int.to_string(view_err_count)
                <> " consecutive times, the UI is stale",
              )
              inject_frozen_indicator(state_after_cmds)
            }
            False -> state_after_cmds
          }
          LoopState(
            ..state_after_cmds,
            tree: state.tree,
            error_state: ErrorState(
              ..state_after_cmds.error_state,
              errors: err_count,
              consecutive_view_errors: view_err_count,
            ),
          )
        }
      }
    }
    Error(reason) -> {
      let err_count = state.error_state.errors + 1
      case err_count <= 10 {
        True ->
          platform.log_warning(
            "plushie: update error: " <> dynamic.classify(reason),
          )
        False -> Nil
      }
      LoopState(
        ..state,
        error_state: ErrorState(..state.error_state, errors: err_count),
      )
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
      let state = case dict.get(state.timers, timer_key) {
        Ok(PendingTimer(timer: old_timer, ..)) -> {
          process.cancel_timer(old_timer)
          state
        }
        Error(_) -> state
      }
      // Assign a nonce to detect stale deliveries from cancelled timers
      let nonce = state.async.nonce_counter + 1
      let state =
        LoopState(
          ..state,
          async: AsyncTracker(..state.async, nonce_counter: nonce),
        )
      // Wrap msg as Dynamic since RuntimeMessage is not parameterized
      let timer =
        process.send_after(
          state.self,
          delay_ms,
          InternalMsg(coerce_to_dynamic(msg), nonce),
        )
      LoopState(
        ..state,
        timers: dict.insert(
          state.timers,
          timer_key,
          PendingTimer(timer:, nonce:),
        ),
      )
    }

    command_encode.DoneImmediate(value, mapper) -> {
      case platform.try_call(fn() { mapper(value) }) {
        Ok(mapped_msg) -> {
          // Nonce -1 signals "always deliver" (Done, not a timer)
          process.send(
            state.self,
            InternalMsg(coerce_to_dynamic(mapped_msg), -1),
          )
        }
        Error(reason) -> {
          platform.log_error(
            "plushie: Command.done mapper crashed: " <> string.inspect(reason),
          )
        }
      }
      state
    }

    command_encode.SpawnAsync(tag, work) -> {
      // Kill existing task for same tag before starting a new one
      let state = cancel_existing_task(state, tag)
      let nonce = state.async.nonce_counter + 1
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
        async: AsyncTracker(
          ..state.async,
          tasks: dict.insert(
            state.async.tasks,
            tag,
            AsyncTask(pid:, nonce:, monitor:),
          ),
          nonce_counter: nonce,
        ),
      )
    }

    command_encode.SpawnStream(tag, work) -> {
      // Kill existing task for same tag before starting a new one
      let state = cancel_existing_task(state, tag)
      let nonce = state.async.nonce_counter + 1
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
        async: AsyncTracker(
          ..state.async,
          tasks: dict.insert(
            state.async.tasks,
            tag,
            AsyncTask(pid:, nonce:, monitor:),
          ),
          nonce_counter: nonce,
        ),
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

    command_encode.SystemOp(op, settings) -> {
      send_system_op(state.bridge, op, settings, state.opts)
      state
    }

    command_encode.SystemQuery(op, tag) -> {
      send_system_query(state.bridge, op, tag, state.opts)
      state
    }

    command_encode.ImageOp(op, payload) -> {
      send_image_op(state.bridge, op, payload, state.opts)
      state
    }

    command_encode.EffectRequest(id, tag, kind, payload) -> {
      // One effect per tag: cancel any existing effect with the same tag
      let state = cancel_pending_effect_by_tag(state, tag)
      send_transient(
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
          effect.default_timeout(kind),
          EffectTimeout(request_id: id),
        )
      LoopState(
        ..state,
        effects: EffectTracker(
          ..state.effects,
          pending: dict.insert(
            state.effects.pending,
            id,
            PendingEffect(tag:, timer: timeout_timer),
          ),
        ),
      )
    }

    command_encode.Command(id, family, value) -> {
      send_transient(
        state.bridge,
        encode.encode_command(
          id,
          family,
          value,
          state.opts.session,
          state.opts.format,
        ),
      )
      state
    }

    command_encode.CommandBatch(commands) -> {
      send_transient(
        state.bridge,
        encode.encode_commands(commands, state.opts.session, state.opts.format),
      )
      state
    }

    command_encode.AdvanceFrame(timestamp) -> {
      send_transient(
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
  case dict.get(state.async.tasks, tag) {
    Ok(AsyncTask(pid:, monitor:, ..)) -> {
      process.demonitor_process(monitor)
      process.kill(pid)
      let state =
        LoopState(
          ..state,
          async: AsyncTracker(
            ..state.async,
            tasks: dict.delete(state.async.tasks, tag),
          ),
        )
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
  case dict.get(state.async.await_callers, tag) {
    Ok(reply) -> {
      process.send(reply, Nil)
      LoopState(
        ..state,
        async: AsyncTracker(
          ..state.async,
          await_callers: dict.delete(state.async.await_callers, tag),
        ),
      )
    }
    Error(_) -> state
  }
}

// -- Wire helpers ------------------------------------------------------------

@target(erlang)
/// Send a rebuildable message to the bridge. Dropped during restart
/// because the runtime rebuilds settings, snapshot, subscriptions,
/// and windows during resync.
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
/// Send a transient message to the bridge. Queued during restart
/// and flushed after resync completes. Used for effects, widget ops,
/// image ops, widget commands, interact, advance_frame, and stub
/// registration.
fn send_transient(
  bridge: Subject(BridgeMessage),
  result: Result(BitArray, protocol.EncodeError),
) -> Nil {
  case result {
    Ok(bytes) -> process.send(bridge, bridge.SendTransient(data: bytes))
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
  send_transient(
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
fn send_system_op(
  bridge: Subject(BridgeMessage),
  op: String,
  settings: List(#(String, PropValue)),
  opts: RuntimeOpts,
) -> Nil {
  send_encoded(
    bridge,
    encode.encode_system_op(
      op,
      dict.from_list(settings),
      opts.session,
      opts.format,
    ),
  )
}

@target(erlang)
fn send_system_query(
  bridge: Subject(BridgeMessage),
  op: String,
  tag: String,
  opts: RuntimeOpts,
) -> Nil {
  send_encoded(
    bridge,
    encode.encode_system_query(
      op,
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
  send_transient(
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
  cached_keys: List(String),
  bridge: Subject(BridgeMessage),
  self: Subject(RuntimeMessage),
  opts: RuntimeOpts,
) -> #(Dict(String, SubEntry), List(String)) {
  let desired_by_key =
    list.fold(desired, dict.new(), fn(acc, sub) {
      let k = runtime_core.subscription_key_string(sub)
      dict.insert(acc, k, sub)
    })

  let new_sorted_keys = dict.keys(desired_by_key) |> list.sort(string.compare)

  // Short-circuit: if the sorted key list matches the cache, the set of
  // subscriptions is unchanged. Still check for max_rate/window_id updates
  // on existing renderer subs, but skip the full add/remove diff.
  case new_sorted_keys == cached_keys {
    True -> {
      let updated = update_max_rates(current, desired_by_key, bridge, opts)
      #(updated, cached_keys)
    }
    False -> {
      let result =
        diff_subscriptions(current, desired_by_key, bridge, self, opts)
      #(result, new_sorted_keys)
    }
  }
}

@target(erlang)
/// When subscription keys haven't changed, check for max_rate or
/// window_id updates on existing renderer subscriptions.
fn update_max_rates(
  current: Dict(String, SubEntry),
  desired_by_key: Dict(String, Subscription),
  bridge: Subject(BridgeMessage),
  opts: RuntimeOpts,
) -> Dict(String, SubEntry) {
  dict.fold(desired_by_key, current, fn(acc, key, sub) {
    case dict.get(acc, key) {
      Ok(RendererSub(kind:, max_rate: old_rate, window_id: old_window_id, ..)) -> {
        let new_rate = subscription.get_max_rate(sub)
        let new_window_id = subscription.get_window_id(sub)
        case old_rate == new_rate && old_window_id == new_window_id {
          True -> acc
          False -> {
            let tag = subscription.wire_tag(sub)
            send_encoded(
              bridge,
              encode.encode_subscribe(
                kind,
                tag,
                new_rate,
                new_window_id,
                opts.session,
                opts.format,
              ),
            )
            dict.insert(
              acc,
              key,
              RendererSub(
                kind:,
                wire_tag: tag,
                max_rate: new_rate,
                window_id: new_window_id,
              ),
            )
          }
        }
      }
      _ -> acc
    }
  })
}

@target(erlang)
/// Full subscription diff: stop removed, start new, update kept.
fn diff_subscriptions(
  current: Dict(String, SubEntry),
  desired_by_key: Dict(String, Subscription),
  bridge: Subject(BridgeMessage),
  self: Subject(RuntimeMessage),
  opts: RuntimeOpts,
) -> Dict(String, SubEntry) {
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
      Ok(RendererSub(kind:, max_rate: old_rate, window_id: old_window_id, ..)) -> {
        let new_rate = subscription.get_max_rate(sub)
        let new_window_id = subscription.get_window_id(sub)
        case old_rate == new_rate && old_window_id == new_window_id {
          True -> acc
          False -> {
            let tag = subscription.wire_tag(sub)
            send_encoded(
              bridge,
              encode.encode_subscribe(
                kind,
                tag,
                new_rate,
                new_window_id,
                opts.session,
                opts.format,
              ),
            )
            dict.insert(
              acc,
              key,
              RendererSub(
                kind:,
                wire_tag: tag,
                max_rate: new_rate,
                window_id: new_window_id,
              ),
            )
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
      let tag = subscription.wire_tag(sub)
      let max_rate = subscription.get_max_rate(sub)
      let window_id = subscription.get_window_id(sub)
      send_encoded(
        bridge,
        encode.encode_subscribe(
          kind,
          tag,
          max_rate,
          window_id,
          opts.session,
          opts.format,
        ),
      )
      RendererSub(kind:, wire_tag: tag, max_rate:, window_id:)
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
    RendererSub(kind:, wire_tag:, ..) -> {
      send_encoded(
        bridge,
        encode.encode_unsubscribe(kind, wire_tag, opts.session, opts.format),
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
    let base_config = case
      platform.try_call(fn() { app.get_window_config(app)(model) })
    {
      Ok(c) -> c
      Error(reason) -> {
        platform.log_error(
          "plushie: window_config() crashed for window '"
          <> window_id
          <> "': "
          <> string.inspect(reason),
        )
        dict.new()
      }
    }
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

fn try_normalize_view(
  view_tree: Node,
  registry: widget.Registry,
  memo_cache: tree.MemoCache,
) -> Result(tree.NormalizeResult, String) {
  tree.normalize_view(view_tree, registry, memo_cache)
}
