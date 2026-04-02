//// Pure session test backend.
////
//// Runs the app's init/update/view cycle in-memory without a
//// renderer binary. Uses the same pure Elm loop as the real
//// runtime, but skips the wire protocol and rendering.
////
//// Interactions (click, type_text, toggle, etc.) construct
//// the appropriate Event and dispatch it through the update
//// cycle. Element queries search the normalized tree directly.
////
//// This backend works on both BEAM and JavaScript targets.

import gleam/list
import gleam/option
import gleam/string
import plushie/event
import plushie/event/types.{type EventTarget}
import plushie/key
import plushie/node
import plushie/testing/backend.{type TestBackend, TestBackend}
import plushie/testing/element
import plushie/testing/session

/// Create a pure session test backend.
///
/// All operations run in-memory without a renderer. Widget
/// interactions are simulated by constructing events directly.
pub fn backend() -> TestBackend(model) {
  TestBackend(
    start: fn(app) { session.start(app) },
    stop: fn(_sess) { Nil },
    find: fn(sess, id) { element.find(in: session.current_tree(sess), id:) },
    click: fn(sess, id) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.WidgetClick(target:))
    },
    type_text: fn(sess, id, text) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.WidgetInput(target:, value: text))
    },
    submit: fn(sess, id) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.WidgetSubmit(target:, value: ""))
    },
    toggle: fn(sess, id) {
      let target = resolve_event_target(session.current_tree(sess), id)
      // Determine current toggle state from the tree
      let value = case element.find(in: session.current_tree(sess), id:) {
        option.Some(el) ->
          case element.prop(el, "checked") {
            option.Some(node.BoolVal(v)) -> !v
            _ ->
              case element.prop(el, "is_toggled") {
                option.Some(node.BoolVal(v)) -> !v
                _ -> True
              }
          }
        option.None -> True
      }
      session.send_event(sess, event.WidgetToggle(target:, value:))
    },
    select: fn(sess, id, value) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.WidgetSelect(target:, value:))
    },
    slide: fn(sess, id, value) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.WidgetSlide(target:, value:))
    },
    press_key: fn(sess, key_str) {
      let #(key_name, modifiers) = parse_key_event(key_str)
      session.send_event(
        sess,
        event.KeyPress(
          window_id: "",
          key: key_name,
          modified_key: key_name,
          modifiers:,
          physical_key: option.None,
          location: types.Standard,
          text: option.None,
          repeat: False,
          captured: False,
        ),
      )
    },
    release_key: fn(sess, key_str) {
      let #(key_name, modifiers) = parse_key_event(key_str)
      session.send_event(
        sess,
        event.KeyRelease(
          window_id: "",
          key: key_name,
          modified_key: key_name,
          modifiers:,
          physical_key: option.None,
          location: types.Standard,
          text: option.None,
          captured: False,
        ),
      )
    },
    type_key: fn(sess, key_str) {
      let #(key_name, modifiers) = parse_key_event(key_str)
      let sess =
        session.send_event(
          sess,
          event.KeyPress(
            window_id: "",
            key: key_name,
            modified_key: key_name,
            modifiers:,
            physical_key: option.None,
            location: types.Standard,
            text: option.None,
            repeat: False,
            captured: False,
          ),
        )
      session.send_event(
        sess,
        event.KeyRelease(
          window_id: "",
          key: key_name,
          modified_key: key_name,
          modifiers:,
          physical_key: option.None,
          location: types.Standard,
          text: option.None,
          captured: False,
        ),
      )
    },
    canvas_press: fn(sess, id, x, y) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.WidgetPress(
          target:,
          x:,
          y:,
          button: types.LeftButton,
          pointer: types.Mouse,
          finger: option.None,
          modifiers: types.modifiers_none(),
          captured: False,
        ),
      )
    },
    model: fn(sess) { session.model(sess) },
    tree: fn(sess) { session.current_tree(sess) },
    reset: fn(sess) {
      // Re-initialize the app from scratch
      session.start(session.get_app(sess))
    },
    send_event: fn(sess, evt) { session.send_event(sess, evt) },
  )
}

fn resolve_event_target(tree: node.Node, selector: String) -> EventTarget {
  case find_event_target(tree, selector, "") {
    option.Some(found) -> found
    option.None ->
      panic as {
        "widget not found: \""
        <> selector
        <> "\". Check that the ID matches a widget in the current tree."
      }
  }
}

fn find_event_target(
  tree: node.Node,
  target: String,
  current_window: String,
) -> option.Option(EventTarget) {
  let window_id = case tree.kind {
    "window" -> tree.id
    _ -> current_window
  }

  let local_id = last_segment(tree.id)
  let exact_match = tree.id == target
  let local_match = !string.contains(target, "/") && local_id == target

  case tree.kind != "window" && { exact_match || local_match } {
    True -> {
      let et = types.make_target(tree.id, window_id)
      option.Some(et)
    }
    False -> find_event_target_in_children(tree.children, target, window_id)
  }
}

fn find_event_target_in_children(
  children: List(node.Node),
  target: String,
  current_window: String,
) -> option.Option(EventTarget) {
  case children {
    [] -> option.None
    [child, ..rest] ->
      case find_event_target(child, target, current_window) {
        option.Some(found) -> option.Some(found)
        option.None ->
          find_event_target_in_children(rest, target, current_window)
      }
  }
}

fn last_segment(id: String) -> String {
  case string.split(id, "/") {
    [] -> id
    segments ->
      case list.last(segments) {
        Ok(last) -> last
        Error(_) -> id
      }
  }
}

/// Parse a key string into a resolved key name and Modifiers.
fn parse_key_event(key_str: String) -> #(String, types.Modifiers) {
  let parsed = key.parse(key_str)
  let modifiers =
    types.Modifiers(
      shift: parsed.shift,
      ctrl: parsed.ctrl,
      alt: parsed.alt,
      logo: parsed.logo,
      command: parsed.command,
    )
  #(parsed.key, modifiers)
}
