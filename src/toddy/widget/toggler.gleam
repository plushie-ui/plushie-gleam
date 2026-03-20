//// Toggler widget builder (toggle switch).

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
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
    style: Option(String),
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
    style: None,
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

pub fn style(t: Toggler, s: String) -> Toggler {
  Toggler(..t, style: option.Some(s))
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
    |> build.put_optional_string("style", t.style)
  Node(id: t.id, kind: "toggler", props:, children: [])
}
