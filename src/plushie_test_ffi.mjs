// Test FFI: JavaScript implementations.
//
// Mirrors plushie_test_ffi.erl for the JS target. Emit is synchronous:
// values are collected in an array as the work function runs, then
// returned as a Gleam list paired with the final return value.

import { toList } from "./gleam.mjs";

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
