//// Text editor widget builder (multi-line text editing).

import gleam/dict
import gleam/option.{type Option, None}
import plushie/node.{type Node, type PropValue, ListVal, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/color.{type Color}
import plushie/prop/font.{type Font}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/prop/wrapping.{type Wrapping}
import plushie/widget/build

pub opaque type TextEditor {
  TextEditor(
    id: String,
    content: String,
    placeholder: Option(String),
    width: Option(Length),
    height: Option(Length),
    min_height: Option(Float),
    max_height: Option(Float),
    padding: Option(Padding),
    font: Option(Font),
    size: Option(Float),
    line_height: Option(Float),
    wrapping: Option(Wrapping),
    ime_purpose: Option(String),
    highlight_syntax: Option(String),
    highlight_theme: Option(String),
    style: Option(String),
    key_bindings: Option(List(PropValue)),
    placeholder_color: Option(Color),
    selection_color: Option(Color),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, content: String) -> TextEditor {
  TextEditor(
    id:,
    content:,
    placeholder: None,
    width: None,
    height: None,
    min_height: None,
    max_height: None,
    padding: None,
    font: None,
    size: None,
    line_height: None,
    wrapping: None,
    ime_purpose: None,
    highlight_syntax: None,
    highlight_theme: None,
    style: None,
    key_bindings: None,
    placeholder_color: None,
    selection_color: None,
    a11y: None,
  )
}

pub fn placeholder(te: TextEditor, p: String) -> TextEditor {
  TextEditor(..te, placeholder: option.Some(p))
}

pub fn width(te: TextEditor, w: Length) -> TextEditor {
  TextEditor(..te, width: option.Some(w))
}

pub fn height(te: TextEditor, h: Length) -> TextEditor {
  TextEditor(..te, height: option.Some(h))
}

pub fn min_height(te: TextEditor, h: Float) -> TextEditor {
  TextEditor(..te, min_height: option.Some(h))
}

pub fn max_height(te: TextEditor, h: Float) -> TextEditor {
  TextEditor(..te, max_height: option.Some(h))
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

pub fn line_height(te: TextEditor, h: Float) -> TextEditor {
  TextEditor(..te, line_height: option.Some(h))
}

pub fn wrapping(te: TextEditor, w: Wrapping) -> TextEditor {
  TextEditor(..te, wrapping: option.Some(w))
}

pub fn ime_purpose(te: TextEditor, p: String) -> TextEditor {
  TextEditor(..te, ime_purpose: option.Some(p))
}

pub fn highlight_syntax(te: TextEditor, lang: String) -> TextEditor {
  TextEditor(..te, highlight_syntax: option.Some(lang))
}

pub fn highlight_theme(te: TextEditor, theme: String) -> TextEditor {
  TextEditor(..te, highlight_theme: option.Some(theme))
}

pub fn style(te: TextEditor, s: String) -> TextEditor {
  TextEditor(..te, style: option.Some(s))
}

/// Set declarative key binding rules. Each rule is a DictVal.
pub fn key_bindings(te: TextEditor, bindings: List(PropValue)) -> TextEditor {
  TextEditor(..te, key_bindings: option.Some(bindings))
}

pub fn placeholder_color(te: TextEditor, c: Color) -> TextEditor {
  TextEditor(..te, placeholder_color: option.Some(c))
}

pub fn selection_color(te: TextEditor, c: Color) -> TextEditor {
  TextEditor(..te, selection_color: option.Some(c))
}

pub fn a11y(te: TextEditor, a: A11y) -> TextEditor {
  TextEditor(..te, a11y: option.Some(a))
}

pub fn build(te: TextEditor) -> Node {
  let props =
    dict.new()
    |> build.put_string("content", te.content)
    |> build.put_optional_string("placeholder", te.placeholder)
    |> build.put_optional("width", te.width, length.to_prop_value)
    |> build.put_optional("height", te.height, length.to_prop_value)
    |> build.put_optional_float("min_height", te.min_height)
    |> build.put_optional_float("max_height", te.max_height)
    |> build.put_optional("padding", te.padding, padding.to_prop_value)
    |> build.put_optional("font", te.font, font.to_prop_value)
    |> build.put_optional_float("size", te.size)
    |> build.put_optional_float("line_height", te.line_height)
    |> build.put_optional("wrapping", te.wrapping, wrapping.to_prop_value)
    |> build.put_optional_string("ime_purpose", te.ime_purpose)
    |> build.put_optional_string("highlight_syntax", te.highlight_syntax)
    |> build.put_optional_string("highlight_theme", te.highlight_theme)
    |> build.put_optional_string("style", te.style)
    |> build.put_optional("key_bindings", te.key_bindings, fn(kb) {
      ListVal(kb)
    })
    |> build.put_optional(
      "placeholder_color",
      te.placeholder_color,
      color.to_prop_value,
    )
    |> build.put_optional(
      "selection_color",
      te.selection_color,
      color.to_prop_value,
    )
    |> build.put_optional("a11y", te.a11y, a11y.to_prop_value)
  Node(id: te.id, kind: "text_editor", props:, children: [])
}
