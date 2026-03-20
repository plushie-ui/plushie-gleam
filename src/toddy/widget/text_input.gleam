//// TextInput widget builder (single-line text entry).

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/alignment.{type Alignment}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/widget/build

pub opaque type TextInput {
  TextInput(
    id: String,
    value: String,
    placeholder: Option(String),
    padding: Option(Padding),
    width: Option(Length),
    size: Option(Float),
    font: Option(Font),
    line_height: Option(Float),
    align_x: Option(Alignment),
    on_submit: Option(Bool),
    on_paste: Option(Bool),
    secure: Option(Bool),
    style: Option(String),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, value: String) -> TextInput {
  TextInput(
    id:,
    value:,
    placeholder: None,
    padding: None,
    width: None,
    size: None,
    font: None,
    line_height: None,
    align_x: None,
    on_submit: None,
    on_paste: None,
    secure: None,
    style: None,
    a11y: None,
  )
}

pub fn placeholder(input: TextInput, p: String) -> TextInput {
  TextInput(..input, placeholder: option.Some(p))
}

pub fn padding(input: TextInput, p: Padding) -> TextInput {
  TextInput(..input, padding: option.Some(p))
}

pub fn width(input: TextInput, w: Length) -> TextInput {
  TextInput(..input, width: option.Some(w))
}

pub fn size(input: TextInput, s: Float) -> TextInput {
  TextInput(..input, size: option.Some(s))
}

pub fn font(input: TextInput, f: Font) -> TextInput {
  TextInput(..input, font: option.Some(f))
}

pub fn line_height(input: TextInput, h: Float) -> TextInput {
  TextInput(..input, line_height: option.Some(h))
}

pub fn align_x(input: TextInput, a: Alignment) -> TextInput {
  TextInput(..input, align_x: option.Some(a))
}

pub fn on_submit(input: TextInput, enabled: Bool) -> TextInput {
  TextInput(..input, on_submit: option.Some(enabled))
}

pub fn on_paste(input: TextInput, enabled: Bool) -> TextInput {
  TextInput(..input, on_paste: option.Some(enabled))
}

pub fn secure(input: TextInput, s: Bool) -> TextInput {
  TextInput(..input, secure: option.Some(s))
}

pub fn style(input: TextInput, s: String) -> TextInput {
  TextInput(..input, style: option.Some(s))
}

pub fn a11y(input: TextInput, a: A11y) -> TextInput {
  TextInput(..input, a11y: option.Some(a))
}

pub fn build(input: TextInput) -> Node {
  let props =
    dict.new()
    |> build.put_string("value", input.value)
    |> build.put_optional_string("placeholder", input.placeholder)
    |> build.put_optional("padding", input.padding, padding.to_prop_value)
    |> build.put_optional("width", input.width, length.to_prop_value)
    |> build.put_optional_float("size", input.size)
    |> build.put_optional("font", input.font, font.to_prop_value)
    |> build.put_optional_float("line_height", input.line_height)
    |> build.put_optional("align_x", input.align_x, alignment.to_prop_value)
    |> build.put_optional_bool("on_submit", input.on_submit)
    |> build.put_optional_bool("on_paste", input.on_paste)
    |> build.put_optional_bool("secure", input.secure)
    |> build.put_optional_string("style", input.style)
    |> build.put_optional("a11y", input.a11y, a11y.to_prop_value)
  Node(id: input.id, kind: "text_input", props:, children: [])
}
