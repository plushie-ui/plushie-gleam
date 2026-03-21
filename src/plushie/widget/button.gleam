//// Button widget builder.

import gleam/dict
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

pub fn style(button: Button, s: ButtonStyle) -> Button {
  Button(..button, style: option.Some(s))
}

pub fn width(button: Button, w: Length) -> Button {
  Button(..button, width: option.Some(w))
}

pub fn height(button: Button, h: Length) -> Button {
  Button(..button, height: option.Some(h))
}

pub fn padding(button: Button, p: Padding) -> Button {
  Button(..button, padding: option.Some(p))
}

pub fn clip(button: Button, c: Bool) -> Button {
  Button(..button, clip: option.Some(c))
}

pub fn disabled(button: Button, d: Bool) -> Button {
  Button(..button, disabled: option.Some(d))
}

pub fn a11y(button: Button, a: A11y) -> Button {
  Button(..button, a11y: option.Some(a))
}

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
