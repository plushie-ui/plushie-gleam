//// Integration tests for the Shortcuts example.

import gleam/option
import gleeunit/should
import plushie/event
import plushie/testing
import plushie/testing/element

import examples/shortcuts

fn key_press(key: String) -> event.Event {
  event.KeyPress(
    key: key,
    modified_key: key,
    modifiers: event.modifiers_none(),
    physical_key: option.None,
    location: event.Standard,
    text: option.Some(key),
    repeat: False,
    captured: False,
  )
}

pub fn starts_with_zero_events_test() {
  let ctx = testing.start(shortcuts.app())
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("0 key events captured"))
}

pub fn header_text_is_present_test() {
  let ctx = testing.start(shortcuts.app())
  let assert option.Some(el) = testing.find(ctx, "header")
  should.equal(element.text(el), option.Some("Press any key"))
}

pub fn scrollable_log_exists_test() {
  let ctx = testing.start(shortcuts.app())
  should.be_true(option.is_some(testing.find(ctx, "log")))
}

pub fn key_event_increments_count_test() {
  let ctx = testing.start(shortcuts.app())
  let ctx = testing.send_event(ctx, key_press("a"))
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("1 key events captured"))
}

pub fn multiple_key_events_accumulate_test() {
  let ctx = testing.start(shortcuts.app())
  let ctx = testing.send_event(ctx, key_press("a"))
  let ctx = testing.send_event(ctx, key_press("b"))
  let ctx = testing.send_event(ctx, key_press("c"))
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("3 key events captured"))
}
