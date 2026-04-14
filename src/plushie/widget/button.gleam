//// Button widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node, StringVal}
import plushie/prop/a11y.{type A11y}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/widget/build

pub type ButtonStyle {
  Primary
  Secondary
  Success
  Warning
  Danger
  TextStyle
  BackgroundStyle
  Subtle
}

pub opaque type Button {
  Button(
    id: String,
    label: String,
    style: Option(ButtonStyle),
    width: Option(Length),
    height: Option(Length),
    padding: Option(Padding),
    clip: Option(Bool),
    disabled: Option(Bool),
    a11y: Option(A11y),
    animated_props: dict.Dict(String, node.PropValue),
  )
}

/// Create a new button builder with the given ID and label.
pub fn new(id: String, label: String) -> Button {
  Button(
    id:,
    label:,
    style: None,
    width: None,
    height: None,
    padding: None,
    clip: None,
    disabled: None,
    a11y: None,
    animated_props: dict.new(),
  )
}

/// Set the button style preset.
pub fn style(button: Button, s: ButtonStyle) -> Button {
  Button(..button, style: option.Some(s))
}

/// Set the button width.
pub fn width(button: Button, w: Length) -> Button {
  Button(..button, width: option.Some(w))
}

/// Set the button height.
pub fn height(button: Button, h: Length) -> Button {
  Button(..button, height: option.Some(h))
}

/// Set the button padding.
pub fn padding(button: Button, p: Padding) -> Button {
  Button(..button, padding: option.Some(p))
}

/// Set whether child content that overflows is clipped.
pub fn clip(button: Button, c: Bool) -> Button {
  Button(..button, clip: option.Some(c))
}

/// Set whether the button is disabled.
pub fn disabled(button: Button, d: Bool) -> Button {
  Button(..button, disabled: option.Some(d))
}

/// Set accessibility properties for this button.
pub fn a11y(button: Button, a: A11y) -> Button {
  Button(..button, a11y: option.Some(a))
}

/// Set width to an animation descriptor (Transition, Spring, or Sequence).
/// The descriptor must be pre-encoded via its module's `encode` function.
pub fn width_animated(button: Button, animation: node.PropValue) -> Button {
  Button(
    ..button,
    animated_props: dict.insert(button.animated_props, "width", animation),
  )
}

/// Set height to an animation descriptor (Transition, Spring, or Sequence).
/// The descriptor must be pre-encoded via its module's `encode` function.
pub fn height_animated(button: Button, animation: node.PropValue) -> Button {
  Button(
    ..button,
    animated_props: dict.insert(button.animated_props, "height", animation),
  )
}

/// Set padding to an animation descriptor (Transition, Spring, or Sequence).
/// The descriptor must be pre-encoded via its module's `encode` function.
pub fn padding_animated(button: Button, animation: node.PropValue) -> Button {
  Button(
    ..button,
    animated_props: dict.insert(button.animated_props, "padding", animation),
  )
}

/// Option type for button properties.
pub type Opt {
  Style(ButtonStyle)
  Width(Length)
  Height(Length)
  Padding(Padding)
  Clip(Bool)
  Disabled(Bool)
  A11y(A11y)
}

/// Apply a list of options to a button builder.
pub fn with_opts(button: Button, opts: List(Opt)) -> Button {
  list.fold(opts, button, fn(b, opt) {
    case opt {
      Style(s) -> style(b, s)
      Width(w) -> width(b, w)
      Height(h) -> height(b, h)
      Padding(p) -> padding(b, p)
      Clip(v) -> clip(b, v)
      Disabled(v) -> disabled(b, v)
      A11y(a) -> a11y(b, a)
    }
  })
}

/// Build the button into a renderable Node.
pub fn build(button: Button) -> Node {
  let props =
    dict.new()
    |> build.put_string("label", button.label)
    |> build.put_optional("style", button.style, fn(s) {
      StringVal(style_to_string(s))
    })
    |> build.put_optional("width", button.width, length.to_prop_value)
    |> build.put_optional("height", button.height, length.to_prop_value)
    |> build.put_optional("padding", button.padding, padding.to_prop_value)
    |> build.put_optional_bool("clip", button.clip)
    |> build.put_optional_bool("disabled", button.disabled)
    |> build.apply_default_a11y(button.a11y, "button", option.Some("label"))
    |> build.merge_animated(button.animated_props)
  Node(id: button.id, kind: "button", props:, children: [], meta: dict.new())
}

fn style_to_string(s: ButtonStyle) -> String {
  case s {
    Primary -> "primary"
    Secondary -> "secondary"
    Success -> "success"
    Warning -> "warning"
    Danger -> "danger"
    TextStyle -> "text"
    BackgroundStyle -> "background"
    Subtle -> "subtle"
  }
}
