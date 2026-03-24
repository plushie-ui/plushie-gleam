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
 * @param {string} settingsJson - Serialized settings message
 * @param {function} onEvent - Callback receiving JSON event strings
 * @returns {Ok|Error} Ok(transport) or Error(reason)
 */
export function create(settingsJson, onEvent) {
  if (!PlushieAppCtor) {
    return new Error(
      "PlushieApp constructor not set. " +
        "Call setPlushieAppConstructor() after loading the WASM module.",
    );
  }
  try {
    const app = new PlushieAppCtor(settingsJson, (eventJson) => {
      onEvent(eventJson);
    });
    return new Ok({ app });
  } catch (e) {
    return new Error(`WASM init failed: ${e}`);
  }
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
