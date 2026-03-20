//// Canvas widget builder. Layers are managed via extension commands.

import gleam/dict
import toddy/node.{type Node, Node}
import toddy/prop/length.{type Length}

pub opaque type Canvas {
  Canvas(id: String, width: Length, height: Length)
}

pub fn new(id: String, width: Length, height: Length) -> Canvas {
  Canvas(id:, width:, height:)
}

pub fn build(c: Canvas) -> Node {
  let props =
    dict.new()
    |> dict.insert("width", length.to_prop_value(c.width))
    |> dict.insert("height", length.to_prop_value(c.height))
  Node(id: c.id, kind: "canvas", props:, children: [])
}
