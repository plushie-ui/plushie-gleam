//// Integration tests for the Counter example.

import gleam/option
import gleeunit/should
import plushie/testing
import plushie/testing/element

import examples/counter

pub fn starts_with_count_zero_test() {
  let ctx = testing.start(counter.app())
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("Count: 0"))
}

pub fn increment_button_increases_count_test() {
  let ctx = testing.start(counter.app())
  let ctx = testing.click(ctx, "inc")
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("Count: 1"))
}

pub fn decrement_button_decreases_count_test() {
  let ctx = testing.start(counter.app())
  let ctx = testing.click(ctx, "dec")
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("Count: -1"))
}

pub fn multiple_clicks_accumulate_test() {
  let ctx = testing.start(counter.app())
  let ctx = testing.click(ctx, "inc")
  let ctx = testing.click(ctx, "inc")
  let ctx = testing.click(ctx, "inc")
  let ctx = testing.click(ctx, "dec")
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("Count: 2"))
}

pub fn tree_updates_after_click_test() {
  let ctx = testing.start(counter.app())
  let ctx = testing.click(ctx, "inc")
  let ctx = testing.click(ctx, "inc")
  let assert option.Some(el) = testing.find(ctx, "count")
  should.equal(element.text(el), option.Some("Count: 2"))
}

pub fn increment_and_decrement_buttons_exist_test() {
  let ctx = testing.start(counter.app())
  should.be_true(option.is_some(testing.find(ctx, "inc")))
  should.be_true(option.is_some(testing.find(ctx, "dec")))
}
