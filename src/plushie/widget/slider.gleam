//// Slider widget builder (numeric range selection).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, FloatVal, ListVal, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/color.{type Color}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type Slider {
  Slider(
    id: String,
    range: #(Float, Float),
    value: Float,
    step: Option(Float),
    shift_step: Option(Float),
    default_value: Option(Float),
    width: Option(Length),
    height: Option(Float),
    circular_handle: Option(Bool),
    rail_color: Option(Color),
    rail_width: Option(Float),
    style: Option(String),
    label: Option(String),
    event_rate: Option(Int),
    a11y: Option(A11y),
  )
}

/// Create a new slider builder.
pub fn new(id: String, range: #(Float, Float), value: Float) -> Slider {
  Slider(
    id:,
    range:,
    value:,
    step: None,
    shift_step: None,
    default_value: None,
    width: None,
    height: None,
    circular_handle: None,
    rail_color: None,
    rail_width: None,
    style: None,
    label: None,
    event_rate: None,
    a11y: None,
  )
}

/// Set the step increment.
pub fn step(slider: Slider, s: Float) -> Slider {
  Slider(..slider, step: option.Some(s))
}

/// Set the step increment when shift is held.
pub fn shift_step(slider: Slider, s: Float) -> Slider {
  Slider(..slider, shift_step: option.Some(s))
}

/// Set the default value (double-click to reset).
pub fn default_value(slider: Slider, v: Float) -> Slider {
  Slider(..slider, default_value: option.Some(v))
}

/// Set the width.
pub fn width(slider: Slider, w: Length) -> Slider {
  Slider(..slider, width: option.Some(w))
}

/// Set the height.
pub fn height(slider: Slider, h: Float) -> Slider {
  Slider(..slider, height: option.Some(h))
}

/// Set whether the handle is circular.
pub fn circular_handle(slider: Slider, enabled: Bool) -> Slider {
  Slider(..slider, circular_handle: option.Some(enabled))
}

/// Set the rail color.
pub fn rail_color(slider: Slider, c: Color) -> Slider {
  Slider(..slider, rail_color: option.Some(c))
}

/// Set the rail width.
pub fn rail_width(slider: Slider, w: Float) -> Slider {
  Slider(..slider, rail_width: option.Some(w))
}

/// Set the style.
pub fn style(slider: Slider, s: String) -> Slider {
  Slider(..slider, style: option.Some(s))
}

/// Set the label text.
pub fn label(slider: Slider, l: String) -> Slider {
  Slider(..slider, label: option.Some(l))
}

/// Set the event throttle rate in milliseconds.
pub fn event_rate(slider: Slider, rate: Int) -> Slider {
  Slider(..slider, event_rate: option.Some(rate))
}

fn range_to_prop_value(range: #(Float, Float)) -> node.PropValue {
  ListVal([FloatVal(range.0), FloatVal(range.1)])
}

/// Set accessibility properties for this widget.
pub fn a11y(slider: Slider, a: A11y) -> Slider {
  Slider(..slider, a11y: option.Some(a))
}

/// Option type for slider properties.
pub type Opt {
  Step(Float)
  ShiftStep(Float)
  DefaultValue(Float)
  Width(Length)
  Height(Float)
  CircularHandle(Bool)
  RailColor(Color)
  RailWidth(Float)
  Style(String)
  Label(String)
  EventRate(Int)
  A11y(A11y)
}

/// Apply a list of options to a slider builder.
pub fn with_opts(slider: Slider, opts: List(Opt)) -> Slider {
  list.fold(opts, slider, fn(s, opt) {
    case opt {
      Step(v) -> step(s, v)
      ShiftStep(v) -> shift_step(s, v)
      DefaultValue(v) -> default_value(s, v)
      Width(w) -> width(s, w)
      Height(h) -> height(s, h)
      CircularHandle(v) -> circular_handle(s, v)
      RailColor(c) -> rail_color(s, c)
      RailWidth(w) -> rail_width(s, w)
      Style(v) -> style(s, v)
      Label(l) -> label(s, l)
      EventRate(r) -> event_rate(s, r)
      A11y(a) -> a11y(s, a)
    }
  })
}

/// Build the slider into a renderable Node.
pub fn build(slider: Slider) -> Node {
  let props =
    dict.new()
    |> dict.insert("range", range_to_prop_value(slider.range))
    |> dict.insert("value", FloatVal(slider.value))
    |> build.put_optional_float("step", slider.step)
    |> build.put_optional_float("shift_step", slider.shift_step)
    |> build.put_optional_float("default", slider.default_value)
    |> build.put_optional("width", slider.width, length.to_prop_value)
    |> build.put_optional_float("height", slider.height)
    |> build.put_optional_bool("circular_handle", slider.circular_handle)
    |> build.put_optional("rail_color", slider.rail_color, color.to_prop_value)
    |> build.put_optional_float("rail_width", slider.rail_width)
    |> build.put_optional_string("style", slider.style)
    |> build.put_optional_string("label", slider.label)
    |> build.put_optional_int("event_rate", slider.event_rate)
    |> build.put_optional("a11y", slider.a11y, a11y.to_prop_value)
  Node(id: slider.id, kind: "slider", props:, children: [], meta: dict.new())
}
