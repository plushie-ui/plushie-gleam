//// Combo box widget builder (text field with suggestions dropdown).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, type PropValue, ListVal, Node, StringVal}
import toddy/prop/a11y.{type A11y}
import toddy/prop/font.{type Font}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/prop/shaping.{type Shaping}
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
    line_height: Option(Float),
    menu_height: Option(Float),
    icon: Option(PropValue),
    on_option_hovered: Option(Bool),
    on_open: Option(Bool),
    on_close: Option(Bool),
    shaping: Option(Shaping),
    ellipsis: Option(String),
    menu_style: Option(PropValue),
    on_submit: Option(Bool),
    style: Option(String),
    a11y: Option(A11y),
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
    line_height: None,
    menu_height: None,
    icon: None,
    on_option_hovered: None,
    on_open: None,
    on_close: None,
    shaping: None,
    ellipsis: None,
    menu_style: None,
    on_submit: None,
    style: None,
    a11y: None,
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

pub fn line_height(cb: ComboBox, h: Float) -> ComboBox {
  ComboBox(..cb, line_height: option.Some(h))
}

pub fn menu_height(cb: ComboBox, h: Float) -> ComboBox {
  ComboBox(..cb, menu_height: option.Some(h))
}

/// Set a custom icon. Pass a DictVal with keys like code_point, size, font, etc.
pub fn icon(cb: ComboBox, i: PropValue) -> ComboBox {
  ComboBox(..cb, icon: option.Some(i))
}

pub fn on_option_hovered(cb: ComboBox, enabled: Bool) -> ComboBox {
  ComboBox(..cb, on_option_hovered: option.Some(enabled))
}

pub fn on_open(cb: ComboBox, enabled: Bool) -> ComboBox {
  ComboBox(..cb, on_open: option.Some(enabled))
}

pub fn on_close(cb: ComboBox, enabled: Bool) -> ComboBox {
  ComboBox(..cb, on_close: option.Some(enabled))
}

pub fn shaping(cb: ComboBox, s: Shaping) -> ComboBox {
  ComboBox(..cb, shaping: option.Some(s))
}

pub fn ellipsis(cb: ComboBox, e: String) -> ComboBox {
  ComboBox(..cb, ellipsis: option.Some(e))
}

/// Set dropdown menu style overrides. Pass a DictVal with optional keys:
/// background, text_color, selected_text_color, selected_background, border, shadow.
pub fn menu_style(cb: ComboBox, ms: PropValue) -> ComboBox {
  ComboBox(..cb, menu_style: option.Some(ms))
}

pub fn on_submit(cb: ComboBox, enabled: Bool) -> ComboBox {
  ComboBox(..cb, on_submit: option.Some(enabled))
}

pub fn style(cb: ComboBox, s: String) -> ComboBox {
  ComboBox(..cb, style: option.Some(s))
}

pub fn a11y(cb: ComboBox, a: A11y) -> ComboBox {
  ComboBox(..cb, a11y: option.Some(a))
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
    |> build.put_optional_float("line_height", cb.line_height)
    |> build.put_optional_float("menu_height", cb.menu_height)
    |> build.put_optional("icon", cb.icon, fn(i) { i })
    |> build.put_optional_bool("on_option_hovered", cb.on_option_hovered)
    |> build.put_optional_bool("on_open", cb.on_open)
    |> build.put_optional_bool("on_close", cb.on_close)
    |> build.put_optional("shaping", cb.shaping, shaping.to_prop_value)
    |> build.put_optional_string("ellipsis", cb.ellipsis)
    |> build.put_optional("menu_style", cb.menu_style, fn(ms) { ms })
    |> build.put_optional_bool("on_submit", cb.on_submit)
    |> build.put_optional_string("style", cb.style)
    |> build.put_optional("a11y", cb.a11y, a11y.to_prop_value)
  Node(id: cb.id, kind: "combo_box", props:, children: [])
}
