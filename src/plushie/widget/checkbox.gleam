//// Checkbox widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, type PropValue, DictVal, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/font.{type Font}
import plushie/prop/length.{type Length}
import plushie/prop/shaping.{type Shaping}
import plushie/prop/wrapping.{type Wrapping}
import plushie/widget/build

/// Custom icon for the checkbox check mark.
pub type CheckboxIcon {
  CheckboxIcon(
    code_point: String,
    size: Option(Float),
    line_height: Option(Float),
    font: Option(Font),
    shaping: Option(Shaping),
  )
}

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
    line_height: Option(Float),
    shaping: Option(Shaping),
    wrapping: Option(Wrapping),
    style: Option(String),
    icon: Option(CheckboxIcon),
    disabled: Option(Bool),
    a11y: Option(A11y),
  )
}

/// Create a new checkbox builder.
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
    line_height: None,
    shaping: None,
    wrapping: None,
    style: None,
    icon: None,
    disabled: None,
    a11y: None,
  )
}

/// Set the spacing between children.
pub fn spacing(cb: Checkbox, s: Int) -> Checkbox {
  Checkbox(..cb, spacing: option.Some(s))
}

/// Set the width.
pub fn width(cb: Checkbox, w: Length) -> Checkbox {
  Checkbox(..cb, width: option.Some(w))
}

/// Set the size.
pub fn size(cb: Checkbox, s: Float) -> Checkbox {
  Checkbox(..cb, size: option.Some(s))
}

/// Set the text size in pixels.
pub fn text_size(cb: Checkbox, s: Float) -> Checkbox {
  Checkbox(..cb, text_size: option.Some(s))
}

/// Set the font.
pub fn font(cb: Checkbox, f: Font) -> Checkbox {
  Checkbox(..cb, font: option.Some(f))
}

/// Set the line height.
pub fn line_height(cb: Checkbox, h: Float) -> Checkbox {
  Checkbox(..cb, line_height: option.Some(h))
}

/// Set the text shaping strategy.
pub fn shaping(cb: Checkbox, s: Shaping) -> Checkbox {
  Checkbox(..cb, shaping: option.Some(s))
}

/// Set the text wrapping mode.
pub fn wrapping(cb: Checkbox, w: Wrapping) -> Checkbox {
  Checkbox(..cb, wrapping: option.Some(w))
}

/// Set the style.
pub fn style(cb: Checkbox, s: String) -> Checkbox {
  Checkbox(..cb, style: option.Some(s))
}

/// Set a custom icon.
pub fn icon(cb: Checkbox, i: CheckboxIcon) -> Checkbox {
  Checkbox(..cb, icon: option.Some(i))
}

/// Set whether the widget is disabled.
pub fn disabled(cb: Checkbox, d: Bool) -> Checkbox {
  Checkbox(..cb, disabled: option.Some(d))
}

/// Set accessibility properties for this widget.
pub fn a11y(cb: Checkbox, a: A11y) -> Checkbox {
  Checkbox(..cb, a11y: option.Some(a))
}

/// Option type for checkbox properties.
pub type Opt {
  Spacing(Int)
  Width(Length)
  Size(Float)
  TextSize(Float)
  Font(Font)
  LineHeight(Float)
  Shaping(Shaping)
  Wrapping(Wrapping)
  Style(String)
  Icon(CheckboxIcon)
  Disabled(Bool)
  A11y(A11y)
}

/// Apply a list of options to a checkbox builder.
pub fn with_opts(cb: Checkbox, opts: List(Opt)) -> Checkbox {
  list.fold(opts, cb, fn(c, opt) {
    case opt {
      Spacing(s) -> spacing(c, s)
      Width(w) -> width(c, w)
      Size(s) -> size(c, s)
      TextSize(s) -> text_size(c, s)
      Font(f) -> font(c, f)
      LineHeight(h) -> line_height(c, h)
      Shaping(s) -> shaping(c, s)
      Wrapping(w) -> wrapping(c, w)
      Style(s) -> style(c, s)
      Icon(i) -> icon(c, i)
      Disabled(d) -> disabled(c, d)
      A11y(a) -> a11y(c, a)
    }
  })
}

fn icon_to_prop_value(i: CheckboxIcon) -> PropValue {
  let props =
    dict.new()
    |> dict.insert("code_point", node.StringVal(i.code_point))
    |> build.put_optional_float("size", i.size)
    |> build.put_optional_float("line_height", i.line_height)
    |> build.put_optional("font", i.font, font.to_prop_value)
    |> build.put_optional("shaping", i.shaping, shaping.to_prop_value)
  DictVal(props)
}

/// Build the checkbox into a renderable Node.
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
    |> build.put_optional_float("line_height", cb.line_height)
    |> build.put_optional("shaping", cb.shaping, shaping.to_prop_value)
    |> build.put_optional("wrapping", cb.wrapping, wrapping.to_prop_value)
    |> build.put_optional_string("style", cb.style)
    |> build.put_optional("icon", cb.icon, icon_to_prop_value)
    |> build.put_optional_bool("disabled", cb.disabled)
    |> build.put_optional("a11y", cb.a11y, a11y.to_prop_value)
  Node(id: cb.id, kind: "checkbox", props:, children: [], meta: dict.new())
}
