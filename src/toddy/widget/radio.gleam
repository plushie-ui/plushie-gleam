//// Radio button widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/font.{type Font}
import toddy/widget/build

pub opaque type Radio {
  Radio(
    id: String,
    value: String,
    selected: Option(String),
    label: String,
    spacing: Option(Int),
    size: Option(Float),
    text_size: Option(Float),
    font: Option(Font),
    style: Option(String),
  )
}

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
    spacing: None,
    size: None,
    text_size: None,
    font: None,
    style: None,
  )
}

pub fn spacing(r: Radio, s: Int) -> Radio {
  Radio(..r, spacing: option.Some(s))
}

pub fn size(r: Radio, s: Float) -> Radio {
  Radio(..r, size: option.Some(s))
}

pub fn text_size(r: Radio, s: Float) -> Radio {
  Radio(..r, text_size: option.Some(s))
}

pub fn font(r: Radio, f: Font) -> Radio {
  Radio(..r, font: option.Some(f))
}

pub fn style(r: Radio, s: String) -> Radio {
  Radio(..r, style: option.Some(s))
}

pub fn build(r: Radio) -> Node {
  let props =
    dict.new()
    |> build.put_string("value", r.value)
    |> build.put_optional_string("selected", r.selected)
    |> build.put_string("label", r.label)
    |> build.put_optional_int("spacing", r.spacing)
    |> build.put_optional_float("size", r.size)
    |> build.put_optional_float("text_size", r.text_size)
    |> build.put_optional("font", r.font, font.to_prop_value)
    |> build.put_optional_string("style", r.style)
  Node(id: r.id, kind: "radio", props:, children: [])
}
