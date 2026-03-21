//// Rule widget builder (horizontal/vertical divider).

import gleam/dict
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/widget/build

pub opaque type Rule {
  Rule(id: String, a11y: Option(A11y))
}

pub fn new(id: String) -> Rule {
  Rule(id:, a11y: None)
}

pub fn a11y(r: Rule, a: A11y) -> Rule {
  Rule(..r, a11y: option.Some(a))
}

pub fn build(r: Rule) -> Node {
  let props =
    dict.new()
    |> build.put_optional("a11y", r.a11y, a11y.to_prop_value)
  Node(id: r.id, kind: "rule", props:, children: [])
}
