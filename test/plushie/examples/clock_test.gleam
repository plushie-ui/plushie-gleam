//// Integration tests for the Clock example.

import gleam/option
import gleeunit/should
import plushie/event
import plushie/testing
import plushie/testing/element

import examples/clock

pub fn initial_time_display_is_zero_test() {
  let session = testing.start(clock.app())
  let assert option.Some(el) = testing.find(session, "time")
  should.equal(element.text(el), option.Some("00:00:00"))
}

pub fn timer_tick_updates_elapsed_test() {
  let session = testing.start(clock.app())
  let session =
    testing.send_event(session, event.TimerTick(tag: "tick", timestamp: 1000))
  let assert option.Some(el) = testing.find(session, "time")
  should.equal(element.text(el), option.Some("00:00:01"))
}

pub fn multiple_ticks_accumulate_test() {
  let session = testing.start(clock.app())
  let session =
    testing.send_event(session, event.TimerTick(tag: "tick", timestamp: 1000))
  let session =
    testing.send_event(session, event.TimerTick(tag: "tick", timestamp: 2000))
  let session =
    testing.send_event(session, event.TimerTick(tag: "tick", timestamp: 3000))
  let assert option.Some(el) = testing.find(session, "time")
  should.equal(element.text(el), option.Some("00:00:03"))
}

pub fn label_text_is_present_test() {
  let session = testing.start(clock.app())
  let assert option.Some(el) = testing.find(session, "label")
  should.equal(element.text(el), option.Some("Elapsed time"))
}

pub fn time_display_exists_test() {
  let session = testing.start(clock.app())
  should.be_true(option.is_some(testing.find(session, "time")))
}
