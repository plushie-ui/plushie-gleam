//// WASM transport for the JavaScript target.
////
//// Wraps the plushie-renderer-wasm module's PlushieApp API.
//// Communication is always JSON (the WASM renderer does not
//// support MessagePack framing). Messages are passed as JSON
//// strings via the PlushieApp constructor and send_message method.
////
//// The WASM module must be loaded before creating a transport.
//// In browser contexts, call the wasm-bindgen init() function
//// first. In Node.js, use the appropriate WASM loader.
////
//// ## Usage
////
//// ```gleam
//// import plushie/bridge_web
////
//// let assert Ok(transport) =
////   bridge_web.create(settings_json, on_event_callback)
//// bridge_web.send(transport, message_json)
//// bridge_web.close(transport)
//// ```

/// Opaque handle to a WASM transport instance.
///
/// Wraps the JavaScript PlushieApp object. Created by `create`,
/// which instantiates the WASM renderer and wires up the event
/// callback.
pub type WebTransport

@target(javascript)
/// Create a WASM transport by instantiating the PlushieApp.
///
/// `settings_json` is the serialized settings message (including
/// protocol_version). `on_event` is called with each JSON-encoded
/// event string emitted by the renderer.
///
/// Returns `Ok(WebTransport)` on success, or `Error(reason)` if
/// the WASM module fails to initialize.
@external(javascript, "../plushie_bridge_web_ffi.mjs", "create")
pub fn create(
  settings_json: String,
  on_event: fn(String) -> Nil,
) -> Result(WebTransport, String)

@target(javascript)
/// Send a JSON-encoded protocol message to the WASM renderer.
///
/// The message is parsed by the renderer on the next event loop
/// tick. Accepts any valid protocol message: Snapshot, Patch,
/// Settings, Subscribe, Unsubscribe, WidgetOp, WindowOp, Effect,
/// ExtensionCommand, etc.
@external(javascript, "../plushie_bridge_web_ffi.mjs", "send")
pub fn send(transport: WebTransport, json: String) -> Nil

@target(javascript)
/// Replace the event callback on an existing transport.
///
/// Used to wire the renderer's event stream to the runtime after
/// both the transport and runtime are initialized (breaking the
/// chicken-and-egg dependency).
@external(javascript, "../plushie_bridge_web_ffi.mjs", "setOnEvent")
pub fn set_on_event(transport: WebTransport, on_event: fn(String) -> Nil) -> Nil

@target(javascript)
/// Close the transport and release the WASM renderer.
@external(javascript, "../plushie_bridge_web_ffi.mjs", "close")
pub fn close(transport: WebTransport) -> Nil
