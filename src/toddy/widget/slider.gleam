//// Slider widget builder (numeric range selection).

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, FloatVal, ListVal, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/length.{type Length}
import toddy/widget/build

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
    style: Option(String),
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
    style: None,
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

pub fn style(slider: Slider, s: String) -> Slider {
  Slider(..slider, style: option.Some(s))
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
    |> build.put_optional_string("style", slider.style)
    |> build.put_optional("a11y", slider.a11y, a11y.to_prop_value)
  Node(id: slider.id, kind: "slider", props:, children: [])
}
