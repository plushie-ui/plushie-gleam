//// Rich text widget builder. Spans are added as child nodes.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/widget/build

pub opaque type RichText {
  RichText(id: String, children: List(Node), a11y: Option(A11y))
}

pub fn new(id: String) -> RichText {
  RichText(id:, children: [], a11y: None)
}

/// Add a span child node.
pub fn push(rt: RichText, child: Node) -> RichText {
  RichText(..rt, children: list.append(rt.children, [child]))
}

/// Add multiple span child nodes.
pub fn extend(rt: RichText, children: List(Node)) -> RichText {
  RichText(..rt, children: list.append(rt.children, children))
}

pub fn a11y(rt: RichText, a: A11y) -> RichText {
  RichText(..rt, a11y: option.Some(a))
}

pub fn build(rt: RichText) -> Node {
  let props =
    dict.new()
    |> build.put_optional("a11y", rt.a11y, a11y.to_prop_value)
  Node(id: rt.id, kind: "rich_text", props:, children: rt.children)
}
