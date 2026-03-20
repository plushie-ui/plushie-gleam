//// Space widget builder (flexible space for layout).

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type Space {
  Space(id: String, width: Option(Length), height: Option(Length))
}

pub fn new(id: String) -> Space {
  Space(id:, width: None, height: None)
}

pub fn width(s: Space, w: Length) -> Space {
  Space(..s, width: option.Some(w))
}

pub fn height(s: Space, h: Length) -> Space {
  Space(..s, height: option.Some(h))
}

pub fn build(s: Space) -> Node {
  let props =
    dict.new()
    |> build.put_optional("width", s.width, length.to_prop_value)
    |> build.put_optional("height", s.height, length.to_prop_value)
  Node(id: s.id, kind: "space", props:, children: [])
}
