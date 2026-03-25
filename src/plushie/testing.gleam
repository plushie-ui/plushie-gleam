//// Test facade for plushie applications.
////
//// Provides a unified test API that works on both BEAM and JS targets.
//// The backend is resolved once at `start` and carried through the
//// `TestContext` -- no repeated env lookups or backend construction.
////
//// ## BEAM target
////
//// Tests run against the real plushie-renderer binary. Set
//// `PLUSHIE_TEST_BACKEND` to choose the backend:
////
////     gleam test                                  # default: mock
////     PLUSHIE_TEST_BACKEND=headless gleam test    # software rendering
////
//// Default: `mock` (real binary in `--mock` mode, sessions pooled).
////
//// ## JavaScript target
////
//// Tests run the app's init/update/view cycle in-memory via the
//// pure session runner. No renderer binary is needed. Widget
//// interactions construct events directly.
////
//// ## Usage
////
////     let ctx = testing.start(my_app())
////     let ctx = testing.click(ctx, "increment")
////     let assert option.Some(el) = testing.find(ctx, "count")
////     should.equal(element.text(el), option.Some("Count: 1"))
////     testing.stop(ctx)

import gleam/option.{type Option}
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/node.{type Node, type PropValue}
import plushie/platform
import plushie/testing/backend.{type TestBackend}
import plushie/testing/element.{type Element}
import plushie/testing/session.{type TestSession}

// JS-only import for the pure session backend
@target(javascript)
import plushie/testing/backend/session_backend

// BEAM-only imports for the pooled backend
@target(erlang)
import plushie/testing/backend/mock as mock_backend
@target(erlang)
import plushie/testing/session_pool

// -- TestContext ---------------------------------------------------------------

/// A test context: bundles the session with its backend.
///
/// Created by `start`, threaded through all test operations.
/// The backend is resolved once at startup, not on every call.
pub opaque type TestContext(model) {
  TestContext(session: TestSession(model, Event), backend: TestBackend(model))
}

// -- Session lifecycle -------------------------------------------------------

/// Start a test session for a simple app (msg = Event).
///
/// On BEAM, requires the plushie-renderer binary (panics with
/// setup instructions if not found). On JS, runs in-memory.
pub fn start(app: App(model, Event)) -> TestContext(model) {
  let be = resolve_backend()
  let session = be.start(app)
  TestContext(session:, backend: be)
}

/// Stop the test context and release resources.
pub fn stop(ctx: TestContext(model)) -> Nil {
  ctx.backend.stop(ctx.session)
}

/// Return the current model.
pub fn model(ctx: TestContext(model)) -> model {
  ctx.backend.model(ctx.session)
}

/// Return the current normalized tree.
pub fn tree(ctx: TestContext(model)) -> Node {
  ctx.backend.tree(ctx.session)
}

/// Dispatch a raw event through the update cycle.
pub fn send_event(ctx: TestContext(model), event: Event) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.send_event(ctx.session, event))
}

// -- Interaction helpers -----------------------------------------------------

/// Simulate a click on a widget by ID.
pub fn click(ctx: TestContext(model), id: String) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.click(ctx.session, id))
}

/// Simulate text input on a widget by ID.
pub fn type_text(
  ctx: TestContext(model),
  id: String,
  text: String,
) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.type_text(ctx.session, id, text))
}

/// Simulate a checkbox/toggler toggle by ID.
pub fn toggle(ctx: TestContext(model), id: String) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.toggle(ctx.session, id))
}

/// Simulate form submission on a widget by ID.
pub fn submit(ctx: TestContext(model), id: String) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.submit(ctx.session, id))
}

/// Simulate a slider change by ID.
pub fn slide(
  ctx: TestContext(model),
  id: String,
  value: Float,
) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.slide(ctx.session, id, value))
}

/// Simulate a key press. Key string uses PascalCase wire format
/// (e.g., "ArrowRight", "Escape", "Tab") with optional modifier
/// prefixes ("ctrl+s", "shift+Tab").
pub fn press_key(ctx: TestContext(model), key: String) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.press_key(ctx.session, key))
}

/// Simulate a key release.
pub fn release_key(ctx: TestContext(model), key: String) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.release_key(ctx.session, key))
}

/// Simulate a key press and release.
pub fn type_key(ctx: TestContext(model), key: String) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.type_key(ctx.session, key))
}

/// Simulate a mouse press on a canvas widget at (x, y) coordinates.
pub fn canvas_press(
  ctx: TestContext(model),
  id: String,
  x: Float,
  y: Float,
) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.canvas_press(ctx.session, id, x, y))
}

/// Simulate selection on a widget by ID.
pub fn select(
  ctx: TestContext(model),
  id: String,
  value: String,
) -> TestContext(model) {
  TestContext(..ctx, session: ctx.backend.select(ctx.session, id, value))
}

// -- Element queries ---------------------------------------------------------

/// Find an element by ID in the context's current tree.
pub fn find(ctx: TestContext(model), id: String) -> Option(Element) {
  ctx.backend.find(ctx.session, id)
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

// -- Backend resolution (target-specific) ------------------------------------

@target(erlang)
fn resolve_backend() -> TestBackend(model) {
  case platform.get_env("PLUSHIE_TEST_BACKEND") {
    Ok("headless") -> get_or_start_pooled(session_pool.Headless)
    _ -> get_or_start_pooled(session_pool.Mock)
  }
}

@target(erlang)
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

@target(erlang)
@external(erlang, "plushie_test_pool_ffi", "get_pool")
fn get_pool() -> Result(session_pool.PoolSubject, Nil)

@target(erlang)
@external(erlang, "plushie_test_pool_ffi", "put_pool")
fn put_pool(pool: session_pool.PoolSubject) -> Nil

@target(javascript)
fn resolve_backend() -> TestBackend(model) {
  session_backend.backend()
}
