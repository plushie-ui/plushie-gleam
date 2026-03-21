//// Sensor widget builder (layout change detection).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/widget/build

pub opaque type Sensor {
  Sensor(id: String, children: List(Node), a11y: Option(A11y))
}

pub fn new(id: String) -> Sensor {
  Sensor(id:, children: [], a11y: None)
}

/// Add a child node.
pub fn push(s: Sensor, child: Node) -> Sensor {
  Sensor(..s, children: list.append(s.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(s: Sensor, children: List(Node)) -> Sensor {
  Sensor(..s, children: list.append(s.children, children))
}

pub fn a11y(s: Sensor, a: A11y) -> Sensor {
  Sensor(..s, a11y: option.Some(a))
}

pub fn build(s: Sensor) -> Node {
  let props =
    dict.new()
    |> build.put_optional("a11y", s.a11y, a11y.to_prop_value)
  Node(id: s.id, kind: "sensor", props:, children: s.children)
}
