//// Floating element widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type Floating {
  Floating(
    id: String,
    children: List(Node),
    translate_x: Option(Float),
    translate_y: Option(Float),
    scale: Option(Float),
    width: Option(Length),
    height: Option(Length),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Floating {
  Floating(
    id:,
    children: [],
    translate_x: None,
    translate_y: None,
    scale: None,
    width: None,
    height: None,
    a11y: None,
  )
}

pub fn translate_x(f: Floating, x: Float) -> Floating {
  Floating(..f, translate_x: option.Some(x))
}

pub fn translate_y(f: Floating, y: Float) -> Floating {
  Floating(..f, translate_y: option.Some(y))
}

pub fn scale(f: Floating, s: Float) -> Floating {
  Floating(..f, scale: option.Some(s))
}

pub fn width(f: Floating, w: Length) -> Floating {
  Floating(..f, width: option.Some(w))
}

pub fn height(f: Floating, h: Length) -> Floating {
  Floating(..f, height: option.Some(h))
}

/// Add a child node.
pub fn push(f: Floating, child: Node) -> Floating {
  Floating(..f, children: list.append(f.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(f: Floating, children: List(Node)) -> Floating {
  Floating(..f, children: list.append(f.children, children))
}

pub fn a11y(f: Floating, a: A11y) -> Floating {
  Floating(..f, a11y: option.Some(a))
}

pub fn build(f: Floating) -> Node {
  let props =
    dict.new()
    |> build.put_optional_float("translate_x", f.translate_x)
    |> build.put_optional_float("translate_y", f.translate_y)
    |> build.put_optional_float("scale", f.scale)
    |> build.put_optional("width", f.width, length.to_prop_value)
    |> build.put_optional("height", f.height, length.to_prop_value)
    |> build.put_optional("a11y", f.a11y, a11y.to_prop_value)
  Node(id: f.id, kind: "float", props:, children: f.children)
}
