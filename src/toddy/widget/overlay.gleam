//// Overlay container widget builder (children stacked on z-axis).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/widget/build

pub opaque type Overlay {
  Overlay(id: String, children: List(Node), a11y: Option(A11y))
}

pub fn new(id: String) -> Overlay {
  Overlay(id:, children: [], a11y: None)
}

/// Add a child node.
pub fn push(o: Overlay, child: Node) -> Overlay {
  Overlay(..o, children: list.append(o.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(o: Overlay, children: List(Node)) -> Overlay {
  Overlay(..o, children: list.append(o.children, children))
}

pub fn a11y(o: Overlay, a: A11y) -> Overlay {
  Overlay(..o, a11y: option.Some(a))
}

pub fn build(o: Overlay) -> Node {
  let props =
    dict.new()
    |> build.put_optional("a11y", o.a11y, a11y.to_prop_value)
  Node(id: o.id, kind: "overlay", props:, children: o.children)
}
