//// Test backend: record-of-functions defining backend capabilities.
////
//// The `TestBackend` type is a record of functions that implement
//// each testing operation (find, click, type_text, etc.). This
//// design lets tests be polymorphic over the backend -- swap
//// `mock()` for `headless()` or `windowed()` and the same test
//// code runs at different fidelity levels.
////
//// ## Backend variants
////
//// - **mock()**: pure Gleam, no renderer process. Runs the Elm loop
////   directly. Fast, deterministic, no external dependencies. Best
////   for unit-testing logic, tree structure, and model state.
//// - **headless()**: starts the Rust binary with `--headless` for
////   software rendering. Supports screenshots and pixel-level
////   assertions. Requires the plushie binary on PATH or configured.
//// - **windowed()**: starts the Rust binary with GPU rendering and
////   a visible window. For manual visual verification and
////   interactive debugging.
////
//// ## Concurrency
////
//// Mock backends are synchronous -- each operation completes
//// immediately in the calling process. Headless and windowed
//// backends communicate with a renderer actor over OTP messages,
//// so operations involve a `process.call` with a timeout.
//// All backends are single-session; concurrent access to the
//// same session is not supported.

import gleam/option.{type Option}
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/testing/element.{type Element}
import plushie/testing/session.{type TestSession}

/// Selector for finding elements: by ID string, by role, by label, or focused.
pub type Selector {
  ById(String)
  ByRole(String)
  ByLabel(String)
  Focused
}

/// A test backend defined as a record of functions.
/// Each function implements a specific testing operation.
pub type TestBackend(model) {
  TestBackend(
    start: fn(App(model, Event)) -> TestSession(model, Event),
    stop: fn(TestSession(model, Event)) -> Nil,
    find: fn(TestSession(model, Event), String) -> Option(Element),
    click: fn(TestSession(model, Event), String) -> TestSession(model, Event),
    type_text: fn(TestSession(model, Event), String, String) ->
      TestSession(model, Event),
    submit: fn(TestSession(model, Event), String) -> TestSession(model, Event),
    toggle: fn(TestSession(model, Event), String) -> TestSession(model, Event),
    select: fn(TestSession(model, Event), String, String) ->
      TestSession(model, Event),
    slide: fn(TestSession(model, Event), String, Float) ->
      TestSession(model, Event),
    model: fn(TestSession(model, Event)) -> model,
    tree: fn(TestSession(model, Event)) -> Node,
    reset: fn(TestSession(model, Event)) -> TestSession(model, Event),
    send_event: fn(TestSession(model, Event), Event) ->
      TestSession(model, Event),
  )
}

/// Create a mock backend using the existing functional test session.
/// This is the default backend: pure Gleam, no renderer needed.
pub fn mock() -> TestBackend(model) {
  TestBackend(
    start: fn(app) { session.start(app) },
    stop: fn(_session) { Nil },
    find: fn(sess, id) { element.find(in: session.current_tree(sess), id:) },
    click: fn(sess, id) {
      let #(local, scope) = split_scoped_id(id)
      session.send_event(sess, event.WidgetClick(id: local, scope:))
    },
    type_text: fn(sess, id, text) {
      let #(local, scope) = split_scoped_id(id)
      session.send_event(
        sess,
        event.WidgetInput(id: local, scope:, value: text),
      )
    },
    submit: fn(sess, id) {
      let #(local, scope) = split_scoped_id(id)
      session.send_event(sess, event.WidgetSubmit(id: local, scope:, value: ""))
    },
    toggle: fn(sess, id) {
      let #(local, scope) = split_scoped_id(id)
      session.send_event(
        sess,
        event.WidgetToggle(id: local, scope:, value: True),
      )
    },
    select: fn(sess, id, value) {
      let #(local, scope) = split_scoped_id(id)
      session.send_event(sess, event.WidgetSelect(id: local, scope:, value:))
    },
    slide: fn(sess, id, value) {
      let #(local, scope) = split_scoped_id(id)
      session.send_event(sess, event.WidgetSlide(id: local, scope:, value:))
    },
    model: fn(sess) { session.model(sess) },
    tree: fn(sess) { session.current_tree(sess) },
    reset: fn(sess) { session.start(session.get_app(sess)) },
    send_event: fn(sess, ev) { session.send_event(sess, ev) },
  )
}

// -- Helpers -----------------------------------------------------------------

import gleam/list
import gleam/string

/// Split a scoped ID like "form/panel/btn" into ("btn", ["form", "panel"]).
fn split_scoped_id(scoped_id: String) -> #(String, List(String)) {
  case string.split(scoped_id, "/") {
    [] -> #(scoped_id, [])
    [single] -> #(single, [])
    segments -> {
      let assert Ok(local) = list.last(segments)
      let scope = list.take(segments, list.length(segments) - 1)
      #(local, scope)
    }
  }
}
