//// Interaction helpers for test sessions.
////
//// These functions simulate user interactions by constructing the
//// appropriate Event and dispatching it through the session's update
//// cycle. Each returns a new TestSession with updated state.

import gleam/dict
import gleam/list
import gleam/option
import gleam/string
import toddy/event.{type Event}
import toddy/ffi
import toddy/node.{BoolVal, StringVal}
import toddy/testing/element
import toddy/testing/session.{type TestSession}
import toddy/tree

/// Simulate a click on a widget by ID. Dispatches WidgetClick.
pub fn click(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  let #(local, scope) = resolve_id(session, id)
  session.send_event(session, event.WidgetClick(id: local, scope:))
}

/// Simulate text input on a widget by ID. Dispatches WidgetInput.
pub fn type_text(
  session: TestSession(model, Event),
  id: String,
  text: String,
) -> TestSession(model, Event) {
  let #(local, scope) = resolve_id(session, id)
  session.send_event(session, event.WidgetInput(id: local, scope:, value: text))
}

/// Simulate a checkbox/toggler toggle by ID. Reads the current value
/// from the tree and dispatches the inverse.
pub fn toggle(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  let #(local, scope) = resolve_id(session, id)
  let current_value = read_bool_prop(session, id)
  session.send_event(
    session,
    event.WidgetToggle(id: local, scope:, value: !current_value),
  )
}

/// Simulate form submission on a widget by ID. Reads the current
/// text value from the tree and dispatches WidgetSubmit.
pub fn submit(
  session: TestSession(model, Event),
  id: String,
) -> TestSession(model, Event) {
  let #(local, scope) = resolve_id(session, id)
  let value = read_string_prop(session, id, "value")
  session.send_event(session, event.WidgetSubmit(id: local, scope:, value:))
}

/// Simulate a slider change by ID. Dispatches WidgetSlide.
pub fn slide(
  session: TestSession(model, Event),
  id: String,
  value: Float,
) -> TestSession(model, Event) {
  let #(local, scope) = resolve_id(session, id)
  session.send_event(session, event.WidgetSlide(id: local, scope:, value:))
}

/// Simulate selection on a widget by ID. Dispatches WidgetSelect.
pub fn select(
  session: TestSession(model, Event),
  id: String,
  value: String,
) -> TestSession(model, Event) {
  let #(local, scope) = resolve_id(session, id)
  session.send_event(session, event.WidgetSelect(id: local, scope:, value:))
}

// -- Internal -----------------------------------------------------------------

/// Resolve a user-provided ID to #(local_id, scope_list).
/// Looks up the element in the normalized tree to find its scoped path.
fn resolve_id(
  session: TestSession(model, msg),
  id: String,
) -> #(String, List(String)) {
  let current_tree = session.current_tree(session)
  case element.find(in: current_tree, id:) {
    option.Some(el) -> split_scoped_id(element.id(el))
    option.None -> #(id, [])
  }
}

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

/// Read a boolean prop from a widget in the tree.
fn read_bool_prop(session: TestSession(model, msg), id: String) -> Bool {
  let current_tree = session.current_tree(session)
  case tree.find(current_tree, id) {
    option.Some(node) -> {
      case dict.get(node.props, "is_checked") {
        Ok(BoolVal(v)) -> v
        _ ->
          case dict.get(node.props, "is_toggled") {
            Ok(BoolVal(v)) -> v
            _ -> False
          }
      }
    }
    option.None -> False
  }
}

/// Check whether a display server is available (DISPLAY or WAYLAND_DISPLAY).
/// Use this to guard tests that spawn the actual toddy renderer so they
/// skip gracefully in headless CI environments without Xvfb.
pub fn display_available() -> Bool {
  case ffi.get_env("DISPLAY"), ffi.get_env("WAYLAND_DISPLAY") {
    Ok(_), _ -> True
    _, Ok(_) -> True
    _, _ -> False
  }
}

/// Read a string prop from a widget in the tree.
fn read_string_prop(
  session: TestSession(model, msg),
  id: String,
  key: String,
) -> String {
  let current_tree = session.current_tree(session)
  case tree.find(current_tree, id) {
    option.Some(node) ->
      case dict.get(node.props, key) {
        Ok(StringVal(s)) -> s
        _ -> ""
      }
    option.None -> ""
  }
}
