//// Slider widget builder (numeric range selection).

import gleam/dict
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

pub fn step(slider: Slider, s: Float) -> Slider {
  Slider(..slider, step: option.Some(s))
}

pub fn shift_step(slider: Slider, s: Float) -> Slider {
  Slider(..slider, shift_step: option.Some(s))
}

pub fn default_value(slider: Slider, v: Float) -> Slider {
  Slider(..slider, default_value: option.Some(v))
}

pub fn width(slider: Slider, w: Length) -> Slider {
  Slider(..slider, width: option.Some(w))
}

pub fn height(slider: Slider, h: Float) -> Slider {
  Slider(..slider, height: option.Some(h))
}

pub fn circular_handle(slider: Slider, enabled: Bool) -> Slider {
  Slider(..slider, circular_handle: option.Some(enabled))
}

pub fn rail_color(slider: Slider, c: Color) -> Slider {
  Slider(..slider, rail_color: option.Some(c))
}

pub fn rail_width(slider: Slider, w: Float) -> Slider {
  Slider(..slider, rail_width: option.Some(w))
}

pub fn style(slider: Slider, s: String) -> Slider {
  Slider(..slider, style: option.Some(s))
}

pub fn label(slider: Slider, l: String) -> Slider {
  Slider(..slider, label: option.Some(l))
}

pub fn event_rate(slider: Slider, rate: Int) -> Slider {
  Slider(..slider, event_rate: option.Some(rate))
}

fn range_to_prop_value(range: #(Float, Float)) -> node.PropValue {
  ListVal([FloatVal(range.0), FloatVal(range.1)])
}

pub fn a11y(slider: Slider, a: A11y) -> Slider {
  Slider(..slider, a11y: option.Some(a))
}

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
  Node(id: slider.id, kind: "slider", props:, children: [])
}
