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
import plushie/prop/color.{type Color}
import plushie/prop/font.{type Font}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/prop/wrapping.{type Wrapping}
import plushie/widget/build

// --- Span --------------------------------------------------------------------

/// Highlight behind a span's text.
pub type SpanHighlight {
  SpanHighlight(
    background: Option(Color),
    border_color: Option(Color),
    border_width: Option(Float),
    border_radius: Option(BorderRadius),
  )
}

/// Border radius: uniform or per-corner (top-left, top-right, bottom-right,
/// bottom-left).
pub type BorderRadius {
  UniformRadius(Float)
  PerCornerRadius(Float, Float, Float, Float)
}

/// A single styled span within a rich text widget.
pub type Span {
  Span(
    text: String,
    size: Option(Float),
    font: Option(Font),
    color: Option(Color),
    line_height: Option(Float),
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

pub fn span_size(s: Span, size: Float) -> Span {
  Span(..s, size: Some(size))
}

pub fn span_font(s: Span, f: Font) -> Span {
  Span(..s, font: Some(f))
}

pub fn span_color(s: Span, c: Color) -> Span {
  Span(..s, color: Some(c))
}

pub fn span_line_height(s: Span, lh: Float) -> Span {
  Span(..s, line_height: Some(lh))
}

pub fn span_link(s: Span, url: String) -> Span {
  Span(..s, link: Some(url))
}

pub fn span_underline(s: Span, u: Bool) -> Span {
  Span(..s, underline: Some(u))
}

pub fn span_strikethrough(s: Span, st: Bool) -> Span {
  Span(..s, strikethrough: Some(st))
}

pub fn span_padding(s: Span, p: Padding) -> Span {
  Span(..s, padding: Some(p))
}

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
  let fields = case h.border_color, h.border_width, h.border_radius {
    None, None, None -> fields
    _, _, _ -> {
      let border = dict.new()
      let border = case h.border_color {
        Some(c) -> dict.insert(border, "color", color.to_prop_value(c))
        None -> border
      }
      let border = case h.border_width {
        Some(w) -> dict.insert(border, "width", FloatVal(w))
        None -> border
      }
      let border = case h.border_radius {
        Some(UniformRadius(r)) -> dict.insert(border, "radius", FloatVal(r))
        Some(PerCornerRadius(tl, tr, br, bl)) ->
          dict.insert(
            border,
            "radius",
            ListVal([FloatVal(tl), FloatVal(tr), FloatVal(br), FloatVal(bl)]),
          )
        None -> border
      }
      dict.insert(fields, "border", DictVal(border))
    }
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
    Some(lh) -> dict.insert(fields, "line_height", FloatVal(lh))
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
    line_height: Option(Float),
    wrapping: Option(Wrapping),
    ellipsis: Option(String),
    a11y: Option(A11y),
  )
}

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

pub fn spans(rt: RichText, s: List(Span)) -> RichText {
  RichText(..rt, spans: Some(s))
}

pub fn width(rt: RichText, w: Length) -> RichText {
  RichText(..rt, width: Some(w))
}

pub fn height(rt: RichText, h: Length) -> RichText {
  RichText(..rt, height: Some(h))
}

pub fn size(rt: RichText, s: Float) -> RichText {
  RichText(..rt, size: Some(s))
}

pub fn font(rt: RichText, f: Font) -> RichText {
  RichText(..rt, font: Some(f))
}

pub fn color(rt: RichText, c: Color) -> RichText {
  RichText(..rt, color: Some(c))
}

pub fn line_height(rt: RichText, lh: Float) -> RichText {
  RichText(..rt, line_height: Some(lh))
}

pub fn wrapping(rt: RichText, w: Wrapping) -> RichText {
  RichText(..rt, wrapping: Some(w))
}

pub fn ellipsis(rt: RichText, e: String) -> RichText {
  RichText(..rt, ellipsis: Some(e))
}

pub fn a11y(rt: RichText, a: A11y) -> RichText {
  RichText(..rt, a11y: Some(a))
}

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
    |> build.put_optional_float("line_height", rt.line_height)
    |> build.put_optional("wrapping", rt.wrapping, wrapping.to_prop_value)
    |> build.put_optional_string("ellipsis", rt.ellipsis)
    |> build.put_optional("a11y", rt.a11y, a11y.to_prop_value)
  Node(id: rt.id, kind: "rich_text", props:, children: [])
}
