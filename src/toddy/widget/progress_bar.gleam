//// ProgressBar widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, DictVal, FloatVal, Node}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type ProgressBar {
  ProgressBar(
    id: String,
    range: #(Float, Float),
    value: Float,
    width: Option(Length),
    height: Option(Float),
    style: Option(String),
  )
}

pub fn new(id: String, range: #(Float, Float), value: Float) -> ProgressBar {
  ProgressBar(id:, range:, value:, width: None, height: None, style: None)
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

fn range_to_prop_value(range: #(Float, Float)) -> node.PropValue {
  DictVal(
    dict.from_list([
      #("min", FloatVal(range.0)),
      #("max", FloatVal(range.1)),
    ]),
  )
}

pub fn build(pb: ProgressBar) -> Node {
  let props =
    dict.new()
    |> dict.insert("range", range_to_prop_value(pb.range))
    |> dict.insert("value", FloatVal(pb.value))
    |> build.put_optional("width", pb.width, length.to_prop_value)
    |> build.put_optional_float("height", pb.height)
    |> build.put_optional_string("style", pb.style)
  Node(id: pb.id, kind: "progress_bar", props:, children: [])
}
