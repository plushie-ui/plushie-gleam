//// Integration tests for the AsyncFetch example.

import gleam/option
import gleeunit/should
import plushie/testing
import plushie/testing/element

import examples/async_fetch

pub fn starts_in_idle_state_test() {
  let session = testing.start(async_fetch.app())
  let assert option.Some(el) = testing.find(session, "status")
  should.equal(element.text(el), option.Some("Press the button to start"))
}

pub fn fetch_button_exists_test() {
  let session = testing.start(async_fetch.app())
  should.be_true(option.is_some(testing.find(session, "fetch")))
}

pub fn clicking_fetch_triggers_async_and_produces_result_test() {
  let session = testing.start(async_fetch.app())
  // The test backend executes async commands synchronously, so
  // after click the status should already be "done" with data.
  let session = testing.click(session, "fetch")
  let assert option.Some(el) = testing.find(session, "result")
  let assert option.Some(text) = element.text(el)
  should.equal(text, "Hello from the async world")
}
