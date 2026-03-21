//// Toggler widget builder (toggle switch).

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/alignment.{type Alignment}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
import toddy/prop/shaping.{type Shaping}
import toddy/prop/wrapping.{type Wrapping}
import toddy/widget/build

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

pub fn spacing(t: Toggler, s: Int) -> Toggler {
  Toggler(..t, spacing: option.Some(s))
}

pub fn width(t: Toggler, w: Length) -> Toggler {
  Toggler(..t, width: option.Some(w))
}

pub fn size(t: Toggler, s: Float) -> Toggler {
  Toggler(..t, size: option.Some(s))
}

pub fn text_size(t: Toggler, s: Float) -> Toggler {
  Toggler(..t, text_size: option.Some(s))
}

pub fn font(t: Toggler, f: Font) -> Toggler {
  Toggler(..t, font: option.Some(f))
}

pub fn line_height(t: Toggler, h: Float) -> Toggler {
  Toggler(..t, line_height: option.Some(h))
}

pub fn shaping(t: Toggler, s: Shaping) -> Toggler {
  Toggler(..t, shaping: option.Some(s))
}

pub fn wrapping(t: Toggler, w: Wrapping) -> Toggler {
  Toggler(..t, wrapping: option.Some(w))
}

pub fn text_alignment(t: Toggler, a: Alignment) -> Toggler {
  Toggler(..t, text_alignment: option.Some(a))
}

pub fn style(t: Toggler, s: String) -> Toggler {
  Toggler(..t, style: option.Some(s))
}

pub fn disabled(t: Toggler, d: Bool) -> Toggler {
  Toggler(..t, disabled: option.Some(d))
}

pub fn a11y(t: Toggler, a: A11y) -> Toggler {
  Toggler(..t, a11y: option.Some(a))
}

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
