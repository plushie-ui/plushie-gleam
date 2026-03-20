//// Overlay container widget builder (children stacked on z-axis).

import gleam/dict
import gleam/list
import toddy/node.{type Node, Node}

pub opaque type Overlay {
  Overlay(id: String, children: List(Node))
}

pub fn new(id: String) -> Overlay {
  Overlay(id:, children: [])
}

/// Add a child node.
pub fn push(o: Overlay, child: Node) -> Overlay {
  Overlay(..o, children: list.append(o.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(o: Overlay, children: List(Node)) -> Overlay {
  Overlay(..o, children: list.append(o.children, children))
}

pub fn build(o: Overlay) -> Node {
  Node(id: o.id, kind: "overlay", props: dict.new(), children: o.children)
}
