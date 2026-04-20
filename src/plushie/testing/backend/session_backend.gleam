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
import plushie/event.{type EventTarget}
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
      session.send_event(sess, event.Widget(event.Click(target:)))
    },
    type_text: fn(sess, id, text) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.Widget(event.Input(target:, value: text)))
    },
    submit: fn(sess, id) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.Widget(event.Submit(target:, value: "")))
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
      session.send_event(sess, event.Widget(event.Toggle(target:, value:)))
    },
    select: fn(sess, id, value) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.Widget(event.Select(target:, value:)))
    },
    slide: fn(sess, id, value) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.Widget(event.Slide(target:, value:)))
    },
    press_key: fn(sess, key_str) {
      let #(key_name, modifiers) = parse_key_event(key_str)
      session.send_event(
        sess,
        event.Key(event.KeyEvent(
          event_type: event.KeyPressed,
          window_id: "",
          key: key_name,
          modified_key: key_name,
          modifiers:,
          physical_key: option.None,
          location: event.Standard,
          text: option.None,
          repeat: False,
          captured: False,
        )),
      )
    },
    release_key: fn(sess, key_str) {
      let #(key_name, modifiers) = parse_key_event(key_str)
      session.send_event(
        sess,
        event.Key(event.KeyEvent(
          event_type: event.KeyReleased,
          window_id: "",
          key: key_name,
          modified_key: key_name,
          modifiers:,
          physical_key: option.None,
          location: event.Standard,
          text: option.None,
          repeat: False,
          captured: False,
        )),
      )
    },
    type_key: fn(sess, key_str) {
      let #(key_name, modifiers) = parse_key_event(key_str)
      let sess =
        session.send_event(
          sess,
          event.Key(event.KeyEvent(
            event_type: event.KeyPressed,
            window_id: "",
            key: key_name,
            modified_key: key_name,
            modifiers:,
            physical_key: option.None,
            location: event.Standard,
            text: option.None,
            repeat: False,
            captured: False,
          )),
        )
      session.send_event(
        sess,
        event.Key(event.KeyEvent(
          event_type: event.KeyReleased,
          window_id: "",
          key: key_name,
          modified_key: key_name,
          modifiers:,
          physical_key: option.None,
          location: event.Standard,
          text: option.None,
          repeat: False,
          captured: False,
        )),
      )
    },
    canvas_press: fn(sess, id, x, y) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.Widget(event.Press(
          target:,
          x:,
          y:,
          button: event.LeftButton,
          pointer: event.Mouse,
          finger: option.None,
          modifiers: event.modifiers_none(),
          captured: False,
        )),
      )
    },
    paste: fn(sess, id, text) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.Widget(event.Paste(target:, value: text)))
    },
    sort: fn(sess, id, column) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(sess, event.Widget(event.Sort(target:, value: column)))
    },
    canvas_touch_press: fn(sess, id, x, y, finger) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.Widget(event.Press(
          target:,
          x:,
          y:,
          button: event.LeftButton,
          pointer: event.Touch,
          finger: option.Some(finger),
          modifiers: event.modifiers_none(),
          captured: False,
        )),
      )
    },
    canvas_touch_release: fn(sess, id, x, y, finger) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.Widget(event.Release(
          target:,
          x:,
          y:,
          button: event.LeftButton,
          pointer: event.Touch,
          finger: option.Some(finger),
          modifiers: event.modifiers_none(),
          captured: False,
          lost: option.None,
        )),
      )
    },
    canvas_touch_move: fn(sess, id, x, y, finger) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.Widget(event.Move(
          target:,
          x:,
          y:,
          pointer: event.Touch,
          finger: option.Some(finger),
          modifiers: event.modifiers_none(),
          captured: False,
        )),
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
  let is_scoped = string.contains(target, "/") || string.contains(target, "#")
  let local_match = !is_scoped && local_id == target

  case tree.kind != "window" && { exact_match || local_match } {
    True -> {
      let et = event.make_target(tree.id, window_id)
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
  // Strip window# prefix first
  let path = case string.split_once(id, "#") {
    Ok(#(_, after)) -> after
    Error(_) -> id
  }
  case string.split(path, "/") {
    [] -> path
    segments ->
      case list.last(segments) {
        Ok(last) -> last
        Error(_) -> path
      }
  }
}

/// Parse a key string into a resolved key name and Modifiers.
fn parse_key_event(key_str: String) -> #(String, event.Modifiers) {
  let parsed = key.parse(key_str)
  let modifiers =
    event.Modifiers(
      shift: parsed.shift,
      ctrl: parsed.ctrl,
      alt: parsed.alt,
      logo: parsed.logo,
      command: parsed.command,
    )
  #(parsed.key, modifiers)
}
