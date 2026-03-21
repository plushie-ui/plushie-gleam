//// Stack container widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/widget/build

pub opaque type Stack {
  Stack(
    id: String,
    children: List(Node),
    width: Option(Length),
    height: Option(Length),
    padding: Option(Padding),
    clip: Option(Bool),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Stack {
  Stack(
    id:,
    children: [],
    width: None,
    height: None,
    padding: None,
    clip: None,
    a11y: None,
  )
}

pub fn width(s: Stack, w: Length) -> Stack {
  Stack(..s, width: option.Some(w))
}

pub fn height(s: Stack, h: Length) -> Stack {
  Stack(..s, height: option.Some(h))
}

pub fn padding(s: Stack, p: Padding) -> Stack {
  Stack(..s, padding: option.Some(p))
}

pub fn clip(s: Stack, c: Bool) -> Stack {
  Stack(..s, clip: option.Some(c))
}

/// Add a child node.
pub fn push(s: Stack, child: Node) -> Stack {
  Stack(..s, children: list.append(s.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(s: Stack, children: List(Node)) -> Stack {
  Stack(..s, children: list.append(s.children, children))
}

pub fn a11y(s: Stack, a: A11y) -> Stack {
  Stack(..s, a11y: option.Some(a))
}

pub fn build(s: Stack) -> Node {
  let props =
    dict.new()
    |> build.put_optional("width", s.width, length.to_prop_value)
    |> build.put_optional("height", s.height, length.to_prop_value)
    |> build.put_optional("padding", s.padding, padding.to_prop_value)
    |> build.put_optional_bool("clip", s.clip)
    |> build.put_optional("a11y", s.a11y, a11y.to_prop_value)
  Node(id: s.id, kind: "stack", props:, children: s.children)
}
