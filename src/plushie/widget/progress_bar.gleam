//// ProgressBar widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import plushie/node.{type Node, FloatVal, ListVal, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type ProgressBar {
  ProgressBar(
    id: String,
    range: #(Float, Float),
    value: Float,
    width: Option(Length),
    height: Option(Float),
    style: Option(String),
    vertical: Option(Bool),
    label: Option(String),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, range: #(Float, Float), value: Float) -> ProgressBar {
  ProgressBar(
    id:,
    range:,
    value:,
    width: None,
    height: None,
    style: None,
    vertical: None,
    label: None,
    a11y: None,
  )
}

pub fn width(pb: ProgressBar, w: Length) -> ProgressBar {
  ProgressBar(..pb, width: option.Some(w))
}

pub fn height(pb: ProgressBar, h: Float) -> ProgressBar {
  ProgressBar(..pb, height: option.Some(h))
}

pub fn style(pb: ProgressBar, s: String) -> ProgressBar {
  ProgressBar(..pb, style: option.Some(s))
}

pub fn vertical(pb: ProgressBar, v: Bool) -> ProgressBar {
  ProgressBar(..pb, vertical: option.Some(v))
}

pub fn label(pb: ProgressBar, l: String) -> ProgressBar {
  ProgressBar(..pb, label: option.Some(l))
}

fn range_to_prop_value(range: #(Float, Float)) -> node.PropValue {
  ListVal([FloatVal(range.0), FloatVal(range.1)])
}

pub fn a11y(pb: ProgressBar, a: A11y) -> ProgressBar {
  ProgressBar(..pb, a11y: option.Some(a))
}

pub fn build(pb: ProgressBar) -> Node {
  let props =
    dict.new()
    |> dict.insert("range", range_to_prop_value(pb.range))
    |> dict.insert("value", FloatVal(pb.value))
    |> build.put_optional("width", pb.width, length.to_prop_value)
    |> build.put_optional_float("height", pb.height)
    |> build.put_optional_string("style", pb.style)
    |> build.put_optional_bool("vertical", pb.vertical)
    |> build.put_optional_string("label", pb.label)
    |> build.put_optional("a11y", pb.a11y, a11y.to_prop_value)
  Node(id: pb.id, kind: "progress_bar", props:, children: [])
}
