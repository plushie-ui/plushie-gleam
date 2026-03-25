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
import gleam/bit_array
@target(javascript)
import gleam/dict.{type Dict}
@target(javascript)
import gleam/dynamic.{type Dynamic}
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
import plushie/canvas_widget
@target(javascript)
import plushie/command.{type Command}
@target(javascript)
import plushie/command_encode
@target(javascript)
import plushie/event.{type Event}
@target(javascript)
import plushie/node.{type Node, type PropValue}
@target(javascript)
import plushie/platform
@target(javascript)
import plushie/protocol.{Json}
@target(javascript)
import plushie/protocol/decode
@target(javascript)
import plushie/protocol/encode
@target(javascript)
import plushie/runtime_core
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
/// Mutable JS-side state container. Private to this module --
/// external code interacts through the opaque `WebRuntime(model)`.
type WebRuntimeHandle

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
  app: App(model, msg),
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

  // Initialize canvas widget registry
  do_set_cw_registry(handle, canvas_widget.empty_registry())

  // Register callbacks so JS timers, async completions, and
  // renderer events can call back into the Gleam update loop.
  // Each callback constructs the appropriate Gleam event type
  // and feeds it through handle_event.
  //
  // Two dispatch paths:
  // - dispatch: goes through handle_event (checks coalescing)
  // - dispatch_direct: goes straight to dispatch_update (for
  //   flushed coalesced events that must not be re-coalesced)
  let dispatch = fn(event) { handle_event(handle, app, event) }
  let dispatch_direct = fn(event) {
    let msg = runtime_core.map_event(app, event)
    dispatch_update(handle, app, msg)
  }
  register_dispatch(handle, dispatch, dispatch_direct)
  register_timer_callback(handle, fn(tag) {
    let timestamp = platform.monotonic_time_ms()
    // Route canvas widget timers to the widget handler
    case canvas_widget.is_widget_tag(tag) {
      True -> {
        let registry = do_get_cw_registry(handle)
        let #(maybe_event, new_registry) =
          canvas_widget.handle_widget_timer(registry, tag, timestamp)
        do_set_cw_registry(handle, new_registry)
        case maybe_event {
          Some(ev) -> dispatch(ev)
          None -> render_and_sync(handle, app, False)
        }
      }
      False -> dispatch(event.TimerTick(tag:, timestamp:))
    }
  })
  register_async_callback(handle, fn(tag, result) {
    dispatch(event.AsyncResult(tag:, result:))
  })
  register_stream_callback(handle, fn(tag, value) {
    dispatch(event.StreamValue(tag:, value:))
  })

  // First render (always snapshot)
  render_and_sync(handle, app, True)

  // Execute init commands
  execute_commands(handle, app, init_commands)

  WebRuntime(handle:)
}

@target(javascript)
/// Handle a JSON event string from the WASM renderer.
///
/// Decodes the JSON as a wire protocol event message and dispatches
/// it through the normal update cycle. Called by the bridge's
/// on_event callback.
pub fn handle_bridge_event(runtime: WebRuntime(model), json: String) -> Nil {
  case bit_array.from_string(json) |> decode.decode_message(Json) {
    Ok(decode.EventMessage(event)) ->
      handle_event(runtime.handle, do_get_app(runtime.handle), event)
    Ok(decode.Hello(..)) -> {
      // Hello handshake -- acknowledged, no dispatch needed
      Nil
    }
    Ok(decode.EffectStubAck(..)) -> {
      // Effect stub ack -- not yet implemented on JS
      Nil
    }
    Ok(_) -> Nil
    Error(_err) -> {
      platform.log_warning("plushie web: failed to decode renderer event")
      Nil
    }
  }
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
/// Stop the runtime, clearing all timers, async tasks, and
/// closing the WASM transport to release the renderer.
pub fn stop(runtime: WebRuntime(model)) -> Nil {
  let transport = do_get_transport(runtime.handle)
  do_stop(runtime.handle)
  bridge_web.close(transport)
}

// -- Core update cycle -------------------------------------------------------

@target(javascript)
/// Run one update cycle: update model, execute commands, re-render.
fn dispatch_update(
  handle: WebRuntimeHandle,
  app: App(model, msg),
  msg: msg,
) -> Nil {
  let update_fn = app.get_update(app)
  let model = do_get_model(handle)

  case platform.try_call(fn() { update_fn(model, msg) }) {
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
  app: App(model, msg),
  force_snapshot: Bool,
) -> Nil {
  let view_fn = app.get_view(app)
  let model = do_get_model(handle)
  let session = do_get_session(handle)

  case platform.try_call(fn() { view_fn(model) }) {
    Ok(raw_tree) -> {
      let registry = do_get_cw_registry(handle)
      let new_tree = tree.normalize_with_registry(raw_tree, registry)
      let new_registry = canvas_widget.derive_registry(new_tree)
      do_set_cw_registry(handle, new_registry)
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

      // Sync subscriptions and windows BEFORE updating the stored
      // tree, so sync_windows can compare old vs new props.
      sync_subscriptions(handle, app)
      sync_windows(handle, app, new_tree, session)
      do_set_tree(handle, Some(new_tree))
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
///
/// Events arrive as `Event` (the wire type) and are mapped to the app's
/// `msg` type via `map_event` before dispatch. For `simple()` apps where
/// `msg = Event`, `map_event` is an identity coercion. For `application()`
/// apps, the `on_event` callback performs the mapping.
fn handle_event(
  handle: WebRuntimeHandle,
  app: App(model, msg),
  event: Event,
) -> Nil {
  case runtime_core.coalesce_key(event) {
    Some(key) -> {
      do_set_coalesce(handle, key, event)
      schedule_coalesce_flush(handle)
    }
    None -> {
      // Non-coalescable: flush pending first, then dispatch
      flush_coalesced(handle)
      // Route through canvas_widget scope chain
      let registry = do_get_cw_registry(handle)
      let #(maybe_event, new_registry) =
        canvas_widget.dispatch_through_widgets(registry, event)
      do_set_cw_registry(handle, new_registry)
      case maybe_event {
        Some(ev) -> {
          let msg = runtime_core.map_event(app, ev)
          dispatch_update(handle, app, msg)
        }
        None -> {
          // Consumed by canvas_widget -- re-render for state changes
          render_and_sync(handle, app, False)
        }
      }
    }
  }
}

// -- Subscription lifecycle --------------------------------------------------

@target(javascript)
fn sync_subscriptions(handle: WebRuntimeHandle, app: App(model, msg)) -> Nil {
  let subscribe_fn = app.get_subscribe(app)
  let model = do_get_model(handle)
  let session = do_get_session(handle)

  let app_subs = case platform.try_call(fn() { subscribe_fn(model) }) {
    Ok(subs) -> subs
    Error(_) -> []
  }
  // Merge canvas widget subscriptions
  let cw_subs = canvas_widget.collect_subscriptions(do_get_cw_registry(handle))
  let desired = list.append(app_subs, cw_subs)

  let desired_map =
    list.map(desired, fn(sub) {
      #(runtime_core.subscription_key_string(sub), sub)
    })
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

  // Update max_rate on surviving renderer subscriptions
  dict.each(desired_map, fn(key, new_sub) {
    case dict.get(active_map, key) {
      Ok(old_sub) ->
        case new_sub, old_sub {
          subscription.Every(..), _ -> Nil
          _, subscription.Every(..) -> Nil
          _, _ ->
            case
              subscription.get_max_rate(new_sub)
              != subscription.get_max_rate(old_sub)
            {
              True -> {
                let kind = subscription.wire_kind(new_sub)
                let stag = subscription.tag(new_sub)
                let max_rate = subscription.get_max_rate(new_sub)
                let assert Ok(bytes) =
                  encode.encode_subscribe(kind, stag, max_rate, session, Json)
                do_send(handle, bytes)
              }
              False -> Nil
            }
        }
      Error(_) -> Nil
    }
  })

  do_set_active_subs(handle, desired_map)
}

@target(javascript)
fn start_subscription(
  handle: WebRuntimeHandle,
  key: String,
  sub: Subscription,
  session: String,
) -> Nil {
  case sub {
    subscription.Every(interval_ms:, tag:) -> {
      let app = do_get_app(handle)
      start_timer_sub(handle, key, interval_ms, tag)
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
  app: App(model, msg),
  new_tree: Node,
  session: String,
) -> Nil {
  let old_windows = do_get_windows(handle)
  let new_windows = runtime_core.detect_windows(new_tree)
  let model = do_get_model(handle)

  // Open new windows (merge base window_config with per-window props)
  let opened = set.difference(new_windows, old_windows)
  set.each(opened, fn(window_id) {
    let base_config = app.get_window_config(app)(model)
    let per_window = runtime_core.extract_window_props(new_tree, window_id)
    let merged = dict.merge(base_config, per_window)
    let assert Ok(bytes) =
      encode.encode_window_op("open", window_id, merged, session, Json)
    do_send(handle, bytes)
  })

  // Close removed windows
  let closed = set.difference(old_windows, new_windows)
  set.each(closed, fn(window_id) {
    let assert Ok(bytes) =
      encode.encode_window_op("close", window_id, dict.new(), session, Json)
    do_send(handle, bytes)
  })

  // Update surviving windows whose tracked props changed
  let old_tree = do_get_tree(handle)
  case old_tree {
    Some(old) -> {
      let surviving = set.intersection(old_windows, new_windows)
      set.each(surviving, fn(window_id) {
        let old_props = runtime_core.extract_window_props(old, window_id)
        let new_props = runtime_core.extract_window_props(new_tree, window_id)
        case old_props == new_props {
          True -> Nil
          False -> {
            let assert Ok(bytes) =
              encode.encode_window_op(
                "update",
                window_id,
                new_props,
                session,
                Json,
              )
            do_send(handle, bytes)
          }
        }
      })
    }
    None -> Nil
  }

  do_set_windows(handle, new_windows)
}

// -- Command execution -------------------------------------------------------

@target(javascript)
fn execute_commands(
  handle: WebRuntimeHandle,
  app: App(model, msg),
  cmd: Command(msg),
) -> Nil {
  let session = do_get_session(handle)
  case command_encode.classify(cmd) {
    command_encode.NoOp -> Nil

    command_encode.RunBatch(commands) ->
      list.each(commands, fn(c) { execute_commands(handle, app, c) })

    command_encode.Exit -> do_stop(handle)

    command_encode.DoneImmediate(value, mapper) -> {
      let msg = mapper(value)
      // Defer to next microtask to match BEAM's mailbox semantics
      defer(fn() { dispatch_update(handle, app, msg) })
    }

    command_encode.ScheduleTimer(delay_ms, msg) -> {
      let key = platform.stable_hash_key(msg)
      // SendAfter msg is already the app's msg type -- dispatch
      // directly to dispatch_update, not through handle_event
      // (which expects Event for coalesce checking).
      set_send_after(handle, key, delay_ms, fn() {
        dispatch_update(handle, app, msg)
      })
    }

    command_encode.SpawnAsync(tag, work) -> start_async(handle, tag, work)
    command_encode.SpawnStream(tag, work) -> start_stream(handle, tag, work)
    command_encode.CancelTask(tag) -> cancel_async(handle, tag)

    command_encode.WidgetOp(op, payload) -> wop(handle, op, payload, session)

    command_encode.WindowOp(op, window_id, settings) ->
      winop(handle, op, window_id, settings, session)

    command_encode.WindowQuery(op, window_id, tag) ->
      winquery(handle, op, window_id, tag, session)

    command_encode.ImageOp(op, payload) -> imgop(handle, op, payload, session)

    command_encode.EffectRequest(id, kind, payload) -> {
      let assert Ok(bytes) =
        encode.encode_effect(id, kind, payload, session, Json)
      do_send(handle, bytes)
    }

    command_encode.ExtensionCmd(node_id, op, payload) -> {
      let assert Ok(bytes) =
        encode.encode_extension_command(node_id, op, payload, session, Json)
      do_send(handle, bytes)
    }

    command_encode.ExtensionBatch(commands) -> {
      list.each(commands, fn(cmd_tuple) {
        let #(nid, o, p) = cmd_tuple
        let assert Ok(bytes) =
          encode.encode_extension_command(nid, o, p, session, Json)
        do_send(handle, bytes)
      })
    }

    command_encode.AdvanceFrame(timestamp) -> {
      let assert Ok(bytes) =
        encode.encode_advance_frame(timestamp, session, Json)
      do_send(handle, bytes)
    }
  }
}

@target(javascript)
/// Send a widget_op wire message.
fn wop(
  handle: WebRuntimeHandle,
  op: String,
  payload: List(#(String, PropValue)),
  session: String,
) -> Nil {
  let assert Ok(bytes) =
    encode.encode_widget_op(op, dict.from_list(payload), session, Json)
  do_send(handle, bytes)
}

@target(javascript)
/// Send a window_op wire message.
fn winop(
  handle: WebRuntimeHandle,
  op: String,
  window_id: String,
  settings: List(#(String, PropValue)),
  session: String,
) -> Nil {
  let assert Ok(bytes) =
    encode.encode_window_op(
      op,
      window_id,
      dict.from_list(settings),
      session,
      Json,
    )
  do_send(handle, bytes)
}

@target(javascript)
/// Send a window query (window_op with a tag).
fn winquery(
  handle: WebRuntimeHandle,
  op: String,
  window_id: String,
  tag: String,
  session: String,
) -> Nil {
  winop(handle, op, window_id, [#("tag", sv(tag))], session)
}

@target(javascript)
/// Send an image_op wire message.
fn imgop(
  handle: WebRuntimeHandle,
  op: String,
  payload: List(#(String, PropValue)),
  session: String,
) -> Nil {
  let assert Ok(bytes) =
    encode.encode_image_op(op, dict.from_list(payload), session, Json)
  do_send(handle, bytes)
}

// -- FFI declarations --------------------------------------------------------
// These are implemented in plushie_runtime_web_ffi.mjs

@target(javascript)
/// Register the dispatch callbacks on the handle.
///
/// `dispatch` goes through handle_event (coalesce checks).
/// `dispatch_direct` goes straight to dispatch_update (used
/// by flushCoalesced to avoid re-coalescing flushed events).
@external(javascript, "../plushie_runtime_web_ffi.mjs", "registerDispatch")
fn register_dispatch(
  handle: WebRuntimeHandle,
  dispatch: fn(Event) -> Nil,
  dispatch_direct: fn(Event) -> Nil,
) -> Nil

@target(javascript)
/// Register the timer tick callback.
/// Called by setInterval handlers with the subscription tag.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "registerTimerCallback")
fn register_timer_callback(
  handle: WebRuntimeHandle,
  callback: fn(String) -> Nil,
) -> Nil

@target(javascript)
/// Register the async completion callback.
/// Called when a Promise resolves or rejects.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "registerAsyncCallback")
fn register_async_callback(
  handle: WebRuntimeHandle,
  callback: fn(String, Result(Dynamic, Dynamic)) -> Nil,
) -> Nil

@target(javascript)
/// Register the stream emission callback.
/// Called for each value emitted by a stream task.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "registerStreamCallback")
fn register_stream_callback(
  handle: WebRuntimeHandle,
  callback: fn(String, Dynamic) -> Nil,
) -> Nil

@target(javascript)
/// Create the mutable runtime state container.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "createHandle")
fn create_handle(
  model: model,
  app: App(model, msg),
  transport: WebTransport,
  session: String,
  empty_subs: Dict(String, Subscription),
  empty_windows: Set(String),
) -> WebRuntimeHandle

// The following accessors have free type variables (model, msg)
// because WebRuntimeHandle is an unparameterized opaque JS object.
// Type safety is maintained by construction: only `start` creates
// handles, and it stores properly typed values. These accessors
// are private to this module and only called in contexts where the
// types are already constrained by the enclosing function signature.

@target(javascript)
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getModel")
fn do_get_model(handle: WebRuntimeHandle) -> model

@target(javascript)
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setModel")
fn do_set_model(handle: WebRuntimeHandle, model: model) -> Nil

@target(javascript)
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getTree")
fn do_get_tree(handle: WebRuntimeHandle) -> Option(Node)

@target(javascript)
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setTree")
fn do_set_tree(handle: WebRuntimeHandle, tree: Option(Node)) -> Nil

@target(javascript)
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getApp")
fn do_get_app(handle: WebRuntimeHandle) -> App(model, msg)

@target(javascript)
/// Get the session ID from the handle.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getSession")
fn do_get_session(handle: WebRuntimeHandle) -> String

@target(javascript)
/// Get the transport from the handle (for closing on stop).
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getTransport")
fn do_get_transport(handle: WebRuntimeHandle) -> WebTransport

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
/// Get the canvas widget registry.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "getCwRegistry")
fn do_get_cw_registry(handle: WebRuntimeHandle) -> canvas_widget.Registry

@target(javascript)
/// Set the canvas widget registry.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setCwRegistry")
fn do_set_cw_registry(
  handle: WebRuntimeHandle,
  registry: canvas_widget.Registry,
) -> Nil

@target(javascript)
/// Send serialized wire bytes to the transport.
///
/// Converts the BitArray (JSON with trailing newline) to a String
/// and sends via the bridge_web abstraction.
fn do_send(handle: WebRuntimeHandle, data: BitArray) -> Nil {
  let transport = do_get_transport(handle)
  case bit_array.to_string(data) {
    Ok(json) -> bridge_web.send(transport, json)
    Error(_) -> {
      platform.log_warning(
        "plushie web: failed to convert wire bytes to string",
      )
      Nil
    }
  }
}

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
fn schedule_coalesce_flush(handle: WebRuntimeHandle) -> Nil

@target(javascript)
/// Flush all pending coalesced events.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "flushCoalesced")
fn flush_coalesced(handle: WebRuntimeHandle) -> Nil

@target(javascript)
/// Defer a function call to the next microtask.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "defer")
fn defer(f: fn() -> Nil) -> Nil

@target(javascript)
/// Start a timer subscription (setInterval).
@external(javascript, "../plushie_runtime_web_ffi.mjs", "startTimerSub")
fn start_timer_sub(
  handle: WebRuntimeHandle,
  key: String,
  interval_ms: Int,
  tag: String,
) -> Nil

@target(javascript)
/// Clear a timer subscription.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "clearTimerSub")
fn clear_timer_sub(handle: WebRuntimeHandle, key: String) -> Nil

@target(javascript)
/// Schedule a SendAfter callback. The callback is a closure that
/// dispatches the msg directly to dispatch_update.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "setSendAfter")
fn set_send_after(
  handle: WebRuntimeHandle,
  key: String,
  delay_ms: Int,
  callback: fn() -> Nil,
) -> Nil

@target(javascript)
/// Start an async task (runs work in a Promise).
@external(javascript, "../plushie_runtime_web_ffi.mjs", "startAsync")
fn start_async(
  handle: WebRuntimeHandle,
  tag: String,
  work: fn() -> Dynamic,
) -> Nil

@target(javascript)
/// Start a stream task.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "startStream")
fn start_stream(
  handle: WebRuntimeHandle,
  tag: String,
  work: fn(fn(Dynamic) -> Nil) -> Dynamic,
) -> Nil

@target(javascript)
/// Cancel an async/stream task.
@external(javascript, "../plushie_runtime_web_ffi.mjs", "cancelAsync")
fn cancel_async(handle: WebRuntimeHandle, tag: String) -> Nil
