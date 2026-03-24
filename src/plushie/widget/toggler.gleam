//// Toggler widget builder (toggle switch).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/alignment.{type Alignment}
import plushie/prop/font.{type Font}
import plushie/prop/length.{type Length}
import plushie/prop/shaping.{type Shaping}
import plushie/prop/wrapping.{type Wrapping}
import plushie/widget/build

pub opaque type Toggler {
  Toggler(
    id: String,
    label: String,
    is_toggled: Bool,
    spacing: Option(Int),
    width: Option(Length),
    size: Option(Float),
    text_size: Option(Float),
    font: Option(Font),
    line_height: Option(Float),
    shaping: Option(Shaping),
    wrapping: Option(Wrapping),
    text_alignment: Option(Alignment),
    style: Option(String),
    disabled: Option(Bool),
    a11y: Option(A11y),
  )
}

/// Create a new toggler builder.
pub fn new(id: String, label: String, is_toggled: Bool) -> Toggler {
  Toggler(
    id:,
    label:,
    is_toggled:,
    spacing: None,
    width: None,
    size: None,
    text_size: None,
    font: None,
    line_height: None,
    shaping: None,
    wrapping: None,
    text_alignment: None,
    style: None,
    disabled: None,
    a11y: None,
  )
}

/// Set the spacing between children.
pub fn spacing(t: Toggler, s: Int) -> Toggler {
  Toggler(..t, spacing: option.Some(s))
}

/// Set the width.
pub fn width(t: Toggler, w: Length) -> Toggler {
  Toggler(..t, width: option.Some(w))
}

/// Set the size.
pub fn size(t: Toggler, s: Float) -> Toggler {
  Toggler(..t, size: option.Some(s))
}

/// Set the text size in pixels.
pub fn text_size(t: Toggler, s: Float) -> Toggler {
  Toggler(..t, text_size: option.Some(s))
}

/// Set the font.
pub fn font(t: Toggler, f: Font) -> Toggler {
  Toggler(..t, font: option.Some(f))
}

/// Set the line height.
pub fn line_height(t: Toggler, h: Float) -> Toggler {
  Toggler(..t, line_height: option.Some(h))
}

/// Set the text shaping strategy.
pub fn shaping(t: Toggler, s: Shaping) -> Toggler {
  Toggler(..t, shaping: option.Some(s))
}

/// Set the text wrapping mode.
pub fn wrapping(t: Toggler, w: Wrapping) -> Toggler {
  Toggler(..t, wrapping: option.Some(w))
}

/// Set the text alignment.
pub fn text_alignment(t: Toggler, a: Alignment) -> Toggler {
  Toggler(..t, text_alignment: option.Some(a))
}

/// Set the style.
pub fn style(t: Toggler, s: String) -> Toggler {
  Toggler(..t, style: option.Some(s))
}

/// Set whether the widget is disabled.
pub fn disabled(t: Toggler, d: Bool) -> Toggler {
  Toggler(..t, disabled: option.Some(d))
}

/// Set accessibility properties for this widget.
pub fn a11y(t: Toggler, a: A11y) -> Toggler {
  Toggler(..t, a11y: option.Some(a))
}

/// Option type for toggler properties.
pub type Opt {
  Spacing(Int)
  Width(Length)
  Size(Float)
  TextSize(Float)
  Font(Font)
  LineHeight(Float)
  Shaping(Shaping)
  Wrapping(Wrapping)
  TextAlignment(Alignment)
  Style(String)
  Disabled(Bool)
  A11y(A11y)
}

/// Apply a list of options to a toggler builder.
pub fn with_opts(t: Toggler, opts: List(Opt)) -> Toggler {
  list.fold(opts, t, fn(tg, opt) {
    case opt {
      Spacing(s) -> spacing(tg, s)
      Width(w) -> width(tg, w)
      Size(s) -> size(tg, s)
      TextSize(s) -> text_size(tg, s)
      Font(f) -> font(tg, f)
      LineHeight(h) -> line_height(tg, h)
      Shaping(s) -> shaping(tg, s)
      Wrapping(w) -> wrapping(tg, w)
      TextAlignment(a) -> text_alignment(tg, a)
      Style(s) -> style(tg, s)
      Disabled(d) -> disabled(tg, d)
      A11y(a) -> a11y(tg, a)
    }
  })
}

/// Build the toggler into a renderable Node.
pub fn build(t: Toggler) -> Node {
  let props =
    dict.new()
    |> build.put_string("label", t.label)
    |> build.put_optional_bool("is_toggled", option.Some(t.is_toggled))
    |> build.put_optional_int("spacing", t.spacing)
    |> build.put_optional("width", t.width, length.to_prop_value)
    |> build.put_optional_float("size", t.size)
    |> build.put_optional_float("text_size", t.text_size)
    |> build.put_optional("font", t.font, font.to_prop_value)
    |> build.put_optional_float("line_height", t.line_height)
    |> build.put_optional("shaping", t.shaping, shaping.to_prop_value)
    |> build.put_optional("wrapping", t.wrapping, wrapping.to_prop_value)
    |> build.put_optional(
      "text_alignment",
      t.text_alignment,
      alignment.to_prop_value,
    )
    |> build.put_optional_string("style", t.style)
    |> build.put_optional_bool("disabled", t.disabled)
    |> build.put_optional("a11y", t.a11y, a11y.to_prop_value)
  Node(id: t.id, kind: "toggler", props:, children: [])
}
