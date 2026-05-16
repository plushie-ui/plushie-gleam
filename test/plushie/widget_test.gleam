//// Pure tests for the typed payload helpers in `plushie/widget`.
////
//// The emit/decode pairs are trivially thin wrappers over
//// `gleam/dynamic/decode`, but pinning their behaviour here keeps the
//// receive-side API contract explicit and catches accidental
//// regressions in the wrappers themselves.

import gleam/dynamic
import gleeunit/should
import plushie/widget

pub fn decode_float_returns_ok_for_float_test() {
  should.equal(widget.decode_float(dynamic.float(1.5)), Ok(1.5))
}

pub fn decode_float_returns_error_for_wrong_type_test() {
  let assert Error(_) = widget.decode_float(dynamic.string("oops"))
}

pub fn decode_int_returns_ok_for_int_test() {
  should.equal(widget.decode_int(dynamic.int(42)), Ok(42))
}

pub fn decode_int_returns_error_for_wrong_type_test() {
  let assert Error(_) = widget.decode_int(dynamic.float(1.5))
}

pub fn decode_string_returns_ok_for_string_test() {
  should.equal(widget.decode_string(dynamic.string("hello")), Ok("hello"))
}

pub fn decode_string_returns_error_for_wrong_type_test() {
  let assert Error(_) = widget.decode_string(dynamic.int(0))
}

pub fn decode_bool_returns_ok_for_bool_test() {
  should.equal(widget.decode_bool(dynamic.bool(True)), Ok(True))
}

pub fn decode_bool_returns_error_for_wrong_type_test() {
  let assert Error(_) = widget.decode_bool(dynamic.string("true"))
}
