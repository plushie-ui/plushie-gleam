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
 * Events received before setOnEvent is called are buffered and
 * flushed when setOnEvent wires the real handler. This prevents
 * event loss during the startup window between transport creation
 * and runtime initialization.
 */
export function create(settingsJson, onEvent) {
  if (!PlushieAppCtor) {
    return new Error(
      "PlushieApp constructor not set. " +
        "Call setPlushieAppConstructor() after loading the WASM module.",
    );
  }
  try {
    const transport = {
      app: null,
      onEvent,
      // Buffer for events received before setOnEvent is called.
      // Flushed on first setOnEvent call, then set to null.
      eventBuffer: [],
    };
    const app = new PlushieAppCtor(settingsJson, (eventJson) => {
      if (transport.eventBuffer !== null) {
        // Still in startup -- buffer the event
        transport.eventBuffer.push(eventJson);
      } else {
        transport.onEvent(eventJson);
      }
    });
    transport.app = app;
    return new Ok(transport);
  } catch (e) {
    return new Error(`WASM init failed: ${e}`);
  }
}

/**
 * Replace the event callback and flush any buffered events.
 *
 * Called after the runtime is initialized. Any events that arrived
 * between create() and this call are replayed in order.
 */
export function setOnEvent(transport, onEvent) {
  transport.onEvent = onEvent;
  // Flush buffered events from the startup window
  if (transport.eventBuffer !== null) {
    const buffered = transport.eventBuffer;
    transport.eventBuffer = null;
    for (const eventJson of buffered) {
      onEvent(eventJson);
    }
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
  // Call wasm-bindgen's free() if available to release WASM memory.
  transport.app?.free?.();
  transport.app = null;
  transport.eventBuffer = null;
}
