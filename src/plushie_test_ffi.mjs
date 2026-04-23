// Test FFI: JavaScript implementations.
//
// Mirrors plushie_test_ffi.erl for the JS target. Emit is synchronous:
// values are collected in an array as the work function runs, then
// returned as a Gleam list paired with the final return value.

import { toList } from "./gleam.mjs";
import { setPlushieAppConstructor } from "./plushie_bridge_web_ffi.mjs";

const fakePlushieState = {
  sent: [],
  onEvent: null,
  settingsJson: null,
  freed: false,
  immediateClipboardText: null,
};

export function collect_stream_values(workFn) {
  const emitted = [];
  const emit = (value) => {
    emitted.push(value);
    return undefined;
  };
  const finalValue = workFn(emit);
  return [toList(emitted), finalValue];
}

export function identity(value) {
  return value;
}

export function install_fake_plushie_app() {
  fakePlushieState.sent = [];
  fakePlushieState.onEvent = null;
  fakePlushieState.settingsJson = null;
  fakePlushieState.freed = false;
  fakePlushieState.immediateClipboardText = null;
  globalThis.__plushieImmediateEffectTimeouts = false;

  setPlushieAppConstructor(function FakePlushieApp(settingsJson, onEvent) {
    fakePlushieState.settingsJson = settingsJson;
    fakePlushieState.onEvent = onEvent;
    return {
      send_message(json) {
        fakePlushieState.sent.push(json);
        if (fakePlushieState.immediateClipboardText === null) {
          return;
        }

        const message = JSON.parse(json);
        if (message.type !== "effect" || message.kind !== "clipboard_read") {
          return;
        }

        onEvent(
          JSON.stringify({
            type: "effect_response",
            id: message.id,
            status: "ok",
            result: { text: fakePlushieState.immediateClipboardText },
          }),
        );
      },
      free() {
        fakePlushieState.freed = true;
      },
    };
  });
}

export function reset_fake_plushie_app() {
  fakePlushieState.sent = [];
  fakePlushieState.onEvent = null;
  fakePlushieState.settingsJson = null;
  fakePlushieState.freed = false;
  fakePlushieState.immediateClipboardText = null;
  globalThis.__plushieImmediateEffectTimeouts = false;
}

export function fake_transport_sent_messages() {
  return toList(fakePlushieState.sent);
}

export function fake_transport_emit(json) {
  fakePlushieState.onEvent?.(json);
}

export function set_immediate_effect_timeouts(enabled) {
  globalThis.__plushieImmediateEffectTimeouts = enabled;
}

export function set_immediate_clipboard_text_response(text) {
  fakePlushieState.immediateClipboardText = text;
}
