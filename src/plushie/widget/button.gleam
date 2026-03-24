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
    |> build.put_optional("a11y", button.a11y, a11y.to_prop_value)
  Node(id: button.id, kind: "button", props:, children: [])
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
