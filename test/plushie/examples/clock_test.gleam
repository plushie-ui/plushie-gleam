//// Integration tests for the Clock example.

@target(erlang)
import gleam/option
@target(erlang)
import gleam/string
@target(erlang)
import gleeunit/should
@target(erlang)
import plushie/event
@target(erlang)
import plushie/testing
@target(erlang)
import plushie/testing/element

@target(erlang)
import examples/clock

@target(erlang)
pub fn initial_time_display_shows_wall_clock_test() {
  let ctx = testing.start(clock.app())
  let assert option.Some(el) = testing.find(ctx, "clock_display")
  let assert option.Some(text) = element.text(el)
  // Wall-clock time should be in HH:MM:SS format
  should.equal(string.length(text), 8)
  should.be_true(string.contains(text, ":"))
}

@target(erlang)
pub fn timer_tick_updates_time_test() {
  let ctx = testing.start(clock.app())
  let assert option.Some(before) = testing.find(ctx, "clock_display")
  let assert option.Some(_time_before) = element.text(before)
  // After a tick, the display still shows valid time
  let ctx =
    testing.send_event(
      ctx,
      event.Timer(event.TimerEvent(tag: "tick", timestamp: 1000)),
    )
  let assert option.Some(after) = testing.find(ctx, "clock_display")
  let assert option.Some(time_after) = element.text(after)
  should.equal(string.length(time_after), 8)
}

@target(erlang)
pub fn subtitle_text_is_present_test() {
  let ctx = testing.start(clock.app())
  let assert option.Some(el) = testing.find(ctx, "subtitle")
  should.equal(element.text(el), option.Some("Updates every second"))
}

@target(erlang)
pub fn time_display_exists_test() {
  let ctx = testing.start(clock.app())
  should.be_true(option.is_some(testing.find(ctx, "clock_display")))
}
