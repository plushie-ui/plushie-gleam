// WASM transport FFI -- JavaScript implementation.
//
// Wraps the PlushieApp wasm-bindgen API. The PlushieApp constructor
// must be available as a global or passed via setPlushieAppConstructor
// before create() is called.

import { Ok, Error } from "./gleam.mjs";

// The PlushieApp constructor from wasm-bindgen output.
// Set this before calling create() -- typically done by the app's
// entry point after loading the WASM module.
let PlushieAppCtor = null;

/**
 * Register the PlushieApp constructor from the WASM module.
 *
 * Call this after loading the WASM binary:
 *   import init, { PlushieApp } from 'plushie-renderer-wasm'
 *   await init()
 *   setPlushieAppConstructor(PlushieApp)
 */
export function setPlushieAppConstructor(ctor) {
  PlushieAppCtor = ctor;
}

/**
 * Create a WebTransport by instantiating PlushieApp.
 *
 * The on_event callback is stored mutably on the transport object
 * so it can be replaced later via setOnEvent (needed because the
 * runtime doesn't exist yet when the transport is created).
 */
export function create(settingsJson, onEvent) {
  if (!PlushieAppCtor) {
    return new Error(
      "PlushieApp constructor not set. " +
        "Call setPlushieAppConstructor() after loading the WASM module.",
    );
  }
  try {
    // The transport holds a mutable event handler. The PlushieApp
    // callback forwards to it, allowing setOnEvent to rewire.
    const transport = { app: null, onEvent };
    const app = new PlushieAppCtor(settingsJson, (eventJson) => {
      transport.onEvent(eventJson);
    });
    transport.app = app;
    return new Ok(transport);
  } catch (e) {
    return new Error(`WASM init failed: ${e}`);
  }
}

/**
 * Replace the event callback on an existing transport.
 */
export function setOnEvent(transport, onEvent) {
  transport.onEvent = onEvent;
}

/**
 * Send a JSON message to the WASM renderer.
 */
export function send(transport, json) {
  if (transport.app) {
    transport.app.send_message(json);
  }
}

/**
 * Close the transport, releasing the WASM renderer.
 */
export function close(transport) {
  transport.app = null;
}
