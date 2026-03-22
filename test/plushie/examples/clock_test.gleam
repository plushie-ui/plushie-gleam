//// Integration tests for the Clock example.

import gleam/option
import gleam/string
import gleeunit/should
import plushie/event
import plushie/testing
import plushie/testing/element

import examples/clock

pub fn initial_time_display_shows_wall_clock_test() {
  let session = testing.start(clock.app())
  let assert option.Some(el) = testing.find(session, "clock_display")
  let assert option.Some(text) = element.text(el)
  // Wall-clock time should be in HH:MM:SS format
  should.equal(string.length(text), 8)
  should.be_true(string.contains(text, ":"))
}

pub fn timer_tick_updates_time_test() {
  let session = testing.start(clock.app())
  let assert option.Some(before) = testing.find(session, "clock_display")
  let assert option.Some(_time_before) = element.text(before)
  // After a tick, the display still shows valid time
  let session =
    testing.send_event(session, event.TimerTick(tag: "tick", timestamp: 1000))
  let assert option.Some(after) = testing.find(session, "clock_display")
  let assert option.Some(time_after) = element.text(after)
  should.equal(string.length(time_after), 8)
}

pub fn subtitle_text_is_present_test() {
  let session = testing.start(clock.app())
  let assert option.Some(el) = testing.find(session, "subtitle")
  should.equal(element.text(el), option.Some("Updates every second"))
}

pub fn time_display_exists_test() {
  let session = testing.start(clock.app())
  should.be_true(option.is_some(testing.find(session, "clock_display")))
}
