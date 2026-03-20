//// Themer widget builder (per-subtree theme override).

import gleam/dict
import gleam/list
import toddy/node.{type Node, Node}
import toddy/prop/theme.{type Theme}

pub opaque type Themer {
  Themer(id: String, children: List(Node), theme: Theme)
}

pub fn new(id: String, t: Theme) -> Themer {
  Themer(id:, children: [], theme: t)
}

/// Add a child node.
pub fn push(th: Themer, child: Node) -> Themer {
  Themer(..th, children: list.append(th.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(th: Themer, children: List(Node)) -> Themer {
  Themer(..th, children: list.append(th.children, children))
}

pub fn build(th: Themer) -> Node {
  let props =
    dict.new()
    |> dict.insert("theme", theme.to_prop_value(th.theme))
  Node(id: th.id, kind: "themer", props:, children: th.children)
}
