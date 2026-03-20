//// Responsive layout widget builder.

import gleam/dict
import gleam/list
import toddy/node.{type Node, Node}

pub opaque type Responsive {
  Responsive(id: String, children: List(Node))
}

pub fn new(id: String) -> Responsive {
  Responsive(id:, children: [])
}

/// Add a child node.
pub fn push(r: Responsive, child: Node) -> Responsive {
  Responsive(..r, children: list.append(r.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(r: Responsive, children: List(Node)) -> Responsive {
  Responsive(..r, children: list.append(r.children, children))
}

pub fn build(r: Responsive) -> Node {
  Node(id: r.id, kind: "responsive", props: dict.new(), children: r.children)
}
