//// Test facade for plushie applications.
////
//// Provides a unified test API that works across all backends:
//// mock (pure Gleam), pooled_mock (shared renderer), headless
//// (software rendering), and windowed (GPU + display).
////
//// ## Backend selection
////
//// Set `PLUSHIE_TEST_BACKEND` to choose the backend:
////
////     PLUSHIE_TEST_BACKEND=pooled_mock gleam test
////     PLUSHIE_TEST_BACKEND=headless gleam test
////
//// Default: `mock` (pure Gleam, no renderer binary needed).
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
import plushie/testing/backend/pooled
import plushie/testing/element.{type Element}
import plushie/testing/helpers
import plushie/testing/session.{type TestSession}
import plushie/testing/session_pool

// -- Session lifecycle -------------------------------------------------------

/// Start a test session for a simple app (msg = Event).
///
/// The backend is selected via `PLUSHIE_TEST_BACKEND`:
/// - (unset/`mock`): pure Gleam, no renderer binary
/// - `pooled_mock`: shared `plushie --mock` process
/// - `headless`: `plushie --headless` with software rendering
pub fn start(app: App(model, Event)) -> TestSession(model, Event) {
  case resolve_backend() {
    option.Some(be) -> be.start(app)
    option.None -> session.start(app)
  }
}

/// Stop the test session and release resources.
///
/// No-op for mock backend. Releases the renderer session for
/// pooled and headless backends.
pub fn stop(session: TestSession(model, Event)) -> Nil {
  case resolve_backend() {
    option.Some(be) -> be.stop(session)
    option.None -> Nil
  }
}

/// Return the current model from the session.
pub fn model(session: TestSession(model, Event)) -> model {
  case resolve_backend() {
    option.Some(be) -> be.model(session)
    option.None -> session.model(session)
  }
}

/// Return the current normalized tree from the session.
pub fn tree(session: TestSession(model, Event)) -> Node {
  case resolve_backend() {
    option.Some(be) -> be.tree(session)
    option.None -> session.current_tree(session)
  }
}

/// Dispatch a raw event through the update cycle.
pub fn send_event(
  session: TestSession(model, Event),
  event: Event,
) -> TestSession(model, Event) {
  case resolve_backend() {
    option.Some(be) -> be.send_event(session, event)
    option.None -> session.send_event(session, event)
  }
}

// -- Interaction helpers -----------------------------------------------------

/// Simulate a click on a widget by ID.
pub fn click(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  case resolve_backend() {
    option.Some(be) -> be.click(session, id)
    option.None -> helpers.click(session, id)
  }
}

/// Simulate text input on a widget by ID.
pub fn type_text(
  session: TestSession(model, Event),
  id: String,
  text: String,
) -> TestSession(model, Event) {
  case resolve_backend() {
    option.Some(be) -> be.type_text(session, id, text)
    option.None -> helpers.type_text(session, id, text)
  }
}

/// Simulate a checkbox/toggler toggle by ID.
pub fn toggle(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  case resolve_backend() {
    option.Some(be) -> be.toggle(session, id)
    option.None -> helpers.toggle(session, id)
  }
}

/// Simulate form submission on a widget by ID.
pub fn submit(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  case resolve_backend() {
    option.Some(be) -> be.submit(session, id)
    option.None -> helpers.submit(session, id)
  }
}

/// Simulate a slider change by ID.
pub fn slide(
  session: TestSession(model, Event),
  id: String,
  value: Float,
) -> TestSession(model, Event) {
  case resolve_backend() {
    option.Some(be) -> be.slide(session, id, value)
    option.None -> helpers.slide(session, id, value)
  }
}

/// Simulate selection on a widget by ID.
pub fn select(
  session: TestSession(model, Event),
  id: String,
  value: String,
) -> TestSession(model, Event) {
  case resolve_backend() {
    option.Some(be) -> be.select(session, id, value)
    option.None -> helpers.select(session, id, value)
  }
}

// -- Element queries ---------------------------------------------------------

/// Find an element by ID in the session's current tree.
pub fn find(session: TestSession(model, Event), id: String) -> Option(Element) {
  case resolve_backend() {
    option.Some(be) -> be.find(session, id)
    option.None -> element.find(in: session.current_tree(session), id:)
  }
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

/// Resolve the backend from PLUSHIE_TEST_BACKEND env var.
/// Returns None for mock (use helpers directly), Some for pooled backends.
fn resolve_backend() -> Option(TestBackend(model)) {
  case ffi.get_env("PLUSHIE_TEST_BACKEND") {
    Ok("pooled_mock") -> option.Some(get_or_start_pooled(session_pool.Mock))
    Ok("headless") -> option.Some(get_or_start_pooled(session_pool.Headless))
    _ -> option.None
  }
}

/// Get or start a pooled backend. The pool is started once per
/// test run and cached in the process dictionary.
fn get_or_start_pooled(mode: session_pool.PoolMode) -> TestBackend(model) {
  case get_pool() {
    Ok(pool_subject) -> pooled.backend(pool_subject)
    Error(_) -> {
      let config =
        session_pool.PoolConfig(..session_pool.default_config(), mode:)
      let assert Ok(pool_subject) = session_pool.start(config)
      put_pool(pool_subject)
      pooled.backend(pool_subject)
    }
  }
}

@external(erlang, "plushie_test_pool_ffi", "get_pool")
fn get_pool() -> Result(session_pool.PoolSubject, Nil)

@external(erlang, "plushie_test_pool_ffi", "put_pool")
fn put_pool(pool: session_pool.PoolSubject) -> Nil
