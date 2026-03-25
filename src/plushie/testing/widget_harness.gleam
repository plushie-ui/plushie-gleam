//// Widget test harness for canvas_widget extensions.
////
//// Wraps a canvas_widget in a minimal host app for isolated testing.
//// The harness records semantic events emitted by the widget (filtering
//// out canvas framework noise) and exposes helpers for querying the
//// widget's emitted output.
////
//// ## Usage
////
//// ```gleam
//// import plushie/testing
//// import plushie/testing/widget_harness
////
//// pub fn clicking_star_emits_select_test() {
////   let app = widget_harness.harness("stars", star_rating_def(), StarProps(rating: 3, max: 5))
////   let ctx = testing.start(app)
////   let ctx = testing.canvas_press(ctx, "stars", 50.0, 10.0)
////   let events = widget_harness.events(testing.model(ctx))
////   // assert on events...
////   testing.stop(ctx)
//// }
//// ```
////
//// The harness model tracks all emitted events. Use `last_event` and
//// `events` to inspect what the widget produced.

import gleam/list
import plushie/app.{type App}
import plushie/canvas_widget.{type CanvasWidgetDef}
import plushie/command
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/ui
import plushie/widget/column
import plushie/widget/window

/// Model for the widget test harness. Tracks emitted events.
pub type HarnessModel {
  HarnessModel(
    /// All events received by the harness (newest first).
    events: List(Event),
  )
}

/// Get the most recent event captured by the harness.
pub fn last_event(model: HarnessModel) -> Result(Event, Nil) {
  case model.events {
    [ev, ..] -> Ok(ev)
    [] -> Error(Nil)
  }
}

/// Get all events captured by the harness (newest first).
pub fn events(model: HarnessModel) -> List(Event) {
  model.events
}

/// Check if any captured event matches the predicate.
pub fn has_event(model: HarnessModel, predicate: fn(Event) -> Bool) -> Bool {
  list.any(model.events, predicate)
}

/// Build a test harness app that hosts a canvas widget.
///
/// The harness wraps the widget in a minimal window layout and records
/// all non-framework events. Canvas lifecycle events (focus, blur,
/// element enter/leave) are filtered out as noise -- only semantic
/// events emitted by the widget's `handle_event` are captured.
pub fn harness(
  widget_id: String,
  def: CanvasWidgetDef(state, props),
  props: props,
) -> App(HarnessModel, Event) {
  let widget_node = canvas_widget.build(def, widget_id, props)
  app.simple(
    fn() { #(HarnessModel(events: []), command.none()) },
    harness_update,
    fn(_model) { harness_view(widget_node) },
  )
}

fn harness_update(
  model: HarnessModel,
  ev: Event,
) -> #(HarnessModel, command.Command(Event)) {
  case is_framework_event(ev) {
    True -> #(model, command.none())
    False -> #(HarnessModel(events: [ev, ..model.events]), command.none())
  }
}

fn harness_view(widget_node: Node) -> Node {
  ui.window("harness", [window.Title("Widget Test")], [
    ui.column("harness_col", [column.Spacing(0)], [widget_node]),
  ])
}

/// Canvas framework events that are internal lifecycle noise, not
/// semantic widget output. These are filtered from the harness.
fn is_framework_event(ev: Event) -> Bool {
  case ev {
    event.CanvasFocused(..) -> True
    event.CanvasBlurred(..) -> True
    event.CanvasElementFocused(..) -> True
    event.CanvasElementBlurred(..) -> True
    event.CanvasGroupFocused(..) -> True
    event.CanvasGroupBlurred(..) -> True
    event.CanvasElementEnter(..) -> True
    event.CanvasElementLeave(..) -> True
    _ -> False
  }
}
