//// Checkbox widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type Checkbox {
  Checkbox(
    id: String,
    label: String,
    is_toggled: Bool,
    spacing: Option(Int),
    width: Option(Length),
    size: Option(Float),
    text_size: Option(Float),
    font: Option(Font),
    style: Option(String),
    disabled: Option(Bool),
    a11y: Option(A11y),
  )
}

pub fn new(id: String, label: String, is_toggled: Bool) -> Checkbox {
  Checkbox(
    id:,
    label:,
    is_toggled:,
    spacing: None,
    width: None,
    size: None,
    text_size: None,
    font: None,
    style: None,
    disabled: None,
    a11y: None,
  )
}

pub fn spacing(cb: Checkbox, s: Int) -> Checkbox {
  Checkbox(..cb, spacing: option.Some(s))
}

pub fn width(cb: Checkbox, w: Length) -> Checkbox {
  Checkbox(..cb, width: option.Some(w))
}

pub fn size(cb: Checkbox, s: Float) -> Checkbox {
  Checkbox(..cb, size: option.Some(s))
}

pub fn text_size(cb: Checkbox, s: Float) -> Checkbox {
  Checkbox(..cb, text_size: option.Some(s))
}

pub fn font(cb: Checkbox, f: Font) -> Checkbox {
  Checkbox(..cb, font: option.Some(f))
}

pub fn style(cb: Checkbox, s: String) -> Checkbox {
  Checkbox(..cb, style: option.Some(s))
}

pub fn disabled(cb: Checkbox, d: Bool) -> Checkbox {
  Checkbox(..cb, disabled: option.Some(d))
}

pub fn a11y(cb: Checkbox, a: A11y) -> Checkbox {
  Checkbox(..cb, a11y: option.Some(a))
}

pub fn build(cb: Checkbox) -> Node {
  let props =
    dict.new()
    |> build.put_string("label", cb.label)
    |> build.put_optional_bool("checked", option.Some(cb.is_toggled))
    |> build.put_optional_int("spacing", cb.spacing)
    |> build.put_optional("width", cb.width, length.to_prop_value)
    |> build.put_optional_float("size", cb.size)
    |> build.put_optional_float("text_size", cb.text_size)
    |> build.put_optional("font", cb.font, font.to_prop_value)
    |> build.put_optional_string("style", cb.style)
    |> build.put_optional_bool("disabled", cb.disabled)
    |> build.put_optional("a11y", cb.a11y, a11y.to_prop_value)
  Node(id: cb.id, kind: "checkbox", props:, children: [])
}
