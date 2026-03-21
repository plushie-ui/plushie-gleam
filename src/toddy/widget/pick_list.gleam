//// Pick list widget builder (dropdown picker).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, ListVal, Node, StringVal}
import toddy/prop/a11y.{type A11y}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/widget/build

pub opaque type PickList {
  PickList(
    id: String,
    options: List(String),
    selected: Option(String),
    placeholder: Option(String),
    width: Option(Length),
    padding: Option(Padding),
    text_size: Option(Float),
    font: Option(Font),
    style: Option(String),
    a11y: Option(A11y),
  )
}

pub fn new(
  id: String,
  options: List(String),
  selected: Option(String),
) -> PickList {
  PickList(
    id:,
    options:,
    selected:,
    placeholder: None,
    width: None,
    padding: None,
    text_size: None,
    font: None,
    style: None,
    a11y: None,
  )
}

pub fn placeholder(pl: PickList, p: String) -> PickList {
  PickList(..pl, placeholder: option.Some(p))
}

pub fn width(pl: PickList, w: Length) -> PickList {
  PickList(..pl, width: option.Some(w))
}

pub fn padding(pl: PickList, p: Padding) -> PickList {
  PickList(..pl, padding: option.Some(p))
}

pub fn text_size(pl: PickList, s: Float) -> PickList {
  PickList(..pl, text_size: option.Some(s))
}

pub fn font(pl: PickList, f: Font) -> PickList {
  PickList(..pl, font: option.Some(f))
}

pub fn style(pl: PickList, s: String) -> PickList {
  PickList(..pl, style: option.Some(s))
}

pub fn a11y(pl: PickList, a: A11y) -> PickList {
  PickList(..pl, a11y: option.Some(a))
}

pub fn build(pl: PickList) -> Node {
  let props =
    dict.new()
    |> dict.insert("options", ListVal(list.map(pl.options, StringVal)))
    |> build.put_optional_string("selected", pl.selected)
    |> build.put_optional_string("placeholder", pl.placeholder)
    |> build.put_optional("width", pl.width, length.to_prop_value)
    |> build.put_optional("padding", pl.padding, padding.to_prop_value)
    |> build.put_optional_float("text_size", pl.text_size)
    |> build.put_optional("font", pl.font, font.to_prop_value)
    |> build.put_optional_string("style", pl.style)
    |> build.put_optional("a11y", pl.a11y, a11y.to_prop_value)
  Node(id: pl.id, kind: "pick_list", props:, children: [])
}
