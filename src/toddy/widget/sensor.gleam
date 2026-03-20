//// Sensor widget builder (layout change detection).

import gleam/dict
import gleam/list
import toddy/node.{type Node, Node}

pub opaque type Sensor {
  Sensor(id: String, children: List(Node))
}

pub fn new(id: String) -> Sensor {
  Sensor(id:, children: [])
}

/// Add a child node.
pub fn push(s: Sensor, child: Node) -> Sensor {
  Sensor(..s, children: list.append(s.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(s: Sensor, children: List(Node)) -> Sensor {
  Sensor(..s, children: list.append(s.children, children))
}

pub fn build(s: Sensor) -> Node {
  Node(id: s.id, kind: "sensor", props: dict.new(), children: s.children)
}
