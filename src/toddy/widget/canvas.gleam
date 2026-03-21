//// Canvas widget builder. Layers are managed via extension commands.

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type Canvas {
  Canvas(id: String, width: Length, height: Length, a11y: Option(A11y))
}

pub fn new(id: String, width: Length, height: Length) -> Canvas {
  Canvas(id:, width:, height:, a11y: None)
}

pub fn a11y(c: Canvas, a: A11y) -> Canvas {
  Canvas(..c, a11y: option.Some(a))
}

pub fn build(c: Canvas) -> Node {
  let props =
    dict.new()
    |> dict.insert("width", length.to_prop_value(c.width))
    |> dict.insert("height", length.to_prop_value(c.height))
    |> build.put_optional("a11y", c.a11y, a11y.to_prop_value)
  Node(id: c.id, kind: "canvas", props:, children: [])
}
