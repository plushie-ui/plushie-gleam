//// Scrollable widget builder (scrollable viewport container).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/direction.{type Direction}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type Scrollable {
  Scrollable(
    id: String,
    children: List(Node),
    width: Option(Length),
    height: Option(Length),
    direction: Option(Direction),
    spacing: Option(Int),
    on_scroll: Option(Bool),
  )
}

pub fn new(id: String) -> Scrollable {
  Scrollable(
    id:,
    children: [],
    width: None,
    height: None,
    direction: None,
    spacing: None,
    on_scroll: None,
  )
}

pub fn width(s: Scrollable, w: Length) -> Scrollable {
  Scrollable(..s, width: option.Some(w))
}

pub fn height(s: Scrollable, h: Length) -> Scrollable {
  Scrollable(..s, height: option.Some(h))
}

pub fn direction(s: Scrollable, d: Direction) -> Scrollable {
  Scrollable(..s, direction: option.Some(d))
}

pub fn spacing(s: Scrollable, sp: Int) -> Scrollable {
  Scrollable(..s, spacing: option.Some(sp))
}

pub fn on_scroll(s: Scrollable, enabled: Bool) -> Scrollable {
  Scrollable(..s, on_scroll: option.Some(enabled))
}

/// Add a child node.
pub fn push(s: Scrollable, child: Node) -> Scrollable {
  Scrollable(..s, children: list.append(s.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(s: Scrollable, children: List(Node)) -> Scrollable {
  Scrollable(..s, children: list.append(s.children, children))
}

pub fn build(s: Scrollable) -> Node {
  let props =
    dict.new()
    |> build.put_optional("width", s.width, length.to_prop_value)
    |> build.put_optional("height", s.height, length.to_prop_value)
    |> build.put_optional("direction", s.direction, direction.to_prop_value)
    |> build.put_optional_int("spacing", s.spacing)
    |> build.put_optional_bool("on_scroll", s.on_scroll)
  Node(id: s.id, kind: "scrollable", props:, children: s.children)
}
