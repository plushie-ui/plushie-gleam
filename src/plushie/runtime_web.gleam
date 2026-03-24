//// JavaScript runtime: callback-driven Elm update loop.
////
//// This is the JS-target equivalent of `runtime.gleam` (which uses
//// OTP actors). It manages the app model, executes the update/view
//// cycle, diffs trees, sends patches to the WASM bridge, and handles
//// command execution and subscription lifecycle.
////
//// State is stored in a mutable JS object via FFI. The update cycle
//// is synchronous (no process boundaries). Event coalescing uses
//// `queueMicrotask` to batch high-frequency events.
////
//// ## Limitations
////
//// Currently only supports `app.simple()` apps where `msg = Event`.
//// Apps created with `app.application()` (custom message types via
//// `on_event`) are not yet supported -- the `msg` type parameter is
//// hardcoded to `Event`. This will be addressed when the JS->Gleam
//// callback bridge is implemented.
////
//// Not all command variants are handled yet. Core commands (None,
//// Batch, Done, SendAfter, Async, Stream, Cancel, Exit) and common
//// widget ops (Focus, ScrollTo, SelectAll) work. Remaining variants
//// log a warning and are skipped.
////
//// ## Architecture
////
//// The JS runtime reuses the same pure functions as the BEAM runtime:
//// - `app.get_update(app)(model, msg)` for the update step
//// - `tree.normalize(raw_tree)` for scoped ID application
//// - `tree.diff(old, new)` for incremental patching
//// - `protocol/encode` (JSON path) for wire serialization
////
//// What differs is the concurrency model: instead of OTP actors and
//// process messages, the JS runtime uses callbacks, Promises, and
//// setTimeout/setInterval for async work.

@target(javascript)
import gleam/dict.{type Dict}
@target(javascript)
import gleam/dynamic.{type Dynamic}
@target(javascript)
import gleam/int
@target(javascript)
import gleam/list
@target(javascript)
import gleam/option.{type Option, None, Some}
@target(javascript)
import gleam/set.{type Set}
@target(javascript)
import plushie/app.{type App}
@target(javascript)
import plushie/bridge_web.{type WebTransport}
@target(javascript)
import plushie/command.{type Command}
@target(javascript)
import plushie/event.{type Event}
@target(javascript)
import plushie/node.{type Node, type PropValue}
@target(javascript)
import plushie/platform
@target(javascript)
import plushie/protocol.{Json}
@target(javascript)
import plushie/protocol/encode
@target(javascript)
import plushie/subscription.{type Subscription}
@target(javascript)
import plushie/tree

// -- Types ------------------------------------------------------------------

@target(javascript)
/// Opaque handle to a running JS runtime.
///
/// Wraps a mutable JS object containing the model, tree, active
/// subscriptions, async task tracking, and coalesce state. Created
/// by `start`, queried with `get_model`/`get_tree`, and torn down
/// with `stop`.
pub opaque type WebRuntime(model) {
  WebRuntime(handle: WebRuntimeHandle)
}

@target(javascript)
/// Opaque JS-side mutable state container.
pub type WebRuntimeHandle

// -- Lifecycle ---------------------------------------------------------------

@target(javascript)
/// Start the JS runtime with a WASM transport.
///
/// Initializes the app model via `init`, renders the first view as
/// a snapshot, syncs subscriptions and windows, and begins
/// processing events from the WASM renderer.
///
/// The `app_opts` value is passed to the app's `init` function.
pub fn start(
  app: App(model, Event),
  transport: WebTransport,
  session: String,
  app_opts: Dynamic,
) -> WebRuntime(model) {
  // Initialize the app
  let init_fn = app.get_init(app)
  let #(model, init_commands) = init_fn(app_opts)

  // Create the mutable runtime state with properly initialized
  // Gleam containers (empty Dict and Set can't be constructed in JS)
  let handle =
    create_handle(model, app, transport, session, dict.new(), set.new())

  // First render (always snapshot)
  render_and_sync(handle, app, True)

  // Execute init commands
  execute_commands(handle, app, init_commands)

  WebRuntime(handle:)
}

@target(javascript)
/// Get the current model from a running runtime.
pub fn get_model(runtime: WebRuntime(model)) -> model {
  do_get_model(runtime.handle)
}

@target(javascript)
/// Get the current normalized tree.
pub fn get_tree(runtime: WebRuntime(model)) -> Option(Node) {
  do_get_tree(runtime.handle)
}

@target(javascript)
/// Inject an event into the update loop.
pub fn dispatch_event(runtime: WebRuntime(model), event: Event) -> Nil {
  handle_event(runtime.handle, do_get_app(runtime.handle), event)
}

@target(javascript)
/// Stop the runtime, clearing all timers and async tasks.
pub fn stop(runtime: WebRuntime(model)) -> Nil {
  do_stop(runtime.handle)
}

// -- Core update cycle -------------------------------------------------------

@target(javascript)
/// Run one update cycle: update model, execute commands, re-render.
fn dispatch_update(
  handle: WebRuntimeHandle,
  app: App(model, Event),
  event: Event,
) -> Nil {
  let update_fn = app.get_update(app)
  let model = do_get_model(handle)

  case platform.try_call(fn() { update_fn(model, event) }) {
    Ok(#(new_model, commands)) -> {
      do_set_model(handle, new_model)
      execute_commands(handle, app, commands)
      render_and_sync(handle, app, False)
    }
    Error(reason) -> {
      platform.log_warning(
        "plushie: update error: " <> dynamic.classify(reason),
      )
      Nil
    }
  }
}

@target(javascript)
/// Render the view, diff against previous tree, send patch or snapshot.
fn render_and_sync(
  handle: WebRuntimeHandle,
  app: App(model, Event),
  force_snapshot: Bool,
) -> Nil {
  let view_fn = app.get_view(app)
  let model = do_get_model(handle)
  let session = do_get_session(handle)

  case platform.try_call(fn() { view_fn(model) }) {
    Ok(raw_tree) -> {
      let new_tree = tree.normalize(raw_tree)
      let old_tree = do_get_tree(handle)

      case force_snapshot || option.is_none(old_tree) {
        True -> {
          let assert Ok(bytes) = encode.encode_snapshot(new_tree, session, Json)
          do_send(handle, bytes)
        }
        False -> {
          let assert Some(old) = old_tree
          let ops = tree.diff(old, new_tree)
          case list.is_empty(ops) {
            True -> Nil
            False -> {
              let assert Ok(bytes) = encode.encode_patch(ops, session, Json)
              do_send(handle, bytes)
            }
          }
        }
      }

      do_set_tree(handle, Some(new_tree))
      sync_subscriptions(handle, app)
      sync_windows(handle, new_tree, session)
    }
    Error(reason) -> {
      platform.log_warning("plushie: view error: " <> dynamic.classify(reason))
      Nil
    }
  }
}

// -- Event handling ----------------------------------------------------------

@target(javascript)
/// Handle an incoming event, with coalescing for high-frequency events.
fn handle_event(
  handle: WebRuntimeHandle,
  app: App(model, Event),
  event: Event,
) -> Nil {
  case coalesce_key(event) {
    Some(key) -> {
      do_set_coalesce(handle, key, event)
      schedule_coalesce_flush(handle, app)
    }
    None -> {
      // Non-coalescable: flush pending first, then dispatch
      flush_coalesced(handle, app)
      dispatch_update(handle, app, event)
    }
  }
}

@target(javascript)
/// Determine the coalesce key for an event, if coalescable.
fn coalesce_key(event: Event) -> Option(String) {
  case event {
    event.MouseMoved(..) -> Some("mouse:moved")
    event.SensorResize(id:, ..) -> Some("sensor:" <> id)
    _ -> None
  }
}

// -- Subscription lifecycle --------------------------------------------------

@target(javascript)
fn sync_subscriptions(handle: WebRuntimeHandle, app: App(model, Event)) -> Nil {
  let subscribe_fn = app.get_subscribe(app)
  let model = do_get_model(handle)
  let session = do_get_session(handle)

  let desired = case platform.try_call(fn() { subscribe_fn(model) }) {
    Ok(subs) -> subs
    Error(_) -> []
  }

  let desired_map =
    list.map(desired, fn(sub) { #(subscription_key_string(sub), sub) })
    |> dict.from_list()

  let active_map = do_get_active_subs(handle)

  // Stop removed subscriptions
  dict.each(active_map, fn(key, sub) {
    case dict.has_key(desired_map, key) {
      True -> Nil
      False -> stop_subscription(handle, key, sub, session)
    }
  })

  // Start new subscriptions
  dict.each(desired_map, fn(key, sub) {
    case dict.has_key(active_map, key) {
      True -> Nil
      False -> start_subscription(handle, key, sub, session)
    }
  })

  do_set_active_subs(handle, desired_map)
}

@target(javascript)
/// Convert a SubscriptionKey to a string for use as a dict key.
fn subscription_key_string(sub: Subscription) -> String {
  let key = subscription.key(sub)
  case key {
    subscription.TimerKey(interval_ms:, tag:) ->
      "timer:" <> int.to_string(interval_ms) <> ":" <> tag
    subscription.RendererKey(kind:, tag:) -> "renderer:" <> kind <> ":" <> tag
  }
}

@target(javascript)
fn start_subscription(
  handle: WebRuntimeHandle,
  key: String,
  sub: Subscription,
  session: String,
) -> Nil {
  case sub {
    subscription.Every(interval_ms:, tag:, ..) -> {
      let app = do_get_app(handle)
      start_timer_sub(handle, app, key, interval_ms, tag)
    }
    _ -> {
      let kind = subscription.wire_kind(sub)
      let stag = subscription.tag(sub)
      let max_rate = subscription.get_max_rate(sub)
      let assert Ok(bytes) =
        encode.encode_subscribe(kind, stag, max_rate, session, Json)
      do_send(handle, bytes)
    }
  }
}

@target(javascript)
fn stop_subscription(
  handle: WebRuntimeHandle,
  key: String,
  sub: Subscription,
  session: String,
) -> Nil {
  case sub {
    subscription.Every(..) -> {
      // Timer: clear the JS interval
      clear_timer_sub(handle, key)
    }
    _ -> {
      // Renderer subscription: send unsubscribe
      let kind = subscription.wire_kind(sub)
      let assert Ok(bytes) = encode.encode_unsubscribe(kind, session, Json)
      do_send(handle, bytes)
    }
  }
}

// -- Window lifecycle --------------------------------------------------------

@target(javascript)
fn sync_windows(
  handle: WebRuntimeHandle,
  new_tree: Node,
  session: String,
) -> Nil {
  let old_windows = do_get_windows(handle)
  let new_windows = detect_windows(new_tree)

  // Open new windows
  set.each(new_windows, fn(id) {
    case set.contains(old_windows, id) {
      True -> Nil
      False -> {
        let assert Ok(bytes) =
          encode.encode_window_op("open", id, dict.new(), session, Json)
        do_send(handle, bytes)
      }
    }
  })

  // Close removed windows
  set.each(old_windows, fn(id) {
    case set.contains(new_windows, id) {
      True -> Nil
      False -> {
        let assert Ok(bytes) =
          encode.encode_window_op("close", id, dict.new(), session, Json)
        do_send(handle, bytes)
      }
    }
  })

  do_set_windows(handle, new_windows)
}

@target(javascript)
/// Detect window nodes at root or direct child level.
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

// -- Command execution -------------------------------------------------------

@target(javascript)
fn execute_commands(
  handle: WebRuntimeHandle,
  app: App(model, Event),
  cmd: Command(Event),
) -> Nil {
  let session = do_get_session(handle)
  case cmd {
    command.None -> Nil

    command.Batch(commands:) ->
      list.each(commands, fn(c) { execute_commands(handle, app, c) })

    command.Exit -> do_stop(handle)

    command.Done(value:, mapper:) -> {
      let msg = mapper(value)
      // Defer to next microtask to match BEAM's mailbox semantics
      defer(fn() { dispatch_update(handle, app, msg) })
    }

    command.SendAfter(delay_ms:, msg:) -> {
      let key = platform.stable_hash_key(dynamic.from(msg))
      set_send_after(handle, app, key, delay_ms, msg)
    }

    command.Async(work:, tag:) -> {
      start_async(handle, app, tag, work)
    }

    command.Stream(work:, tag:) -> {
      start_stream(handle, app, tag, work)
    }

    command.Cancel(tag:) -> {
      cancel_async(handle, tag)
    }

    command.Focus(id:) ->
      send_widget_op(
        handle,
        "focus",
        dict.from_list([#("id", node.StringVal(id))]),
        session,
      )
    command.FocusNext ->
      send_widget_op(handle, "focus_next", dict.new(), session)
    command.FocusPrevious ->
      send_widget_op(handle, "focus_previous", dict.new(), session)
    command.SelectAll(id:) ->
      send_widget_op(
        handle,
        "select_all",
        dict.from_list([#("id", node.StringVal(id))]),
        session,
      )
    command.ScrollTo(id:, x:, y:) ->
      send_widget_op(
        handle,
        "scroll_to",
        dict.from_list([
          #("id", node.StringVal(id)),
          #("x", node.FloatVal(x)),
          #("y", node.FloatVal(y)),
        ]),
        session,
      )

    command.CloseWindow(id:) -> {
      let assert Ok(bytes) =
        encode.encode_window_op("close", id, dict.new(), session, Json)
      do_send(handle, bytes)
    }

    command.Effect(request_id:, kind:, payload:) -> {
      let assert Ok(bytes) =
        encode.encode_effect(request_id, kind, payload, session, Json)
      do_send(handle, bytes)
    }

    command.ExtensionCommand(node_id:, op:, payload:) -> {
      let assert Ok(bytes) =
        encode.encode_extension_command(node_id, op, payload, session, Json)
      do_send(handle, bytes)
    }

    // Other widget/window commands: encode and send
    _ -> {
      // Catch-all for remaining command variants that are just wire ops
      platform.log_warning("plushie web: unhandled command variant, skipping")
      Nil
    }
  }
}

@target(javascript)
fn send_widget_op(
  handle: WebRuntimeHandle,
  op: String,
  payload: Dict(String, PropValue),
  session: String,
) -> Nil {
  let assert Ok(bytes) = encode.encode_widget_op(op, payload, session, Json)
  do_send(handle, bytes)
}

// -- FFI declarations --------------------------------------------------------
// These are implemented in plushie_runtime_web_ffi.mjs

@target(javascript)
/// Create the mutable runtime state container.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "createHandle")
fn create_handle(
  model: model,
  app: App(model, Event),
  transport: WebTransport,
  session: String,
  empty_subs: Dict(String, Subscription),
  empty_windows: Set(String),
) -> WebRuntimeHandle

@target(javascript)
/// Get the current model from the handle.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getModel")
fn do_get_model(handle: WebRuntimeHandle) -> model

@target(javascript)
/// Set the model on the handle.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setModel")
fn do_set_model(handle: WebRuntimeHandle, model: model) -> Nil

@target(javascript)
/// Get the current tree from the handle.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getTree")
fn do_get_tree(handle: WebRuntimeHandle) -> Option(Node)

@target(javascript)
/// Set the tree on the handle.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setTree")
fn do_set_tree(handle: WebRuntimeHandle, tree: Option(Node)) -> Nil

@target(javascript)
/// Get the app reference from the handle.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getApp")
fn do_get_app(handle: WebRuntimeHandle) -> App(model, Event)

@target(javascript)
/// Get the session ID from the handle.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getSession")
fn do_get_session(handle: WebRuntimeHandle) -> String

@target(javascript)
/// Get the active subscriptions dict.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getActiveSubs")
fn do_get_active_subs(handle: WebRuntimeHandle) -> Dict(String, Subscription)

@target(javascript)
/// Set the active subscriptions dict.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setActiveSubs")
fn do_set_active_subs(
  handle: WebRuntimeHandle,
  subs: Dict(String, Subscription),
) -> Nil

@target(javascript)
/// Get the set of active window IDs.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getWindows")
fn do_get_windows(handle: WebRuntimeHandle) -> Set(String)

@target(javascript)
/// Set the active window IDs.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setWindows")
fn do_set_windows(handle: WebRuntimeHandle, windows: Set(String)) -> Nil

@target(javascript)
/// Send serialized wire bytes to the transport.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "sendToTransport")
fn do_send(handle: WebRuntimeHandle, data: BitArray) -> Nil

@target(javascript)
/// Stop the runtime: clear all timers, cancel async tasks, close transport.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "stop")
fn do_stop(handle: WebRuntimeHandle) -> Nil

@target(javascript)
/// Store a coalescable event for deferred processing.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setCoalesce")
fn do_set_coalesce(handle: WebRuntimeHandle, key: String, event: Event) -> Nil

@target(javascript)
/// Schedule a microtask to flush coalesced events.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "scheduleCoalesceFlush")
fn schedule_coalesce_flush(
  handle: WebRuntimeHandle,
  app: App(model, Event),
) -> Nil

@target(javascript)
/// Flush all pending coalesced events.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "flushCoalesced")
fn flush_coalesced(handle: WebRuntimeHandle, app: App(model, Event)) -> Nil

@target(javascript)
/// Defer a function call to the next microtask.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "defer")
fn defer(f: fn() -> Nil) -> Nil

@target(javascript)
/// Start a timer subscription (setInterval).
@external(javascript, "../plushie_runtime_web_ffi.mjs", "startTimerSub")
fn start_timer_sub(
  handle: WebRuntimeHandle,
  app: App(model, Event),
  key: String,
  interval_ms: Int,
  tag: String,
) -> Nil

@target(javascript)
/// Clear a timer subscription.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "clearTimerSub")
fn clear_timer_sub(handle: WebRuntimeHandle, key: String) -> Nil

@target(javascript)
/// Schedule a SendAfter callback.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setSendAfter")
fn set_send_after(
  handle: WebRuntimeHandle,
  app: App(model, Event),
  key: String,
  delay_ms: Int,
  msg: Event,
) -> Nil

@target(javascript)
/// Start an async task (runs work in a Promise).
@external(javascript, "../plushie_runtime_web_ffi.mjs", "startAsync")
fn start_async(
  handle: WebRuntimeHandle,
  app: App(model, Event),
  tag: String,
  work: fn() -> Dynamic,
) -> Nil

@target(javascript)
/// Start a stream task.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "startStream")
fn start_stream(
  handle: WebRuntimeHandle,
  app: App(model, Event),
  tag: String,
  work: fn(fn(Dynamic) -> Nil) -> Nil,
) -> Nil

@target(javascript)
/// Cancel an async/stream task.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "cancelAsync")
fn cancel_async(handle: WebRuntimeHandle, tag: String) -> Nil
