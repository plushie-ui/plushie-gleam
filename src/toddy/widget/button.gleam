//// Button widget builder.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node, StringVal}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/widget/build

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
