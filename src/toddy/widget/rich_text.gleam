//// Rich text widget builder. Spans are added as child nodes.

import gleam/dict
import gleam/list
import toddy/node.{type Node, Node}

pub opaque type RichText {
  RichText(id: String, children: List(Node))
}

pub fn new(id: String) -> RichText {
  RichText(id:, children: [])
}

/// Add a span child node.
pub fn push(rt: RichText, child: Node) -> RichText {
  RichText(..rt, children: list.append(rt.children, [child]))
}

/// Add multiple span child nodes.
pub fn extend(rt: RichText, children: List(Node)) -> RichText {
  RichText(..rt, children: list.append(rt.children, children))
}

pub fn build(rt: RichText) -> Node {
  Node(id: rt.id, kind: "rich_text", props: dict.new(), children: rt.children)
}
