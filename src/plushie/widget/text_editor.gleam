//// Text editor widget builder (multi-line text editing).

import gleam/dict
import gleam/list
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

/// Create a new text editor builder.
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

/// Set the placeholder text.
pub fn placeholder(te: TextEditor, p: String) -> TextEditor {
  TextEditor(..te, placeholder: option.Some(p))
}

/// Set the width.
pub fn width(te: TextEditor, w: Length) -> TextEditor {
  TextEditor(..te, width: option.Some(w))
}

/// Set the height.
pub fn height(te: TextEditor, h: Length) -> TextEditor {
  TextEditor(..te, height: option.Some(h))
}

/// Set the minimum height in pixels.
pub fn min_height(te: TextEditor, h: Float) -> TextEditor {
  TextEditor(..te, min_height: option.Some(h))
}

/// Set the maximum height in pixels.
pub fn max_height(te: TextEditor, h: Float) -> TextEditor {
  TextEditor(..te, max_height: option.Some(h))
}

/// Set the padding.
pub fn padding(te: TextEditor, p: Padding) -> TextEditor {
  TextEditor(..te, padding: option.Some(p))
}

/// Set the font.
pub fn font(te: TextEditor, f: Font) -> TextEditor {
  TextEditor(..te, font: option.Some(f))
}

/// Set the size.
pub fn size(te: TextEditor, s: Float) -> TextEditor {
  TextEditor(..te, size: option.Some(s))
}

/// Set the line height.
pub fn line_height(te: TextEditor, h: Float) -> TextEditor {
  TextEditor(..te, line_height: option.Some(h))
}

/// Set the text wrapping mode.
pub fn wrapping(te: TextEditor, w: Wrapping) -> TextEditor {
  TextEditor(..te, wrapping: option.Some(w))
}

/// Set the IME purpose hint.
pub fn ime_purpose(te: TextEditor, p: String) -> TextEditor {
  TextEditor(..te, ime_purpose: option.Some(p))
}

/// Set the syntax highlighting language.
pub fn highlight_syntax(te: TextEditor, lang: String) -> TextEditor {
  TextEditor(..te, highlight_syntax: option.Some(lang))
}

/// Set the syntax highlighting theme.
pub fn highlight_theme(te: TextEditor, theme: String) -> TextEditor {
  TextEditor(..te, highlight_theme: option.Some(theme))
}

/// Set the style.
pub fn style(te: TextEditor, s: String) -> TextEditor {
  TextEditor(..te, style: option.Some(s))
}

/// Set declarative key binding rules. Each rule is a DictVal.
pub fn key_bindings(te: TextEditor, bindings: List(PropValue)) -> TextEditor {
  TextEditor(..te, key_bindings: option.Some(bindings))
}

/// Set the placeholder text color.
pub fn placeholder_color(te: TextEditor, c: Color) -> TextEditor {
  TextEditor(..te, placeholder_color: option.Some(c))
}

/// Set the selection highlight color.
pub fn selection_color(te: TextEditor, c: Color) -> TextEditor {
  TextEditor(..te, selection_color: option.Some(c))
}

/// Set accessibility properties for this widget.
pub fn a11y(te: TextEditor, a: A11y) -> TextEditor {
  TextEditor(..te, a11y: option.Some(a))
}

/// Option type for text editor properties.
pub type Opt {
  Placeholder(String)
  Width(Length)
  Height(Length)
  MinHeight(Float)
  MaxHeight(Float)
  Padding(Padding)
  Font(Font)
  Size(Float)
  LineHeight(Float)
  Wrapping(Wrapping)
  ImePurpose(String)
  HighlightSyntax(String)
  HighlightTheme(String)
  Style(String)
  KeyBindings(List(PropValue))
  PlaceholderColor(Color)
  SelectionColor(Color)
  A11y(A11y)
}

/// Apply a list of options to a text editor builder.
pub fn with_opts(te: TextEditor, opts: List(Opt)) -> TextEditor {
  list.fold(opts, te, fn(t, opt) {
    case opt {
      Placeholder(p) -> placeholder(t, p)
      Width(w) -> width(t, w)
      Height(h) -> height(t, h)
      MinHeight(h) -> min_height(t, h)
      MaxHeight(h) -> max_height(t, h)
      Padding(p) -> padding(t, p)
      Font(f) -> font(t, f)
      Size(s) -> size(t, s)
      LineHeight(h) -> line_height(t, h)
      Wrapping(w) -> wrapping(t, w)
      ImePurpose(p) -> ime_purpose(t, p)
      HighlightSyntax(lang) -> highlight_syntax(t, lang)
      HighlightTheme(theme) -> highlight_theme(t, theme)
      Style(s) -> style(t, s)
      KeyBindings(kb) -> key_bindings(t, kb)
      PlaceholderColor(c) -> placeholder_color(t, c)
      SelectionColor(c) -> selection_color(t, c)
      A11y(a) -> a11y(t, a)
    }
  })
}

/// Build the text editor into a renderable Node.
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
  Node(id: te.id, kind: "text_editor", props:, children: [], meta: dict.new())
}
