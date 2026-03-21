//// Themer widget builder (per-subtree theme override).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/theme.{type Theme}
import plushie/widget/build

pub opaque type Themer {
  Themer(id: String, children: List(Node), theme: Theme, a11y: Option(A11y))
}

pub fn new(id: String, t: Theme) -> Themer {
  Themer(id:, children: [], theme: t, a11y: None)
}

/// Add a child node.
pub fn push(th: Themer, child: Node) -> Themer {
  Themer(..th, children: list.append(th.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(th: Themer, children: List(Node)) -> Themer {
  Themer(..th, children: list.append(th.children, children))
}

pub fn a11y(th: Themer, a: A11y) -> Themer {
  Themer(..th, a11y: option.Some(a))
}

pub fn build(th: Themer) -> Node {
  let props =
    dict.new()
    |> dict.insert("theme", theme.to_prop_value(th.theme))
    |> build.put_optional("a11y", th.a11y, a11y.to_prop_value)
  Node(id: th.id, kind: "themer", props:, children: th.children)
}
