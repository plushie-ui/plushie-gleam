//// Integration tests for the AsyncFetch example.

@target(erlang)
import gleam/option
@target(erlang)
import gleeunit/should
@target(erlang)
import plushie/testing
@target(erlang)
import plushie/testing/element

@target(erlang)
import examples/async_fetch

@target(erlang)
pub fn starts_in_idle_state_test() {
  let ctx = testing.start(async_fetch.app())
  let assert option.Some(el) = testing.find(ctx, "status")
  should.equal(element.text(el), option.Some("Press the button to start"))
}

@target(erlang)
pub fn fetch_button_exists_test() {
  let ctx = testing.start(async_fetch.app())
  should.be_true(option.is_some(testing.find(ctx, "fetch")))
}

@target(erlang)
pub fn clicking_fetch_triggers_async_and_produces_result_test() {
  let ctx = testing.start(async_fetch.app())
  // The test backend executes async commands synchronously, so
  // after click the status should already be "done" with data.
  let ctx = testing.click(ctx, "fetch")
  let assert option.Some(el) = testing.find(ctx, "result")
  let assert option.Some(text) = element.text(el)
  should.equal(text, "Hello from the async world")
}
