//// Pin widget builder (absolutely positioned element).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type Pin {
  Pin(
    id: String,
    children: List(Node),
    x: Option(Float),
    y: Option(Float),
    width: Option(Length),
    height: Option(Length),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Pin {
  Pin(
    id:,
    children: [],
    x: None,
    y: None,
    width: None,
    height: None,
    a11y: None,
  )
}

pub fn x(p: Pin, val: Float) -> Pin {
  Pin(..p, x: option.Some(val))
}

pub fn y(p: Pin, val: Float) -> Pin {
  Pin(..p, y: option.Some(val))
}

pub fn width(p: Pin, w: Length) -> Pin {
  Pin(..p, width: option.Some(w))
}

pub fn height(p: Pin, h: Length) -> Pin {
  Pin(..p, height: option.Some(h))
}

/// Add a child node.
pub fn push(p: Pin, child: Node) -> Pin {
  Pin(..p, children: list.append(p.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(p: Pin, children: List(Node)) -> Pin {
  Pin(..p, children: list.append(p.children, children))
}

pub fn a11y(p: Pin, a: A11y) -> Pin {
  Pin(..p, a11y: option.Some(a))
}

pub fn build(p: Pin) -> Node {
  let props =
    dict.new()
    |> build.put_optional_float("x", p.x)
    |> build.put_optional_float("y", p.y)
    |> build.put_optional("width", p.width, length.to_prop_value)
    |> build.put_optional("height", p.height, length.to_prop_value)
    |> build.put_optional("a11y", p.a11y, a11y.to_prop_value)
  Node(id: p.id, kind: "pin", props:, children: p.children)
}
