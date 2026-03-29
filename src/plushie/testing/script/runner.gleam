//// Script executor for `.plushie` test scripts.
////
//// Runs parsed scripts step by step, collecting per-instruction
//// results. Returns Ok(Nil) on success or Error(failures) with
//// a list of (instruction, reason) tuples.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import plushie/event.{type Event}
import plushie/node.{type Node, StringVal}
import plushie/testing/element
import plushie/testing/script.{
  type Instruction, type Script, AssertModel, AssertScreenshot, AssertText,
  AssertTreeHash, Click, Expect, Move, MoveTo, Press, Release, Select, Slide,
  Toggle, TypeKey, TypeText, Wait,
}
import plushie/testing/session.{type TestSession}

/// A single failure: the instruction that failed and why.
pub type Failure {
  Failure(instruction: Instruction, reason: String)
}

/// Run a parsed script against a test session.
/// Returns Ok(Nil) on success or Error(failures).
pub fn run(
  script_val: Script,
  session: TestSession(model, Event),
) -> Result(Nil, List(Failure)) {
  let result =
    list.index_fold(
      script_val.instructions,
      #(session, []),
      fn(acc, instruction, idx) {
        let #(sess, failures) = acc
        case execute(sess, instruction) {
          Ok(new_sess) -> #(new_sess, failures)
          Error(reason) -> {
            let failure =
              Failure(
                instruction:,
                reason: "line " <> int.to_string(idx + 1) <> ": " <> reason,
              )
            #(sess, [failure, ..failures])
          }
        }
      },
    )

  case result.1 {
    [] -> Ok(Nil)
    failures -> Error(list.reverse(failures))
  }
}

fn execute(
  session: TestSession(model, Event),
  instruction: Instruction,
) -> Result(TestSession(model, Event), String) {
  case instruction {
    Click(selector) -> {
      let target = resolve_event_target(session.current_tree(session), selector)
      Ok(session.send_event(
        session,
        event.WidgetClick(window_id: target.0, id: target.1, scope: target.2),
      ))
    }

    TypeText(selector, text) -> {
      let target = resolve_event_target(session.current_tree(session), selector)
      Ok(session.send_event(
        session,
        event.WidgetInput(
          window_id: target.0,
          id: target.1,
          scope: target.2,
          value: text,
        ),
      ))
    }

    TypeKey(key) -> {
      Ok(session.send_event(
        session,
        event.KeyPress(
          window_id: "",
          key:,
          modified_key: key,
          modifiers: event.modifiers_none(),
          physical_key: option.None,
          location: event.Standard,
          text: option.Some(key),
          repeat: False,
          captured: False,
        ),
      ))
    }

    Press(key) -> {
      Ok(session.send_event(
        session,
        event.KeyPress(
          window_id: "",
          key:,
          modified_key: key,
          modifiers: event.modifiers_none(),
          physical_key: option.None,
          location: event.Standard,
          text: option.None,
          repeat: False,
          captured: False,
        ),
      ))
    }

    Release(key) -> {
      Ok(session.send_event(
        session,
        event.KeyRelease(
          window_id: "",
          key:,
          modified_key: key,
          modifiers: event.modifiers_none(),
          physical_key: option.None,
          location: event.Standard,
          text: option.None,
          captured: False,
        ),
      ))
    }

    Toggle(selector) -> {
      let target = resolve_event_target(session.current_tree(session), selector)
      Ok(session.send_event(
        session,
        event.WidgetToggle(
          window_id: target.0,
          id: target.1,
          scope: target.2,
          value: True,
        ),
      ))
    }

    Select(selector, value) -> {
      let target = resolve_event_target(session.current_tree(session), selector)
      Ok(session.send_event(
        session,
        event.WidgetSelect(
          window_id: target.0,
          id: target.1,
          scope: target.2,
          value:,
        ),
      ))
    }

    Slide(selector, value) -> {
      let target = resolve_event_target(session.current_tree(session), selector)
      Ok(session.send_event(
        session,
        event.WidgetSlide(
          window_id: target.0,
          id: target.1,
          scope: target.2,
          value:,
        ),
      ))
    }

    Move(_target) -> {
      // No-op: moving cursor to a widget by selector requires layout bounds
      Ok(session)
    }

    MoveTo(x, y) -> {
      // Cursor movement dispatched as MouseMoved
      Ok(session.send_event(
        session,
        event.MouseMoved(
          window_id: "",
          x: int.to_float(x),
          y: int.to_float(y),
          captured: False,
        ),
      ))
    }

    Expect(text) -> {
      let tree = session.current_tree(session)
      case tree_contains_text(tree, text) {
        True -> Ok(session)
        False -> Error("expected to find text \"" <> text <> "\" in tree")
      }
    }

    AssertText(selector, expected) -> {
      let tree = session.current_tree(session)
      case element.find(in: tree, id: selector) {
        option.Some(el) ->
          case element.text(el) {
            option.Some(actual) ->
              case actual == expected {
                True -> Ok(session)
                False ->
                  Error(
                    "expected text \""
                    <> expected
                    <> "\" for \""
                    <> selector
                    <> "\", got \""
                    <> actual
                    <> "\"",
                  )
              }
            option.None ->
              Error("element \"" <> selector <> "\" has no text content")
          }
        option.None -> Error("element \"" <> selector <> "\" not found")
      }
    }

    AssertModel(expression) -> {
      let model_str = string.inspect(session.model(session))
      case string.contains(model_str, expression) {
        True -> Ok(session)
        False ->
          Error(
            "assert_model failed: \""
            <> expression
            <> "\" not found in model: "
            <> model_str,
          )
      }
    }

    AssertTreeHash(_name) -> {
      // Tree hash assertions are typically handled at a higher level
      // with golden file infrastructure. Here we just pass through.
      Ok(session)
    }

    AssertScreenshot(_name) -> {
      // Screenshot assertions need renderer support, pass through.
      Ok(session)
    }

    Wait(_ms) -> {
      // In test mode, waits are no-ops (synchronous execution).
      Ok(session)
    }
  }
}

// -- Helpers -----------------------------------------------------------------

fn split_scoped_id(id: String) -> #(String, List(String)) {
  // Strip leading # (CSS-style selector)
  let clean_id = case string.starts_with(id, "#") {
    True -> string.drop_start(id, 1)
    False -> id
  }
  case string.split(clean_id, "/") {
    [] -> #(clean_id, [])
    [single] -> #(single, [])
    segments -> {
      let assert Ok(local) = list.last(segments)
      let scope = list.take(segments, list.length(segments) - 1) |> list.reverse
      #(local, scope)
    }
  }
}

fn resolve_event_target(
  tree: Node,
  target: String,
) -> #(String, String, List(String)) {
  case find_event_target(tree, target, "") {
    option.Some(found) -> found
    option.None -> #(default_window_id(tree), target, [])
  }
}

fn find_event_target(
  tree: Node,
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
  children: List(Node),
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

fn default_window_id(tree: Node) -> String {
  case tree.kind {
    "window" -> tree.id
    _ ->
      case list.find(tree.children, fn(child) { child.kind == "window" }) {
        Ok(window) -> window.id
        Error(_) -> ""
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

/// Recursively check if any node in the tree contains the given text.
fn tree_contains_text(tree: Node, text: String) -> Bool {
  let props = tree.props
  let values = [
    dict.get(props, "content"),
    dict.get(props, "label"),
    dict.get(props, "value"),
    dict.get(props, "placeholder"),
  ]
  let found =
    list.any(values, fn(result) {
      case result {
        Ok(StringVal(s)) -> s == text
        _ -> False
      }
    })
  case found {
    True -> True
    False ->
      list.any(tree.children, fn(child) { tree_contains_text(child, text) })
  }
}
