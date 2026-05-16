//// Canvas-based vertical dimmer widget.
////
//// Renders a vertical bar that fills from the bottom up to the
//// configured `value` (0.0..1.0). Pressing anywhere on the bar emits
//// a `change` event with the new value derived from the press y
//// coordinate.
////
////     dimmer.widget("brightness", 0.5)
////
//// Events:
//// - `Widget(CustomWidget(kind: "change"))` with `data` = float in 0.0..1.0.
////
//// The widget is presentational: the brightness value lives in the
//// app's model and is read back through props on every render. The
//// widget itself carries no state.

import gleam/dict
import gleam/float
import gleam/option
import plushie/canvas/shape
import plushie/event.{type Event, LeftButton, Press, Widget}
import plushie/node.{type Node}
import plushie/prop/length
import plushie/widget.{
  type EventAction, type WidgetDef, Consumed, WidgetDef, emit_float,
}
import plushie/widget/canvas

pub const width: Float = 60.0

pub const height: Float = 200.0

pub type DimmerProps {
  DimmerProps(value: Float)
}

pub fn def() -> WidgetDef(Nil, DimmerProps) {
  WidgetDef(
    init: fn() { Nil },
    view: render,
    handle_event: handle_event,
    subscriptions: fn(_, _) { [] },
    cache_key: option.None,
  )
}

/// Build a dimmer widget placeholder bound to the given brightness
/// value (0.0..1.0).
pub fn widget(id: String, value: Float) -> Node {
  widget.build(def(), id, DimmerProps(value: clamp(value)))
}

fn handle_event(event: Event, state: Nil) -> #(EventAction, Nil) {
  case event {
    Widget(Press(y: y, button: LeftButton, ..)) -> {
      // Canvas-local y: 0 at top, `height` at bottom.
      let new_value = clamp(1.0 -. y /. height)
      #(emit_float("change", new_value), state)
    }
    _ -> #(Consumed, state)
  }
}

fn render(id: String, props: DimmerProps, _state: Nil) -> Node {
  let value = clamp(props.value)
  let fill_h = value *. height
  let fill_y = height -. fill_h

  canvas.new(id, length.Fixed(width), length.Fixed(height))
  |> canvas.on_press(True)
  |> canvas.alt("Brightness dimmer")
  |> canvas.layers(
    dict.from_list([
      #("bar", [
        shape.rect(0.0, 0.0, width, height, [shape.Fill("#1f2937")]),
        shape.rect(0.0, fill_y, width, fill_h, [shape.Fill("#fbbf24")]),
      ]),
    ]),
  )
  |> canvas.build()
}

fn clamp(v: Float) -> Float {
  float.max(0.0, float.min(1.0, v))
}
