//// Test facade for plushie applications.
////
//// Provides a unified test API across all backends. Tests always
//// run against the real plushie-renderer binary.
////
//// ## Backend selection
////
//// Set `PLUSHIE_TEST_BACKEND` to choose the backend:
////
////     gleam test                                  # default: mock
////     PLUSHIE_TEST_BACKEND=headless gleam test    # software rendering
////
//// Default: `mock` (real binary in `--mock` mode, sessions pooled).
////
//// ## Usage
////
////     let session = testing.start(my_app())
////     let session = testing.click(session, "increment")
////     let assert option.Some(el) = testing.find(session, "count")
////     should.equal(element.text(el), option.Some("Count: 1"))
////     testing.stop(session)

import gleam/option.{type Option}
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/ffi
import plushie/node.{type Node, type PropValue}
import plushie/testing/backend.{type TestBackend}
import plushie/testing/backend/mock as mock_backend
import plushie/testing/element.{type Element}
import plushie/testing/session.{type TestSession}
import plushie/testing/session_pool

// -- Session lifecycle -------------------------------------------------------

/// Start a test session for a simple app (msg = Event).
///
/// Requires the plushie-renderer binary. Panics with setup
/// instructions if not found.
pub fn start(app: App(model, Event)) -> TestSession(model, Event) {
  let be = resolve_backend()
  be.start(app)
}

/// Stop the test session and release resources.
pub fn stop(session: TestSession(model, Event)) -> Nil {
  let be = resolve_backend()
  be.stop(session)
}

/// Return the current model from the session.
pub fn model(session: TestSession(model, Event)) -> model {
  let be = resolve_backend()
  be.model(session)
}

/// Return the current normalized tree from the session.
pub fn tree(session: TestSession(model, Event)) -> Node {
  let be = resolve_backend()
  be.tree(session)
}

/// Dispatch a raw event through the update cycle.
pub fn send_event(
  session: TestSession(model, Event),
  event: Event,
) -> TestSession(model, Event) {
  let be = resolve_backend()
  be.send_event(session, event)
}

// -- Interaction helpers -----------------------------------------------------

/// Simulate a click on a widget by ID.
pub fn click(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  let be = resolve_backend()
  be.click(session, id)
}

/// Simulate text input on a widget by ID.
pub fn type_text(
  session: TestSession(model, Event),
  id: String,
  text: String,
) -> TestSession(model, Event) {
  let be = resolve_backend()
  be.type_text(session, id, text)
}

/// Simulate a checkbox/toggler toggle by ID.
pub fn toggle(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  let be = resolve_backend()
  be.toggle(session, id)
}

/// Simulate form submission on a widget by ID.
pub fn submit(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  let be = resolve_backend()
  be.submit(session, id)
}

/// Simulate a slider change by ID.
pub fn slide(
  session: TestSession(model, Event),
  id: String,
  value: Float,
) -> TestSession(model, Event) {
  let be = resolve_backend()
  be.slide(session, id, value)
}

/// Simulate selection on a widget by ID.
pub fn select(
  session: TestSession(model, Event),
  id: String,
  value: String,
) -> TestSession(model, Event) {
  let be = resolve_backend()
  be.select(session, id, value)
}

// -- Element queries ---------------------------------------------------------

/// Find an element by ID in the session's current tree.
pub fn find(session: TestSession(model, Event), id: String) -> Option(Element) {
  let be = resolve_backend()
  be.find(session, id)
}

/// Extract text content from an element.
pub fn element_text(el: Element) -> Option(String) {
  element.text(el)
}

/// Get a prop value from an element.
pub fn element_prop(el: Element, key: String) -> Option(PropValue) {
  element.prop(el, key)
}

/// Get an element's children.
pub fn element_children(el: Element) -> List(Element) {
  element.children(el)
}

// -- Backend resolution ------------------------------------------------------

/// Resolve the test backend from PLUSHIE_TEST_BACKEND env var.
/// Always returns a backend that talks to the real binary.
fn resolve_backend() -> TestBackend(model) {
  case ffi.get_env("PLUSHIE_TEST_BACKEND") {
    Ok("headless") -> get_or_start_pooled(session_pool.Headless)
    // Default: mock (real binary in --mock mode, sessions pooled)
    _ -> get_or_start_pooled(session_pool.Mock)
  }
}

/// Get or start a pooled backend. The pool is started once per
/// test run and cached in the process dictionary.
fn get_or_start_pooled(mode: session_pool.PoolMode) -> TestBackend(model) {
  case get_pool() {
    Ok(pool_subject) -> mock_backend.backend(pool_subject)
    Error(_) -> {
      let config =
        session_pool.PoolConfig(..session_pool.default_config(), mode:)
      let assert Ok(pool_subject) = session_pool.start(config)
      put_pool(pool_subject)
      mock_backend.backend(pool_subject)
    }
  }
}

@external(erlang, "plushie_test_pool_ffi", "get_pool")
fn get_pool() -> Result(session_pool.PoolSubject, Nil)

@external(erlang, "plushie_test_pool_ffi", "put_pool")
fn put_pool(pool: session_pool.PoolSubject) -> Nil
