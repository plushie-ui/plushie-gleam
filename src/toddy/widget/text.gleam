//// Text widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node, StringVal}
import toddy/prop/a11y.{type A11y}
import toddy/prop/alignment.{type Alignment}
import toddy/prop/color.{type Color}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
import toddy/prop/shaping.{type Shaping}
import toddy/prop/wrapping.{type Wrapping}
import toddy/widget/build

pub type TextStyle {
  DefaultStyle
  PrimaryStyle
  SecondaryStyle
  SuccessStyle
  DangerStyle
  WarningStyle
}

pub opaque type Text {
  Text(
    id: String,
    content: String,
    size: Option(Float),
    color: Option(Color),
    font: Option(Font),
    width: Option(Length),
    height: Option(Length),
    line_height: Option(Float),
    align_x: Option(Alignment),
    align_y: Option(Alignment),
    wrapping: Option(Wrapping),
    ellipsis: Option(String),
    shaping: Option(Shaping),
    style: Option(TextStyle),
    a11y: Option(A11y),
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
    line_height: None,
    align_x: None,
    align_y: None,
    wrapping: None,
    ellipsis: None,
    shaping: None,
    style: None,
    a11y: None,
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

pub fn line_height(text: Text, h: Float) -> Text {
  Text(..text, line_height: option.Some(h))
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

pub fn ellipsis(text: Text, e: String) -> Text {
  Text(..text, ellipsis: option.Some(e))
}

pub fn shaping(text: Text, s: Shaping) -> Text {
  Text(..text, shaping: option.Some(s))
}

pub fn style(text: Text, s: TextStyle) -> Text {
  Text(..text, style: option.Some(s))
}

pub fn a11y(text: Text, a: A11y) -> Text {
  Text(..text, a11y: option.Some(a))
}

fn style_to_string(s: TextStyle) -> String {
  case s {
    DefaultStyle -> "default"
    PrimaryStyle -> "primary"
    SecondaryStyle -> "secondary"
    SuccessStyle -> "success"
    DangerStyle -> "danger"
    WarningStyle -> "warning"
  }
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
    |> build.put_optional_float("line_height", text.line_height)
    |> build.put_optional("align_x", text.align_x, alignment.to_prop_value)
    |> build.put_optional("align_y", text.align_y, alignment.to_prop_value)
    |> build.put_optional("wrapping", text.wrapping, wrapping.to_prop_value)
    |> build.put_optional_string("ellipsis", text.ellipsis)
    |> build.put_optional("shaping", text.shaping, shaping.to_prop_value)
    |> build.put_optional("style", text.style, fn(s) {
      StringVal(style_to_string(s))
    })
    |> build.put_optional("a11y", text.a11y, a11y.to_prop_value)
  Node(id: text.id, kind: "text", props:, children: [])
}
