//// Test backend: record-of-functions defining backend capabilities.
////
//// The `TestBackend` type is a record of functions that implement
//// each testing operation (find, click, type_text, etc.). This
//// design lets tests be polymorphic over the backend -- the same
//// test code runs at different fidelity levels.
////
//// ## Backend variants
////
//// - **mock**: `plushie-renderer --mock` via session pool.
////   Protocol-only, no rendering. Default backend.
//// - **headless**: `plushie-renderer --headless` with software
////   rendering. Supports screenshots and pixel assertions.
//// - **windowed**: `plushie-renderer` with GPU rendering and
////   visible windows.
////
//// See `plushie/testing.gleam` for backend selection via
//// `PLUSHIE_TEST_BACKEND` env var.

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
    press_key: fn(TestSession(model, Event), String) ->
      TestSession(model, Event),
    release_key: fn(TestSession(model, Event), String) ->
      TestSession(model, Event),
    type_key: fn(TestSession(model, Event), String) -> TestSession(model, Event),
    canvas_press: fn(TestSession(model, Event), String, Float, Float) ->
      TestSession(model, Event),
    model: fn(TestSession(model, Event)) -> model,
    tree: fn(TestSession(model, Event)) -> Node,
    reset: fn(TestSession(model, Event)) -> TestSession(model, Event),
    send_event: fn(TestSession(model, Event), Event) ->
      TestSession(model, Event),
  )
}
