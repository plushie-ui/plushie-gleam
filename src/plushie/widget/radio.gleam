//// Radio button widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/font.{type Font}
import plushie/prop/length.{type Length}
import plushie/prop/shaping.{type Shaping}
import plushie/prop/wrapping.{type Wrapping}
import plushie/widget/build

pub opaque type Radio {
  Radio(
    id: String,
    value: String,
    selected: Option(String),
    label: String,
    group: Option(String),
    spacing: Option(Int),
    width: Option(Length),
    size: Option(Float),
    text_size: Option(Float),
    font: Option(Font),
    line_height: Option(Float),
    shaping: Option(Shaping),
    wrapping: Option(Wrapping),
    style: Option(String),
    a11y: Option(A11y),
  )
}

/// Create a new radio builder.
pub fn new(
  id: String,
  value: String,
  selected: Option(String),
  label: String,
) -> Radio {
  Radio(
    id:,
    value:,
    selected:,
    label:,
    group: None,
    spacing: None,
    width: None,
    size: None,
    text_size: None,
    font: None,
    line_height: None,
    shaping: None,
    wrapping: None,
    style: None,
    a11y: None,
  )
}

/// Set the radio button group name.
pub fn group(r: Radio, g: String) -> Radio {
  Radio(..r, group: option.Some(g))
}

/// Set the spacing between children.
pub fn spacing(r: Radio, s: Int) -> Radio {
  Radio(..r, spacing: option.Some(s))
}

/// Set the width.
pub fn width(r: Radio, w: Length) -> Radio {
  Radio(..r, width: option.Some(w))
}

/// Set the size.
pub fn size(r: Radio, s: Float) -> Radio {
  Radio(..r, size: option.Some(s))
}

/// Set the text size in pixels.
pub fn text_size(r: Radio, s: Float) -> Radio {
  Radio(..r, text_size: option.Some(s))
}

/// Set the font.
pub fn font(r: Radio, f: Font) -> Radio {
  Radio(..r, font: option.Some(f))
}

/// Set the line height.
pub fn line_height(r: Radio, h: Float) -> Radio {
  Radio(..r, line_height: option.Some(h))
}

/// Set the text shaping strategy.
pub fn shaping(r: Radio, s: Shaping) -> Radio {
  Radio(..r, shaping: option.Some(s))
}

/// Set the text wrapping mode.
pub fn wrapping(r: Radio, w: Wrapping) -> Radio {
  Radio(..r, wrapping: option.Some(w))
}

/// Set the style.
pub fn style(r: Radio, s: String) -> Radio {
  Radio(..r, style: option.Some(s))
}

/// Set accessibility properties for this widget.
pub fn a11y(r: Radio, a: A11y) -> Radio {
  Radio(..r, a11y: option.Some(a))
}

/// Option type for radio properties.
pub type Opt {
  Group(String)
  Spacing(Int)
  Width(Length)
  Size(Float)
  TextSize(Float)
  Font(Font)
  LineHeight(Float)
  Shaping(Shaping)
  Wrapping(Wrapping)
  Style(String)
  A11y(A11y)
}

/// Apply a list of options to a radio builder.
pub fn with_opts(r: Radio, opts: List(Opt)) -> Radio {
  list.fold(opts, r, fn(rd, opt) {
    case opt {
      Group(g) -> group(rd, g)
      Spacing(s) -> spacing(rd, s)
      Width(w) -> width(rd, w)
      Size(s) -> size(rd, s)
      TextSize(s) -> text_size(rd, s)
      Font(f) -> font(rd, f)
      LineHeight(h) -> line_height(rd, h)
      Shaping(s) -> shaping(rd, s)
      Wrapping(w) -> wrapping(rd, w)
      Style(s) -> style(rd, s)
      A11y(a) -> a11y(rd, a)
    }
  })
}

/// Build the radio into a renderable Node.
pub fn build(r: Radio) -> Node {
  let props =
    dict.new()
    |> build.put_string("value", r.value)
    |> build.put_optional_string("selected", r.selected)
    |> build.put_string("label", r.label)
    |> build.put_optional_string("group", r.group)
    |> build.put_optional_int("spacing", r.spacing)
    |> build.put_optional("width", r.width, length.to_prop_value)
    |> build.put_optional_float("size", r.size)
    |> build.put_optional_float("text_size", r.text_size)
    |> build.put_optional("font", r.font, font.to_prop_value)
    |> build.put_optional_float("line_height", r.line_height)
    |> build.put_optional("shaping", r.shaping, shaping.to_prop_value)
    |> build.put_optional("wrapping", r.wrapping, wrapping.to_prop_value)
    |> build.put_optional_string("style", r.style)
    |> build.put_optional("a11y", r.a11y, a11y.to_prop_value)
  Node(id: r.id, kind: "radio", props:, children: [])
}
