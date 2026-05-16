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
import plushie/event.{type Event, type MouseButton}
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
pub type TestBackend(model, msg) {
  TestBackend(
    start: fn(App(model, msg)) -> TestSession(model, msg),
    stop: fn(TestSession(model, msg)) -> Nil,
    find: fn(TestSession(model, msg), String) -> Option(Element),
    click: fn(TestSession(model, msg), String) -> TestSession(model, msg),
    type_text: fn(TestSession(model, msg), String, String) ->
      TestSession(model, msg),
    submit: fn(TestSession(model, msg), String) -> TestSession(model, msg),
    toggle: fn(TestSession(model, msg), String) -> TestSession(model, msg),
    select: fn(TestSession(model, msg), String, String) ->
      TestSession(model, msg),
    slide: fn(TestSession(model, msg), String, Float) -> TestSession(model, msg),
    press_key: fn(TestSession(model, msg), String) -> TestSession(model, msg),
    release_key: fn(TestSession(model, msg), String) -> TestSession(model, msg),
    type_key: fn(TestSession(model, msg), String) -> TestSession(model, msg),
    canvas_press: fn(TestSession(model, msg), String, Float, Float, MouseButton) ->
      TestSession(model, msg),
    canvas_release: fn(
      TestSession(model, msg),
      String,
      Float,
      Float,
      MouseButton,
    ) ->
      TestSession(model, msg),
    canvas_move: fn(TestSession(model, msg), String, Float, Float) ->
      TestSession(model, msg),
    paste: fn(TestSession(model, msg), String, String) ->
      TestSession(model, msg),
    sort: fn(TestSession(model, msg), String, String) -> TestSession(model, msg),
    canvas_touch_press: fn(TestSession(model, msg), String, Float, Float, Int) ->
      TestSession(model, msg),
    canvas_touch_release: fn(TestSession(model, msg), String, Float, Float, Int) ->
      TestSession(model, msg),
    canvas_touch_move: fn(TestSession(model, msg), String, Float, Float, Int) ->
      TestSession(model, msg),
    model: fn(TestSession(model, msg)) -> model,
    tree: fn(TestSession(model, msg)) -> Node,
    reset: fn(TestSession(model, msg)) -> TestSession(model, msg),
    send_event: fn(TestSession(model, msg), Event) -> TestSession(model, msg),
  )
}
