//// Pick list widget builder (dropdown picker).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, type PropValue, ListVal, Node, StringVal}
import plushie/prop/a11y.{type A11y}
import plushie/prop/font.{type Font}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/prop/shaping.{type Shaping}
import plushie/widget/build

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
    line_height: Option(Float),
    menu_height: Option(Float),
    shaping: Option(Shaping),
    handle: Option(PropValue),
    ellipsis: Option(String),
    menu_style: Option(PropValue),
    on_open: Option(Bool),
    on_close: Option(Bool),
    style: Option(String),
    a11y: Option(A11y),
  )
}

/// Create a new pick list builder.
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
    line_height: None,
    menu_height: None,
    shaping: None,
    handle: None,
    ellipsis: None,
    menu_style: None,
    on_open: None,
    on_close: None,
    style: None,
    a11y: None,
  )
}

/// Set the placeholder text.
pub fn placeholder(pl: PickList, p: String) -> PickList {
  PickList(..pl, placeholder: option.Some(p))
}

/// Set the width.
pub fn width(pl: PickList, w: Length) -> PickList {
  PickList(..pl, width: option.Some(w))
}

/// Set the padding.
pub fn padding(pl: PickList, p: Padding) -> PickList {
  PickList(..pl, padding: option.Some(p))
}

/// Set the text size in pixels.
pub fn text_size(pl: PickList, s: Float) -> PickList {
  PickList(..pl, text_size: option.Some(s))
}

/// Set the font.
pub fn font(pl: PickList, f: Font) -> PickList {
  PickList(..pl, font: option.Some(f))
}

/// Set the line height.
pub fn line_height(pl: PickList, h: Float) -> PickList {
  PickList(..pl, line_height: option.Some(h))
}

/// Set the dropdown menu height.
pub fn menu_height(pl: PickList, h: Float) -> PickList {
  PickList(..pl, menu_height: option.Some(h))
}

/// Set the text shaping strategy.
pub fn shaping(pl: PickList, s: Shaping) -> PickList {
  PickList(..pl, shaping: option.Some(s))
}

/// Set the dropdown handle style. Pass a DictVal with a "type" key.
pub fn handle(pl: PickList, h: PropValue) -> PickList {
  PickList(..pl, handle: option.Some(h))
}

/// Set the text ellipsis mode.
pub fn ellipsis(pl: PickList, e: String) -> PickList {
  PickList(..pl, ellipsis: option.Some(e))
}

/// Set dropdown menu style overrides. Pass a DictVal.
pub fn menu_style(pl: PickList, ms: PropValue) -> PickList {
  PickList(..pl, menu_style: option.Some(ms))
}

/// Enable the open event.
pub fn on_open(pl: PickList, enabled: Bool) -> PickList {
  PickList(..pl, on_open: option.Some(enabled))
}

/// Enable the close event.
pub fn on_close(pl: PickList, enabled: Bool) -> PickList {
  PickList(..pl, on_close: option.Some(enabled))
}

/// Set the style.
pub fn style(pl: PickList, s: String) -> PickList {
  PickList(..pl, style: option.Some(s))
}

/// Set accessibility properties for this widget.
pub fn a11y(pl: PickList, a: A11y) -> PickList {
  PickList(..pl, a11y: option.Some(a))
}

/// Option type for pick list properties.
pub type Opt {
  Placeholder(String)
  Width(Length)
  Padding(Padding)
  TextSize(Float)
  Font(Font)
  LineHeight(Float)
  MenuHeight(Float)
  Shaping(Shaping)
  Handle(PropValue)
  Ellipsis(String)
  MenuStyle(PropValue)
  OnOpen(Bool)
  OnClose(Bool)
  Style(String)
  A11y(A11y)
}

/// Apply a list of options to a pick list builder.
pub fn with_opts(pl: PickList, opts: List(Opt)) -> PickList {
  list.fold(opts, pl, fn(p, opt) {
    case opt {
      Placeholder(v) -> placeholder(p, v)
      Width(w) -> width(p, w)
      Padding(v) -> padding(p, v)
      TextSize(s) -> text_size(p, s)
      Font(f) -> font(p, f)
      LineHeight(h) -> line_height(p, h)
      MenuHeight(h) -> menu_height(p, h)
      Shaping(s) -> shaping(p, s)
      Handle(h) -> handle(p, h)
      Ellipsis(e) -> ellipsis(p, e)
      MenuStyle(ms) -> menu_style(p, ms)
      OnOpen(v) -> on_open(p, v)
      OnClose(v) -> on_close(p, v)
      Style(s) -> style(p, s)
      A11y(a) -> a11y(p, a)
    }
  })
}

/// Build the pick list into a renderable Node.
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
    |> build.put_optional_float("line_height", pl.line_height)
    |> build.put_optional_float("menu_height", pl.menu_height)
    |> build.put_optional("shaping", pl.shaping, shaping.to_prop_value)
    |> build.put_optional("handle", pl.handle, fn(h) { h })
    |> build.put_optional_string("ellipsis", pl.ellipsis)
    |> build.put_optional("menu_style", pl.menu_style, fn(ms) { ms })
    |> build.put_optional_bool("on_open", pl.on_open)
    |> build.put_optional_bool("on_close", pl.on_close)
    |> build.put_optional_string("style", pl.style)
    |> build.put_optional("a11y", pl.a11y, a11y.to_prop_value)
  Node(id: pl.id, kind: "pick_list", props:, children: [])
}
