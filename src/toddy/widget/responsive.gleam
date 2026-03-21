//// Responsive layout widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/widget/build

pub opaque type Responsive {
  Responsive(id: String, children: List(Node), a11y: Option(A11y))
}

pub fn new(id: String) -> Responsive {
  Responsive(id:, children: [], a11y: None)
}

/// Add a child node.
pub fn push(r: Responsive, child: Node) -> Responsive {
  Responsive(..r, children: list.append(r.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(r: Responsive, children: List(Node)) -> Responsive {
  Responsive(..r, children: list.append(r.children, children))
}

pub fn a11y(r: Responsive, a: A11y) -> Responsive {
  Responsive(..r, a11y: option.Some(a))
}

pub fn build(r: Responsive) -> Node {
  let props =
    dict.new()
    |> build.put_optional("a11y", r.a11y, a11y.to_prop_value)
  Node(id: r.id, kind: "responsive", props:, children: r.children)
}
