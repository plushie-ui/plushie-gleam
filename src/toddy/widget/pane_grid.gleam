//// PaneGrid widget for resizable tiled pane layouts.
////
//// Children are keyed by their node ID. The Rust binary manages
//// pane layout state; use PaneSplit/PaneClose/PaneSwap commands
//// to modify the layout.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/length.{type Length}
import toddy/widget/build

pub opaque type PaneGrid {
  PaneGrid(
    id: String,
    children: List(Node),
    spacing: Option(Int),
    width: Option(Length),
    height: Option(Length),
    min_size: Option(Float),
    divider_color: Option(String),
    divider_width: Option(Float),
    leeway: Option(Float),
  )
}

pub fn new(id: String) -> PaneGrid {
  PaneGrid(
    id:,
    children: [],
    spacing: None,
    width: None,
    height: None,
    min_size: None,
    divider_color: None,
    divider_width: None,
    leeway: None,
  )
}

pub fn spacing(pg: PaneGrid, s: Int) -> PaneGrid {
  PaneGrid(..pg, spacing: option.Some(s))
}

pub fn width(pg: PaneGrid, w: Length) -> PaneGrid {
  PaneGrid(..pg, width: option.Some(w))
}

pub fn height(pg: PaneGrid, h: Length) -> PaneGrid {
  PaneGrid(..pg, height: option.Some(h))
}

pub fn min_size(pg: PaneGrid, s: Float) -> PaneGrid {
  PaneGrid(..pg, min_size: option.Some(s))
}

pub fn divider_color(pg: PaneGrid, c: String) -> PaneGrid {
  PaneGrid(..pg, divider_color: option.Some(c))
}

pub fn divider_width(pg: PaneGrid, w: Float) -> PaneGrid {
  PaneGrid(..pg, divider_width: option.Some(w))
}

pub fn leeway(pg: PaneGrid, l: Float) -> PaneGrid {
  PaneGrid(..pg, leeway: option.Some(l))
}

/// Add a child pane node.
pub fn push(pg: PaneGrid, child: Node) -> PaneGrid {
  PaneGrid(..pg, children: list.append(pg.children, [child]))
}

/// Add multiple child pane nodes.
pub fn extend(pg: PaneGrid, children: List(Node)) -> PaneGrid {
  PaneGrid(..pg, children: list.append(pg.children, children))
}

pub fn build(pg: PaneGrid) -> Node {
  let props =
    dict.new()
    |> build.put_optional_int("spacing", pg.spacing)
    |> build.put_optional("width", pg.width, length.to_prop_value)
    |> build.put_optional("height", pg.height, length.to_prop_value)
    |> build.put_optional_float("min_size", pg.min_size)
    |> build.put_optional_string("divider_color", pg.divider_color)
    |> build.put_optional_float("divider_width", pg.divider_width)
    |> build.put_optional_float("leeway", pg.leeway)
  Node(id: pg.id, kind: "pane_grid", props:, children: pg.children)
}
