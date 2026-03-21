//// Mouse area widget builder (mouse interaction wrapper).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/widget/build

pub opaque type MouseArea {
  MouseArea(
    id: String,
    children: List(Node),
    on_right_press: Option(Bool),
    on_middle_press: Option(Bool),
    on_scroll: Option(Bool),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> MouseArea {
  MouseArea(
    id:,
    children: [],
    on_right_press: None,
    on_middle_press: None,
    on_scroll: None,
    a11y: None,
  )
}

pub fn on_right_press(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_right_press: option.Some(enabled))
}

pub fn on_middle_press(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_middle_press: option.Some(enabled))
}

pub fn on_scroll(ma: MouseArea, enabled: Bool) -> MouseArea {
  MouseArea(..ma, on_scroll: option.Some(enabled))
}

/// Add a child node.
pub fn push(ma: MouseArea, child: Node) -> MouseArea {
  MouseArea(..ma, children: list.append(ma.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(ma: MouseArea, children: List(Node)) -> MouseArea {
  MouseArea(..ma, children: list.append(ma.children, children))
}

pub fn a11y(ma: MouseArea, a: A11y) -> MouseArea {
  MouseArea(..ma, a11y: option.Some(a))
}

pub fn build(ma: MouseArea) -> Node {
  let props =
    dict.new()
    |> build.put_optional_bool("on_right_press", ma.on_right_press)
    |> build.put_optional_bool("on_middle_press", ma.on_middle_press)
    |> build.put_optional_bool("on_scroll", ma.on_scroll)
    |> build.put_optional("a11y", ma.a11y, a11y.to_prop_value)
  Node(id: ma.id, kind: "mouse_area", props:, children: ma.children)
}
