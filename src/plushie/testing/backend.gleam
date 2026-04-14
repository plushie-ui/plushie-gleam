//// Test backend: record-of-functions defining backend capabilities.
////
//// The `TestBackend` type is a record of functions that implement
//// each testing operation (find, click, type_text, etc.). This
//// design lets tests be polymorphic over the backend: the same
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
import gleam/string
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/testing/element.{type Element}
import plushie/testing/session.{type TestSession}

/// Selector for finding elements.
pub type Selector {
  /// Match a widget by ID (local, scoped, or window-qualified).
  ById(String)
  /// Match a widget by accessibility role.
  ByRole(String)
  /// Match a widget by accessibility label or content.
  ByLabel(String)
  /// Match a widget by visible text content.
  ByText(String)
  /// Match the focused widget.
  Focused
  /// Scope any selector to a specific window subtree.
  InWindow(window_id: String, selector: Selector)
}

/// Parse a selector from a unified string syntax.
///
/// Supported forms:
/// - `"form/email"` or `"#form/email"` -> ById("form/email")
/// - `"main#form/email"` -> ById("main#form/email") (window-qualified ID)
/// - `":focused"` -> Focused
/// - `"main#:focused"` -> InWindow("main", Focused)
/// - `"[role=button]"` -> ByRole("button")
/// - `"main#[text=Save]"` -> InWindow("main", ByText("Save"))
///
/// Plain strings without special prefixes are treated as ID selectors.
pub fn parse_selector(input: String) -> Selector {
  case input {
    ":focused" -> Focused
    _ ->
      case string.split_once(input, "#:") {
        // "window#:focused"
        Ok(#(window, "focused")) -> InWindow(window, Focused)
        Ok(#(window, rest)) -> InWindow(window, parse_inner(":" <> rest))
        _ ->
          case string.split_once(input, "#[") {
            // "window#[attr=val]"
            Ok(#(window, rest)) ->
              InWindow(window, parse_attribute_selector("[" <> rest))
            _ ->
              case
                string.starts_with(input, "[") && string.ends_with(input, "]")
              {
                True -> parse_attribute_selector(input)
                False ->
                  case input {
                    "#" <> rest -> ById(rest)
                    _ -> ById(input)
                  }
              }
          }
      }
  }
}

fn parse_inner(input: String) -> Selector {
  case input {
    ":focused" -> Focused
    _ ->
      case string.starts_with(input, "[") && string.ends_with(input, "]") {
        True -> parse_attribute_selector(input)
        False -> ById(input)
      }
  }
}

fn parse_attribute_selector(input: String) -> Selector {
  // Strip [ and ]
  let inner =
    input
    |> string.drop_start(1)
    |> string.drop_end(1)
  case string.split_once(inner, "=") {
    Ok(#("role", value)) -> ByRole(value)
    Ok(#("label", value)) -> ByLabel(value)
    Ok(#("text", value)) -> ByText(value)
    _ -> ById(input)
  }
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
