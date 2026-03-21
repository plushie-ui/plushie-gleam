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
    width: Option(Length),
    height: Option(Length),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Floating {
  Floating(id:, children: [], width: None, height: None, a11y: None)
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
    |> build.put_optional("width", f.width, length.to_prop_value)
    |> build.put_optional("height", f.height, length.to_prop_value)
    |> build.put_optional("a11y", f.a11y, a11y.to_prop_value)
  Node(id: f.id, kind: "float", props:, children: f.children)
}
