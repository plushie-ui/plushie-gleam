//// Text editor widget builder (multi-line text editing).

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/prop/wrapping.{type Wrapping}
import toddy/widget/build

pub opaque type TextEditor {
  TextEditor(
    id: String,
    content: String,
    width: Option(Length),
    height: Option(Length),
    padding: Option(Padding),
    font: Option(Font),
    size: Option(Float),
    wrapping: Option(Wrapping),
    style: Option(String),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, content: String) -> TextEditor {
  TextEditor(
    id:,
    content:,
    width: None,
    height: None,
    padding: None,
    font: None,
    size: None,
    wrapping: None,
    style: None,
    a11y: None,
  )
}

pub fn width(te: TextEditor, w: Length) -> TextEditor {
  TextEditor(..te, width: option.Some(w))
}

pub fn height(te: TextEditor, h: Length) -> TextEditor {
  TextEditor(..te, height: option.Some(h))
}

pub fn padding(te: TextEditor, p: Padding) -> TextEditor {
  TextEditor(..te, padding: option.Some(p))
}

pub fn font(te: TextEditor, f: Font) -> TextEditor {
  TextEditor(..te, font: option.Some(f))
}

pub fn size(te: TextEditor, s: Float) -> TextEditor {
  TextEditor(..te, size: option.Some(s))
}

pub fn wrapping(te: TextEditor, w: Wrapping) -> TextEditor {
  TextEditor(..te, wrapping: option.Some(w))
}

pub fn style(te: TextEditor, s: String) -> TextEditor {
  TextEditor(..te, style: option.Some(s))
}

pub fn a11y(te: TextEditor, a: A11y) -> TextEditor {
  TextEditor(..te, a11y: option.Some(a))
}

pub fn build(te: TextEditor) -> Node {
  let props =
    dict.new()
    |> build.put_string("content", te.content)
    |> build.put_optional("width", te.width, length.to_prop_value)
    |> build.put_optional("height", te.height, length.to_prop_value)
    |> build.put_optional("padding", te.padding, padding.to_prop_value)
    |> build.put_optional("font", te.font, font.to_prop_value)
    |> build.put_optional_float("size", te.size)
    |> build.put_optional("wrapping", te.wrapping, wrapping.to_prop_value)
    |> build.put_optional_string("style", te.style)
    |> build.put_optional("a11y", te.a11y, a11y.to_prop_value)
  Node(id: te.id, kind: "text_editor", props:, children: [])
}
