//// Integration tests for the RatePlushie example.

import gleam/option
import gleeunit/should
import plushie/testing
import plushie/testing/element

import examples/rate_plushie

pub fn review_form_inputs_exist_test() {
  let ctx = testing.start(rate_plushie.app())
  should.be_true(option.is_some(testing.find(ctx, "review-name")))
  should.be_true(option.is_some(testing.find(ctx, "review-comment")))
  should.be_true(option.is_some(testing.find(ctx, "submit-review")))
}

pub fn submit_with_no_data_shows_errors_test() {
  let ctx = testing.start(rate_plushie.app())
  let ctx = testing.click(ctx, "submit-review")
  // All three error messages should appear when the form is empty
  should.be_true(option.is_some(testing.find(ctx, "review-name-error")))
  should.be_true(option.is_some(testing.find(ctx, "stars-error")))
}

pub fn typing_name_clears_name_error_test() {
  let ctx = testing.start(rate_plushie.app())
  let ctx = testing.click(ctx, "submit-review")
  should.be_true(option.is_some(testing.find(ctx, "review-name-error")))
  let ctx = testing.type_text(ctx, "review-name", "Alice")
  should.be_true(option.is_none(testing.find(ctx, "review-name-error")))
}

pub fn heading_text_is_present_test() {
  let ctx = testing.start(rate_plushie.app())
  let assert option.Some(el) = testing.find(ctx, "heading")
  should.equal(element.text(el), option.Some("Rate Plushie"))
}
