//// JavaScript/WASM entry point for plushie applications.
////
//// This is the JS-target equivalent of `plushie.gleam` (which uses
//// OTP supervisors). It provides the user-facing API for starting
//// and controlling a plushie app in the browser via the WASM renderer.
////
//// ## Limitations
////
//// Currently only supports `app.simple()` apps where `msg = Event`.
//// See `runtime_web.gleam` module documentation for details.
////
//// ## Quick start (browser)
////
//// ```gleam
//// import plushie_web
//// import plushie/app
//// import plushie/command
//// import plushie/event.{type Event, WidgetClick}
//// import plushie/ui
//// import plushie/widget/window
//// import gleam/int
////
//// type Model { Model(count: Int) }
////
//// pub fn main() {
////   let counter = app.simple(
////     fn(_) { #(Model(0), command.none()) },
////     fn(model, event) {
////       case event {
////         WidgetClick(id: "inc", ..) ->
////           #(Model(model.count + 1), command.none())
////         _ -> #(model, command.none())
////       }
////     },
////     fn(model) {
////       ui.window("main", [window.Title("Counter")], [
////         ui.text_("count", "Count: " <> int.to_string(model.count)),
////         ui.button_("inc", "+"),
////       ])
////     },
////   )
////   let assert Ok(instance) =
////     plushie_web.start(counter, plushie_web.default_start_opts())
//// }
//// ```

@target(javascript)
import gleam/bit_array
@target(javascript)
import gleam/dynamic
@target(javascript)
import gleam/option.{type Option, None}
@target(javascript)
import plushie/app.{type App}
@target(javascript)
import plushie/bridge_web
@target(javascript)
import plushie/event.{type Event}
@target(javascript)
import plushie/node.{type Node}
@target(javascript)
import plushie/protocol.{Json}
@target(javascript)
import plushie/protocol/encode
@target(javascript)
import plushie/runtime_web.{type WebRuntime}

@target(javascript)
/// Options for starting a plushie web application.
pub type WebStartOpts {
  WebStartOpts(
    /// Session identifier. Default: "" (single-session).
    session: String,
    /// Application options passed to init/1. Default: dynamic.nil().
    app_opts: dynamic.Dynamic,
  )
}

@target(javascript)
/// Default start options for the web target.
pub fn default_start_opts() -> WebStartOpts {
  WebStartOpts(session: "", app_opts: dynamic.nil())
}

@target(javascript)
/// A running plushie application on the JavaScript target.
///
/// Parameterized over the model type for type-safe `get_model`.
/// Created by `start`, controlled with `get_model`, `get_tree`,
/// `dispatch_event`, and `stop`.
pub opaque type WebInstance(model) {
  WebInstance(runtime: WebRuntime(model))
}

@target(javascript)
/// Errors that can occur when starting a web application.
pub type WebStartError {
  /// The WASM renderer failed to initialize.
  WasmInitFailed(reason: String)
}

@target(javascript)
/// Format a start error as a human-readable string.
pub fn start_error_to_string(err: WebStartError) -> String {
  case err {
    WasmInitFailed(reason) -> "WASM init failed: " <> reason
  }
}

@target(javascript)
/// Start a plushie application using the WASM renderer.
///
/// Initializes the WASM bridge, sends settings, starts the runtime,
/// and performs the first render. Returns a `WebInstance` for
/// querying state and dispatching events.
///
/// The WASM module must be loaded and registered via
/// `setPlushieAppConstructor()` (from `plushie_bridge_web_ffi.mjs`)
/// before calling this function.
///
/// Only supports `app.simple()` apps (where msg = Event).
pub fn start(
  app: App(model, Event),
  opts: WebStartOpts,
) -> Result(WebInstance(model), WebStartError) {
  // Serialize settings using the same encoder as the BEAM runtime
  let settings = app.get_settings(app)()
  let assert Ok(settings_bytes) =
    encode.encode_settings(settings, opts.session, Json, None)
  let assert Ok(settings_json) = bit_array.to_string(settings_bytes)

  // Create the WASM bridge with a no-op event callback (the runtime
  // doesn't exist yet). After starting the runtime, we rewire the
  // callback to decode events and dispatch them into the update loop.
  case bridge_web.create(settings_json, fn(_event_json) { Nil }) {
    Error(reason) -> Error(WasmInitFailed(reason))
    Ok(transport) -> {
      let runtime =
        runtime_web.start(app, transport, opts.session, opts.app_opts)

      // Wire renderer events to the runtime. The callback decodes
      // each JSON event string and dispatches it.
      bridge_web.set_on_event(transport, fn(event_json) {
        runtime_web.handle_bridge_event(runtime, event_json)
      })

      Ok(WebInstance(runtime:))
    }
  }
}

@target(javascript)
/// Query the current model from a running web application.
///
/// Returns the model with full type safety -- the type parameter
/// flows from the `App(model, Event)` passed to `start`.
pub fn get_model(instance: WebInstance(model)) -> model {
  runtime_web.get_model(instance.runtime)
}

@target(javascript)
/// Query the current normalized tree from a running web application.
pub fn get_tree(instance: WebInstance(model)) -> Option(Node) {
  runtime_web.get_tree(instance.runtime)
}

@target(javascript)
/// Dispatch an event directly to the runtime's update loop.
///
/// The event is processed through the normal update -> view ->
/// diff -> patch cycle as if it came from the WASM renderer.
pub fn dispatch_event(instance: WebInstance(model), event: Event) -> Nil {
  runtime_web.dispatch_event(instance.runtime, event)
}

@target(javascript)
/// Stop a running web application.
///
/// Clears all timers, cancels async tasks, and closes the WASM
/// transport.
pub fn stop(instance: WebInstance(model)) -> Nil {
  runtime_web.stop(instance.runtime)
}
