//// Rule widget builder (horizontal/vertical divider).

import gleam/dict
import toddy/node.{type Node, Node}

pub opaque type Rule {
  Rule(id: String)
}

pub fn new(id: String) -> Rule {
  Rule(id:)
}

pub fn build(r: Rule) -> Node {
  Node(id: r.id, kind: "rule", props: dict.new(), children: [])
}
