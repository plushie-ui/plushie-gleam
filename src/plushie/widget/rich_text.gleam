//// Rich text widget builder. Displays individually styled spans.
////
//// Spans are encoded as a "spans" prop (list of maps), not as child nodes.
//// Each span carries its own text content and optional style overrides.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import plushie/node.{
  type Node, type PropValue, BoolVal, DictVal, FloatVal, ListVal, Node,
  StringVal,
}
import plushie/prop/a11y.{type A11y}
import plushie/prop/border.{type Border}
import plushie/prop/color.{type Color}
import plushie/prop/ellipsis.{type Ellipsis}
import plushie/prop/font.{type Font}
import plushie/prop/length.{type Length}
import plushie/prop/line_height.{type LineHeight}
import plushie/prop/padding.{type Padding}
import plushie/prop/wrapping.{type Wrapping}
import plushie/widget/build

// --- Span --------------------------------------------------------------------

/// Highlight behind a span's text: an optional fill colour and an
/// optional border around the text box.
pub type SpanHighlight {
  SpanHighlight(background: Option(Color), border: Option(Border))
}

/// A single styled span within a rich text widget.
pub type Span {
  Span(
    text: String,
    size: Option(Float),
    font: Option(Font),
    color: Option(Color),
    line_height: Option(LineHeight),
    link: Option(String),
    underline: Option(Bool),
    strikethrough: Option(Bool),
    padding: Option(Padding),
    highlight: Option(SpanHighlight),
  )
}

/// Create a span with the given text and no style overrides.
pub fn span(text: String) -> Span {
  Span(
    text:,
    size: None,
    font: None,
    color: None,
    line_height: None,
    link: None,
    underline: None,
    strikethrough: None,
    padding: None,
    highlight: None,
  )
}

/// Set the size on a span.
pub fn span_size(s: Span, size: Float) -> Span {
  Span(..s, size: Some(size))
}

/// Set the font on a span.
pub fn span_font(s: Span, f: Font) -> Span {
  Span(..s, font: Some(f))
}

/// Set the color on a span.
pub fn span_color(s: Span, c: Color) -> Span {
  Span(..s, color: Some(c))
}

/// Set the line height on a span.
pub fn span_line_height(s: Span, lh: LineHeight) -> Span {
  Span(..s, line_height: Some(lh))
}

/// Set the link on a span.
pub fn span_link(s: Span, url: String) -> Span {
  Span(..s, link: Some(url))
}

/// Set the underline on a span.
pub fn span_underline(s: Span, u: Bool) -> Span {
  Span(..s, underline: Some(u))
}

/// Set the strikethrough on a span.
pub fn span_strikethrough(s: Span, st: Bool) -> Span {
  Span(..s, strikethrough: Some(st))
}

/// Set the padding on a span.
pub fn span_padding(s: Span, p: Padding) -> Span {
  Span(..s, padding: Some(p))
}

/// Set the highlight on a span.
pub fn span_highlight(s: Span, h: SpanHighlight) -> Span {
  Span(..s, highlight: Some(h))
}

/// Encode a span highlight to a PropValue dict.
fn highlight_to_prop_value(h: SpanHighlight) -> PropValue {
  let fields = dict.new()
  let fields = case h.background {
    Some(c) -> dict.insert(fields, "background", color.to_prop_value(c))
    None -> fields
  }
  let fields = case h.border {
    Some(b) -> dict.insert(fields, "border", border.to_prop_value(b))
    None -> fields
  }
  DictVal(fields)
}

/// Encode a single span to a PropValue dict.
pub fn span_to_prop_value(s: Span) -> PropValue {
  let fields = dict.from_list([#("text", StringVal(s.text))])
  let fields = case s.size {
    Some(v) -> dict.insert(fields, "size", FloatVal(v))
    None -> fields
  }
  let fields = case s.font {
    Some(f) -> dict.insert(fields, "font", font.to_prop_value(f))
    None -> fields
  }
  let fields = case s.color {
    Some(c) -> dict.insert(fields, "color", color.to_prop_value(c))
    None -> fields
  }
  let fields = case s.line_height {
    Some(lh) ->
      dict.insert(fields, "line_height", line_height.to_prop_value(lh))
    None -> fields
  }
  let fields = case s.link {
    Some(url) -> dict.insert(fields, "link", StringVal(url))
    None -> fields
  }
  let fields = case s.underline {
    Some(u) -> dict.insert(fields, "underline", BoolVal(u))
    None -> fields
  }
  let fields = case s.strikethrough {
    Some(st) -> dict.insert(fields, "strikethrough", BoolVal(st))
    None -> fields
  }
  let fields = case s.padding {
    Some(p) -> dict.insert(fields, "padding", padding.to_prop_value(p))
    None -> fields
  }
  let fields = case s.highlight {
    Some(h) -> dict.insert(fields, "highlight", highlight_to_prop_value(h))
    None -> fields
  }
  DictVal(fields)
}

// --- RichText ----------------------------------------------------------------

pub opaque type RichText {
  RichText(
    id: String,
    spans: Option(List(Span)),
    width: Option(Length),
    height: Option(Length),
    size: Option(Float),
    font: Option(Font),
    color: Option(Color),
    line_height: Option(LineHeight),
    wrapping: Option(Wrapping),
    ellipsis: Option(Ellipsis),
    a11y: Option(A11y),
  )
}

/// Create a new rich text builder.
pub fn new(id: String) -> RichText {
  RichText(
    id:,
    spans: None,
    width: None,
    height: None,
    size: None,
    font: None,
    color: None,
    line_height: None,
    wrapping: None,
    ellipsis: None,
    a11y: None,
  )
}

/// Set the list of styled spans.
pub fn spans(rt: RichText, s: List(Span)) -> RichText {
  RichText(..rt, spans: Some(s))
}

/// Set the width.
pub fn width(rt: RichText, w: Length) -> RichText {
  RichText(..rt, width: Some(w))
}

/// Set the height.
pub fn height(rt: RichText, h: Length) -> RichText {
  RichText(..rt, height: Some(h))
}

/// Set the size.
pub fn size(rt: RichText, s: Float) -> RichText {
  RichText(..rt, size: Some(s))
}

/// Set the font.
pub fn font(rt: RichText, f: Font) -> RichText {
  RichText(..rt, font: Some(f))
}

/// Set the color.
pub fn color(rt: RichText, c: Color) -> RichText {
  RichText(..rt, color: Some(c))
}

/// Set the line height.
pub fn line_height(rt: RichText, lh: LineHeight) -> RichText {
  RichText(..rt, line_height: Some(lh))
}

/// Set the text wrapping mode.
pub fn wrapping(rt: RichText, w: Wrapping) -> RichText {
  RichText(..rt, wrapping: Some(w))
}

/// Set the text ellipsis mode.
pub fn ellipsis(rt: RichText, e: Ellipsis) -> RichText {
  RichText(..rt, ellipsis: Some(e))
}

/// Set accessibility properties for this widget.
pub fn a11y(rt: RichText, a: A11y) -> RichText {
  RichText(..rt, a11y: Some(a))
}

/// Option type for rich text properties.
pub type Opt {
  Spans(List(Span))
  Width(Length)
  Height(Length)
  Size(Float)
  Font(Font)
  Color(Color)
  LineHeight(LineHeight)
  Wrapping(Wrapping)
  Ellipsis(Ellipsis)
  A11y(A11y)
}

/// Apply a list of options to a rich text builder.
pub fn with_opts(rt: RichText, opts: List(Opt)) -> RichText {
  list.fold(opts, rt, fn(r, opt) {
    case opt {
      Spans(s) -> spans(r, s)
      Width(w) -> width(r, w)
      Height(h) -> height(r, h)
      Size(s) -> size(r, s)
      Font(f) -> font(r, f)
      Color(c) -> color(r, c)
      LineHeight(lh) -> line_height(r, lh)
      Wrapping(w) -> wrapping(r, w)
      Ellipsis(e) -> ellipsis(r, e)
      A11y(a) -> a11y(r, a)
    }
  })
}

/// Build the rich text into a renderable Node.
pub fn build(rt: RichText) -> Node {
  let props =
    dict.new()
    |> build.put_optional("spans", rt.spans, fn(span_list) {
      ListVal(list.map(span_list, span_to_prop_value))
    })
    |> build.put_optional("width", rt.width, length.to_prop_value)
    |> build.put_optional("height", rt.height, length.to_prop_value)
    |> build.put_optional_float("size", rt.size)
    |> build.put_optional("font", rt.font, font.to_prop_value)
    |> build.put_optional("color", rt.color, color.to_prop_value)
    |> build.put_optional(
      "line_height",
      rt.line_height,
      line_height.to_prop_value,
    )
    |> build.put_optional("wrapping", rt.wrapping, wrapping.to_prop_value)
    |> build.put_optional("ellipsis", rt.ellipsis, ellipsis.to_prop_value)
    |> build.apply_default_a11y(rt.a11y, "label", option.None)
  Node(id: rt.id, kind: "rich_text", props:, children: [], meta: dict.new())
}
