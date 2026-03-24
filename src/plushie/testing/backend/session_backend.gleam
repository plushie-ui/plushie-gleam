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

import gleam/option.{None}
import plushie/event
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
      session.send_event(sess, event.WidgetClick(id:, scope: []))
    },
    type_text: fn(sess, id, text) {
      session.send_event(sess, event.WidgetInput(id:, value: text, scope: []))
    },
    submit: fn(sess, id) {
      session.send_event(sess, event.WidgetSubmit(id:, scope: [], value: ""))
    },
    toggle: fn(sess, id) {
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
        None -> True
      }
      session.send_event(sess, event.WidgetToggle(id:, value:, scope: []))
    },
    select: fn(sess, id, value) {
      session.send_event(sess, event.WidgetSelect(id:, scope: [], value:))
    },
    slide: fn(sess, id, value) {
      session.send_event(sess, event.WidgetSlide(id:, value:, scope: []))
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
