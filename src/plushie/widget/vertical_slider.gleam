//// Vertical slider widget builder (numeric range selection, vertical axis).

import gleam/dict
import gleam/option.{type Option, None}
import plushie/node.{type Node, FloatVal, ListVal, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/color.{type Color}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type VerticalSlider {
  VerticalSlider(
    id: String,
    range: #(Float, Float),
    value: Float,
    step: Option(Float),
    shift_step: Option(Float),
    default_value: Option(Float),
    width: Option(Length),
    height: Option(Float),
    rail_color: Option(Color),
    rail_width: Option(Float),
    style: Option(String),
    label: Option(String),
    event_rate: Option(Int),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, range: #(Float, Float), value: Float) -> VerticalSlider {
  VerticalSlider(
    id:,
    range:,
    value:,
    step: None,
    shift_step: None,
    default_value: None,
    width: None,
    height: None,
    rail_color: None,
    rail_width: None,
    style: None,
    label: None,
    event_rate: None,
    a11y: None,
  )
}

pub fn step(vs: VerticalSlider, s: Float) -> VerticalSlider {
  VerticalSlider(..vs, step: option.Some(s))
}

pub fn shift_step(vs: VerticalSlider, s: Float) -> VerticalSlider {
  VerticalSlider(..vs, shift_step: option.Some(s))
}

pub fn default_value(vs: VerticalSlider, v: Float) -> VerticalSlider {
  VerticalSlider(..vs, default_value: option.Some(v))
}

pub fn width(vs: VerticalSlider, w: Length) -> VerticalSlider {
  VerticalSlider(..vs, width: option.Some(w))
}

pub fn height(vs: VerticalSlider, h: Float) -> VerticalSlider {
  VerticalSlider(..vs, height: option.Some(h))
}

pub fn rail_color(vs: VerticalSlider, c: Color) -> VerticalSlider {
  VerticalSlider(..vs, rail_color: option.Some(c))
}

pub fn rail_width(vs: VerticalSlider, w: Float) -> VerticalSlider {
  VerticalSlider(..vs, rail_width: option.Some(w))
}

pub fn style(vs: VerticalSlider, s: String) -> VerticalSlider {
  VerticalSlider(..vs, style: option.Some(s))
}

pub fn label(vs: VerticalSlider, l: String) -> VerticalSlider {
  VerticalSlider(..vs, label: option.Some(l))
}

pub fn event_rate(vs: VerticalSlider, rate: Int) -> VerticalSlider {
  VerticalSlider(..vs, event_rate: option.Some(rate))
}

fn range_to_prop_value(range: #(Float, Float)) -> node.PropValue {
  ListVal([FloatVal(range.0), FloatVal(range.1)])
}

pub fn a11y(vs: VerticalSlider, a: A11y) -> VerticalSlider {
  VerticalSlider(..vs, a11y: option.Some(a))
}

pub fn build(vs: VerticalSlider) -> Node {
  let props =
    dict.new()
    |> dict.insert("range", range_to_prop_value(vs.range))
    |> dict.insert("value", FloatVal(vs.value))
    |> build.put_optional_float("step", vs.step)
    |> build.put_optional_float("shift_step", vs.shift_step)
    |> build.put_optional_float("default", vs.default_value)
    |> build.put_optional("width", vs.width, length.to_prop_value)
    |> build.put_optional_float("height", vs.height)
    |> build.put_optional("rail_color", vs.rail_color, color.to_prop_value)
    |> build.put_optional_float("rail_width", vs.rail_width)
    |> build.put_optional_string("style", vs.style)
    |> build.put_optional_string("label", vs.label)
    |> build.put_optional_int("event_rate", vs.event_rate)
    |> build.put_optional("a11y", vs.a11y, a11y.to_prop_value)
  Node(id: vs.id, kind: "vertical_slider", props:, children: [])
}
