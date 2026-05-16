//// Tests for the dimmer example: a custom-Msg app composed with a
//// custom canvas widget.
////
//// Runs against the real plushie-renderer binary via the pooled
//// `testing.start` backend. The app uses `app.application` with a
//// typed Msg, and the test helpers drive interactions by widget ID
//// (buttons) or canvas coordinates (the dimmer). Wire Events
//// produced by the renderer pass through the app's on_event mapper
//// before reaching update; these tests verify the full chain.

import examples/dimmer
import examples/widgets/dimmer as dimmer_widget
import gleam/dynamic
import gleam/option
import gleeunit/should
import plushie/event.{
  type Event, type Modifiers, EventTarget, LeftButton, Modifiers, Mouse, Press,
  Widget,
}
import plushie/testing
import plushie/testing/element
import plushie/widget.{Emit, WidgetDef}

// ---------------------------------------------------------------------------
// Widget unit tests (Press -> Emit, pure)
// ---------------------------------------------------------------------------

fn no_modifiers() -> Modifiers {
  Modifiers(shift: False, ctrl: False, alt: False, logo: False, command: False)
}

fn press_at(y: Float) -> Event {
  Widget(Press(
    target: EventTarget(window_id: "", id: "dimmer", scope: [], full: "dimmer"),
    x: 30.0,
    y: y,
    button: LeftButton,
    pointer: Mouse,
    finger: option.None,
    modifiers: no_modifiers(),
    captured: False,
  ))
}

pub fn widget_press_at_top_emits_full_brightness_test() {
  let WidgetDef(init:, handle_event:, ..) = dimmer_widget.def()
  let #(action, _) = handle_event(press_at(0.0), init())
  should.equal(action, Emit(kind: "change", data: dynamic.float(1.0)))
}

pub fn widget_press_at_bottom_emits_zero_test() {
  let WidgetDef(init:, handle_event:, ..) = dimmer_widget.def()
  let #(action, _) = handle_event(press_at(dimmer_widget.height), init())
  should.equal(action, Emit(kind: "change", data: dynamic.float(0.0)))
}

pub fn widget_press_at_midpoint_emits_half_brightness_test() {
  let WidgetDef(init:, handle_event:, ..) = dimmer_widget.def()
  let #(action, _) = handle_event(press_at(dimmer_widget.height /. 2.0), init())
  should.equal(action, Emit(kind: "change", data: dynamic.float(0.5)))
}

pub fn widget_press_above_bounds_clamps_to_one_test() {
  let WidgetDef(init:, handle_event:, ..) = dimmer_widget.def()
  let #(action, _) = handle_event(press_at(-50.0), init())
  should.equal(action, Emit(kind: "change", data: dynamic.float(1.0)))
}

pub fn widget_press_below_bounds_clamps_to_zero_test() {
  let WidgetDef(init:, handle_event:, ..) = dimmer_widget.def()
  let #(action, _) =
    handle_event(press_at(dimmer_widget.height +. 50.0), init())
  should.equal(action, Emit(kind: "change", data: dynamic.float(0.0)))
}

// ---------------------------------------------------------------------------
// App integration tests (real renderer, real wire, typed Msg)
// ---------------------------------------------------------------------------

fn read_brightness(ctx: testing.TestContext(dimmer.Model, dimmer.Msg)) -> Float {
  testing.model(ctx).brightness
}

fn approx(a: Float, b: Float) -> Bool {
  let d = a -. b
  case d <. 0.0 {
    True -> 0.0 -. d <. 0.0001
    False -> d <. 0.0001
  }
}

pub fn starts_at_half_brightness_test() {
  let ctx = testing.start(dimmer.app())
  should.be_true(approx(read_brightness(ctx), 0.5))
  testing.stop(ctx)
}

pub fn readout_shows_initial_percent_test() {
  let ctx = testing.start(dimmer.app())
  let assert option.Some(el) = testing.find(ctx, "readout")
  should.equal(element.text(el), option.Some("Brightness: 50%"))
  testing.stop(ctx)
}

pub fn cut_power_button_zeroes_brightness_test() {
  let ctx = testing.start(dimmer.app())
  let ctx = testing.click(ctx, "cut")
  should.be_true(approx(read_brightness(ctx), 0.0))
  let assert option.Some(el) = testing.find(ctx, "readout")
  should.equal(element.text(el), option.Some("Brightness: 0%"))
  testing.stop(ctx)
}

pub fn boost_button_increases_brightness_test() {
  let ctx = testing.start(dimmer.app())
  let ctx = testing.click(ctx, "boost")
  should.be_true(approx(read_brightness(ctx), 0.6))
  let assert option.Some(el) = testing.find(ctx, "readout")
  should.equal(element.text(el), option.Some("Brightness: 60%"))
  testing.stop(ctx)
}

pub fn repeated_boost_clamps_at_one_test() {
  let ctx = testing.start(dimmer.app())
  // 6 boosts from 0.5 at +0.1 each saturates at 1.0.
  let ctx = testing.click(ctx, "boost")
  let ctx = testing.click(ctx, "boost")
  let ctx = testing.click(ctx, "boost")
  let ctx = testing.click(ctx, "boost")
  let ctx = testing.click(ctx, "boost")
  let ctx = testing.click(ctx, "boost")
  should.be_true(approx(read_brightness(ctx), 1.0))
  testing.stop(ctx)
}

pub fn canvas_press_quarter_sets_three_quarter_brightness_test() {
  let ctx = testing.start(dimmer.app())
  let ctx =
    testing.canvas_press(
      ctx,
      "dimmer",
      30.0,
      dimmer_widget.height /. 4.0,
      LeftButton,
    )
  // y = height/4 -> value = 1 - 0.25 = 0.75.
  should.be_true(approx(read_brightness(ctx), 0.75))
  let assert option.Some(el) = testing.find(ctx, "readout")
  should.equal(element.text(el), option.Some("Brightness: 75%"))
  testing.stop(ctx)
}

pub fn canvas_press_three_quarter_sets_quarter_brightness_test() {
  let ctx = testing.start(dimmer.app())
  let ctx =
    testing.canvas_press(
      ctx,
      "dimmer",
      30.0,
      3.0 *. dimmer_widget.height /. 4.0,
      LeftButton,
    )
  // y = 3*height/4 -> value = 1 - 0.75 = 0.25.
  should.be_true(approx(read_brightness(ctx), 0.25))
  let assert option.Some(el) = testing.find(ctx, "readout")
  should.equal(element.text(el), option.Some("Brightness: 25%"))
  testing.stop(ctx)
}

pub fn unrelated_click_is_ignored_test() {
  let ctx = testing.start(dimmer.app())
  // Click an ID that the app doesn't route. on_event must fall through
  // to Ignore and leave the model untouched. A follow-up cut click
  // proves the runtime is still alive and reacting to recognized
  // events.
  let ctx = testing.click(ctx, "buttons")
  should.be_true(approx(read_brightness(ctx), 0.5))
  let ctx = testing.click(ctx, "cut")
  should.be_true(approx(read_brightness(ctx), 0.0))
  testing.stop(ctx)
}
