//// Integration tests for the ColorPicker example.

@target(erlang)
import gleam/option
@target(erlang)
import gleeunit/should
@target(erlang)
import plushie/testing
@target(erlang)
import plushie/testing/element

@target(erlang)
import examples/color_picker

@target(erlang)
pub fn color_picker_widget_is_present_test() {
  let ctx = testing.start(color_picker.app())
  should.be_true(option.is_some(testing.find(ctx, "picker")))
}

@target(erlang)
pub fn swatch_is_present_test() {
  let ctx = testing.start(color_picker.app())
  should.be_true(option.is_some(testing.find(ctx, "swatch")))
}

@target(erlang)
pub fn hsv_display_is_present_test() {
  let ctx = testing.start(color_picker.app())
  should.be_true(option.is_some(testing.find(ctx, "hsv_display")))
}

@target(erlang)
pub fn hex_display_starts_at_red_test() {
  let ctx = testing.start(color_picker.app())
  let assert option.Some(el) = testing.find(ctx, "hex_display")
  should.equal(element.text(el), option.Some("#ff0000"))
}
