//// Combo box widget builder (text field with suggestions dropdown).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, ListVal, Node, StringVal}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/widget/build

pub opaque type ComboBox {
  ComboBox(
    id: String,
    options: List(String),
    value: String,
    placeholder: Option(String),
    width: Option(Length),
    padding: Option(Padding),
    size: Option(Float),
    font: Option(Font),
    on_submit: Option(Bool),
    style: Option(String),
  )
}

pub fn new(id: String, options: List(String), value: String) -> ComboBox {
  ComboBox(
    id:,
    options:,
    value:,
    placeholder: None,
    width: None,
    padding: None,
    size: None,
    font: None,
    on_submit: None,
    style: None,
  )
}

pub fn placeholder(cb: ComboBox, p: String) -> ComboBox {
  ComboBox(..cb, placeholder: option.Some(p))
}

pub fn width(cb: ComboBox, w: Length) -> ComboBox {
  ComboBox(..cb, width: option.Some(w))
}

pub fn padding(cb: ComboBox, p: Padding) -> ComboBox {
  ComboBox(..cb, padding: option.Some(p))
}

pub fn size(cb: ComboBox, s: Float) -> ComboBox {
  ComboBox(..cb, size: option.Some(s))
}

pub fn font(cb: ComboBox, f: Font) -> ComboBox {
  ComboBox(..cb, font: option.Some(f))
}

pub fn on_submit(cb: ComboBox, enabled: Bool) -> ComboBox {
  ComboBox(..cb, on_submit: option.Some(enabled))
}

pub fn style(cb: ComboBox, s: String) -> ComboBox {
  ComboBox(..cb, style: option.Some(s))
}

pub fn build(cb: ComboBox) -> Node {
  let props =
    dict.new()
    |> dict.insert("options", ListVal(list.map(cb.options, StringVal)))
    |> build.put_string("selected", cb.value)
    |> build.put_optional_string("placeholder", cb.placeholder)
    |> build.put_optional("width", cb.width, length.to_prop_value)
    |> build.put_optional("padding", cb.padding, padding.to_prop_value)
    |> build.put_optional_float("size", cb.size)
    |> build.put_optional("font", cb.font, font.to_prop_value)
    |> build.put_optional_bool("on_submit", cb.on_submit)
    |> build.put_optional_string("style", cb.style)
  Node(id: cb.id, kind: "combo_box", props:, children: [])
}
