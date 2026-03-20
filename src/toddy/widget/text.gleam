//// Text widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/alignment.{type Alignment}
import toddy/prop/color.{type Color}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
import toddy/prop/shaping.{type Shaping}
import toddy/prop/wrapping.{type Wrapping}
import toddy/widget/build

pub opaque type Text {
  Text(
    id: String,
    content: String,
    size: Option(Float),
    color: Option(Color),
    font: Option(Font),
    width: Option(Length),
    height: Option(Length),
    align_x: Option(Alignment),
    align_y: Option(Alignment),
    wrapping: Option(Wrapping),
    shaping: Option(Shaping),
  )
}

pub fn new(id: String, content: String) -> Text {
  Text(
    id:,
    content:,
    size: None,
    color: None,
    font: None,
    width: None,
    height: None,
    align_x: None,
    align_y: None,
    wrapping: None,
    shaping: None,
  )
}

pub fn size(text: Text, s: Float) -> Text {
  Text(..text, size: option.Some(s))
}

pub fn color(text: Text, c: Color) -> Text {
  Text(..text, color: option.Some(c))
}

pub fn font(text: Text, f: Font) -> Text {
  Text(..text, font: option.Some(f))
}

pub fn width(text: Text, w: Length) -> Text {
  Text(..text, width: option.Some(w))
}

pub fn height(text: Text, h: Length) -> Text {
  Text(..text, height: option.Some(h))
}

pub fn align_x(text: Text, a: Alignment) -> Text {
  Text(..text, align_x: option.Some(a))
}

pub fn align_y(text: Text, a: Alignment) -> Text {
  Text(..text, align_y: option.Some(a))
}

pub fn wrapping(text: Text, w: Wrapping) -> Text {
  Text(..text, wrapping: option.Some(w))
}

pub fn shaping(text: Text, s: Shaping) -> Text {
  Text(..text, shaping: option.Some(s))
}

pub fn build(text: Text) -> Node {
  let props =
    dict.new()
    |> build.put_string("content", text.content)
    |> build.put_optional_float("size", text.size)
    |> build.put_optional("color", text.color, color.to_prop_value)
    |> build.put_optional("font", text.font, font.to_prop_value)
    |> build.put_optional("width", text.width, length.to_prop_value)
    |> build.put_optional("height", text.height, length.to_prop_value)
    |> build.put_optional("align_x", text.align_x, alignment.to_prop_value)
    |> build.put_optional("align_y", text.align_y, alignment.to_prop_value)
    |> build.put_optional("wrapping", text.wrapping, wrapping.to_prop_value)
    |> build.put_optional("shaping", text.shaping, shaping.to_prop_value)
  Node(id: text.id, kind: "text", props:, children: [])
}
