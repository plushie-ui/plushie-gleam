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
      session.send_event(
        sess,
        event.WidgetClick(window_id: target.0, id: target.1, scope: target.2),
      )
    },
    type_text: fn(sess, id, text) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.WidgetInput(
          window_id: target.0,
          id: target.1,
          value: text,
          scope: target.2,
        ),
      )
    },
    submit: fn(sess, id) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.WidgetSubmit(
          window_id: target.0,
          id: target.1,
          scope: target.2,
          value: "",
        ),
      )
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
      session.send_event(
        sess,
        event.WidgetToggle(
          window_id: target.0,
          id: target.1,
          value:,
          scope: target.2,
        ),
      )
    },
    select: fn(sess, id, value) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.WidgetSelect(
          window_id: target.0,
          id: target.1,
          scope: target.2,
          value:,
        ),
      )
    },
    slide: fn(sess, id, value) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.WidgetSlide(
          window_id: target.0,
          id: target.1,
          value:,
          scope: target.2,
        ),
      )
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
          location: event.Standard,
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
          location: event.Standard,
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
            location: event.Standard,
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
          location: event.Standard,
          text: option.None,
          captured: False,
        ),
      )
    },
    canvas_press: fn(sess, id, x, y) {
      let target = resolve_event_target(session.current_tree(sess), id)
      session.send_event(
        sess,
        event.CanvasPress(
          window_id: target.0,
          id: target.1,
          scope: target.2,
          x:,
          y:,
          button: "left",
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

fn resolve_event_target(
  tree: node.Node,
  target: String,
) -> #(String, String, List(String)) {
  case find_event_target(tree, target, "") {
    option.Some(found) -> found
    option.None -> #(default_window_id(tree), target, [])
  }
}

fn find_event_target(
  tree: node.Node,
  target: String,
  current_window: String,
) -> option.Option(#(String, String, List(String))) {
  let window_id = case tree.kind {
    "window" -> tree.id
    _ -> current_window
  }

  let local_id = last_segment(tree.id)
  let exact_match = tree.id == target
  let local_match = !string.contains(target, "/") && local_id == target

  case tree.kind != "window" && { exact_match || local_match } {
    True -> {
      let #(id, scope) = split_scoped_id(tree.id)
      option.Some(#(window_id, id, scope))
    }
    False -> find_event_target_in_children(tree.children, target, window_id)
  }
}

fn find_event_target_in_children(
  children: List(node.Node),
  target: String,
  current_window: String,
) -> option.Option(#(String, String, List(String))) {
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

fn default_window_id(tree: node.Node) -> String {
  case tree.kind {
    "window" -> tree.id
    _ ->
      case list.find(tree.children, fn(child) { child.kind == "window" }) {
        Ok(window) -> window.id
        Error(_) -> ""
      }
  }
}

fn split_scoped_id(id: String) -> #(String, List(String)) {
  case string.split(id, "/") {
    [] -> #(id, [])
    [single] -> #(single, [])
    segments -> {
      let assert Ok(local) = list.last(segments)
      let scope = list.take(segments, list.length(segments) - 1) |> list.reverse
      #(local, scope)
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
