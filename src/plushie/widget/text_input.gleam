//// TextInput widget builder (single-line text entry).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/alignment.{type Alignment}
import plushie/prop/font.{type Font}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/widget/build

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

/// Create a new text input builder.
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

/// Set the placeholder text.
pub fn placeholder(input: TextInput, p: String) -> TextInput {
  TextInput(..input, placeholder: option.Some(p))
}

/// Set the padding.
pub fn padding(input: TextInput, p: Padding) -> TextInput {
  TextInput(..input, padding: option.Some(p))
}

/// Set the width.
pub fn width(input: TextInput, w: Length) -> TextInput {
  TextInput(..input, width: option.Some(w))
}

/// Set the size.
pub fn size(input: TextInput, s: Float) -> TextInput {
  TextInput(..input, size: option.Some(s))
}

/// Set the font.
pub fn font(input: TextInput, f: Font) -> TextInput {
  TextInput(..input, font: option.Some(f))
}

/// Set the line height.
pub fn line_height(input: TextInput, h: Float) -> TextInput {
  TextInput(..input, line_height: option.Some(h))
}

/// Set the horizontal alignment.
pub fn align_x(input: TextInput, a: Alignment) -> TextInput {
  TextInput(..input, align_x: option.Some(a))
}

/// Enable the submit event.
pub fn on_submit(input: TextInput, enabled: Bool) -> TextInput {
  TextInput(..input, on_submit: option.Some(enabled))
}

/// Enable the paste event.
pub fn on_paste(input: TextInput, enabled: Bool) -> TextInput {
  TextInput(..input, on_paste: option.Some(enabled))
}

/// Set whether input is masked (password mode).
pub fn secure(input: TextInput, s: Bool) -> TextInput {
  TextInput(..input, secure: option.Some(s))
}

/// Set the style.
pub fn style(input: TextInput, s: String) -> TextInput {
  TextInput(..input, style: option.Some(s))
}

/// Set accessibility properties for this widget.
pub fn a11y(input: TextInput, a: A11y) -> TextInput {
  TextInput(..input, a11y: option.Some(a))
}

/// Option type for text input properties.
pub type Opt {
  Placeholder(String)
  Padding(Padding)
  Width(Length)
  Size(Float)
  Font(Font)
  LineHeight(Float)
  AlignX(Alignment)
  OnSubmit(Bool)
  OnPaste(Bool)
  Secure(Bool)
  Style(String)
  A11y(A11y)
}

/// Apply a list of options to a text input builder.
pub fn with_opts(input: TextInput, opts: List(Opt)) -> TextInput {
  list.fold(opts, input, fn(i, opt) {
    case opt {
      Placeholder(p) -> placeholder(i, p)
      Padding(p) -> padding(i, p)
      Width(w) -> width(i, w)
      Size(s) -> size(i, s)
      Font(f) -> font(i, f)
      LineHeight(h) -> line_height(i, h)
      AlignX(a) -> align_x(i, a)
      OnSubmit(v) -> on_submit(i, v)
      OnPaste(v) -> on_paste(i, v)
      Secure(v) -> secure(i, v)
      Style(s) -> style(i, s)
      A11y(a) -> a11y(i, a)
    }
  })
}

/// Build the text input into a renderable Node.
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
