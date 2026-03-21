//// Vertical slider widget builder (numeric range selection, vertical axis).

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, FloatVal, ListVal, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/length.{type Length}
import toddy/widget/build

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
    style: Option(String),
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
    style: None,
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

pub fn style(vs: VerticalSlider, s: String) -> VerticalSlider {
  VerticalSlider(..vs, style: option.Some(s))
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
    |> build.put_optional_string("style", vs.style)
    |> build.put_optional("a11y", vs.a11y, a11y.to_prop_value)
  Node(id: vs.id, kind: "vertical_slider", props:, children: [])
}
