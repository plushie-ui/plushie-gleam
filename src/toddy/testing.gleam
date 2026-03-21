//// Test facade for toddy applications.
////
//// Provides a pure functional test harness that runs the Elm loop
//// (init -> update -> view -> normalize) without the Rust binary.
//// State is threaded immutably through each operation.
////
//// ## Usage
////
////     let session = test.start(my_app)
////     let session = test.click(session, "increment")
////     let model = test.model(session)
////     should.equal(model.count, 1)

import gleam/option.{type Option}
import toddy/app.{type App}
import toddy/event.{type Event}
import toddy/node.{type Node, type PropValue}
import toddy/testing/element.{type Element}
import toddy/testing/helpers
import toddy/testing/session.{type TestSession}

/// Start a test session for a simple app (msg = Event).
pub fn start(app: App(model, Event)) -> TestSession(model, Event) {
  session.start(app)
}

/// Return the current model from the session.
pub fn model(session: TestSession(model, Event)) -> model {
  session.model(session)
}

/// Return the current normalized tree from the session.
pub fn tree(session: TestSession(model, Event)) -> Node {
  session.current_tree(session)
}

/// Dispatch a raw event through the update cycle.
pub fn send_event(
  session: TestSession(model, Event),
  event: Event,
) -> TestSession(model, Event) {
  session.send_event(session, event)
}

// -- Interaction helpers (delegate to helpers module) --------------------------

/// Simulate a click on a widget by ID.
pub fn click(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  helpers.click(session, id)
}

/// Simulate text input on a widget by ID.
pub fn type_text(
  session: TestSession(model, Event),
  id: String,
  text: String,
) -> TestSession(model, Event) {
  helpers.type_text(session, id, text)
}

/// Simulate a checkbox/toggler toggle by ID.
pub fn toggle(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  helpers.toggle(session, id)
}

/// Simulate form submission on a widget by ID.
pub fn submit(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  helpers.submit(session, id)
}

/// Simulate a slider change by ID.
pub fn slide(
  session: TestSession(model, Event),
  id: String,
  value: Float,
) -> TestSession(model, Event) {
  helpers.slide(session, id, value)
}

/// Simulate selection on a widget by ID.
pub fn select(
  session: TestSession(model, Event),
  id: String,
  value: String,
) -> TestSession(model, Event) {
  helpers.select(session, id, value)
}

// -- Element queries (delegate to element module) -----------------------------

/// Find an element by ID in the session's current tree.
pub fn find(session: TestSession(model, Event), id: String) -> Option(Element) {
  element.find(in: session.current_tree(session), id:)
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
