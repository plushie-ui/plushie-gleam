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
        // "window#:focused" (window must be non-empty)
        Ok(#(window, "focused")) if window != "" -> InWindow(window, Focused)
        Ok(#(window, rest)) if window != "" ->
          InWindow(window, parse_inner(":" <> rest))
        _ ->
          case string.split_once(input, "#[") {
            // "window#[attr=val]" (window must be non-empty)
            Ok(#(window, rest)) if window != "" ->
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
    start: fn(App(model, Event)) -> TestSession(model),
    stop: fn(TestSession(model)) -> Nil,
    find: fn(TestSession(model), String) -> Option(Element),
    click: fn(TestSession(model), String) -> TestSession(model),
    type_text: fn(TestSession(model), String, String) -> TestSession(model),
    submit: fn(TestSession(model), String) -> TestSession(model),
    toggle: fn(TestSession(model), String) -> TestSession(model),
    select: fn(TestSession(model), String, String) -> TestSession(model),
    slide: fn(TestSession(model), String, Float) -> TestSession(model),
    press_key: fn(TestSession(model), String) -> TestSession(model),
    release_key: fn(TestSession(model), String) -> TestSession(model),
    type_key: fn(TestSession(model), String) -> TestSession(model),
    canvas_press: fn(TestSession(model), String, Float, Float) ->
      TestSession(model),
    paste: fn(TestSession(model), String, String) -> TestSession(model),
    sort: fn(TestSession(model), String, String) -> TestSession(model),
    canvas_touch_press: fn(TestSession(model), String, Float, Float, Int) ->
      TestSession(model),
    canvas_touch_release: fn(TestSession(model), String, Float, Float, Int) ->
      TestSession(model),
    canvas_touch_move: fn(TestSession(model), String, Float, Float, Int) ->
      TestSession(model),
    model: fn(TestSession(model)) -> model,
    tree: fn(TestSession(model)) -> Node,
    reset: fn(TestSession(model)) -> TestSession(model),
    send_event: fn(TestSession(model), Event) -> TestSession(model),
  )
}
