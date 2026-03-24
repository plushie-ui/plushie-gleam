//// PaneGrid widget for resizable tiled pane layouts.
////
//// Children are keyed by their node ID. The Rust binary manages
//// pane layout state; use PaneSplit/PaneClose/PaneSwap commands
//// to modify the layout.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, ListVal, Node, StringVal}
import plushie/prop/a11y.{type A11y}
import plushie/prop/length.{type Length}
import plushie/widget/build

pub opaque type PaneGrid {
  PaneGrid(
    id: String,
    children: List(Node),
    panes: Option(List(String)),
    spacing: Option(Int),
    width: Option(Length),
    height: Option(Length),
    min_size: Option(Float),
    divider_color: Option(String),
    divider_width: Option(Float),
    leeway: Option(Float),
    event_rate: Option(Int),
    a11y: Option(A11y),
  )
}

/// Create a new pane grid builder.
pub fn new(id: String) -> PaneGrid {
  PaneGrid(
    id:,
    children: [],
    panes: None,
    spacing: None,
    width: None,
    height: None,
    min_size: None,
    divider_color: None,
    divider_width: None,
    leeway: None,
    event_rate: None,
    a11y: None,
  )
}

/// Set the pane IDs.
pub fn panes(pg: PaneGrid, p: List(String)) -> PaneGrid {
  PaneGrid(..pg, panes: option.Some(p))
}

/// Set the spacing between children.
pub fn spacing(pg: PaneGrid, s: Int) -> PaneGrid {
  PaneGrid(..pg, spacing: option.Some(s))
}

/// Set the width.
pub fn width(pg: PaneGrid, w: Length) -> PaneGrid {
  PaneGrid(..pg, width: option.Some(w))
}

/// Set the height.
pub fn height(pg: PaneGrid, h: Length) -> PaneGrid {
  PaneGrid(..pg, height: option.Some(h))
}

/// Set the minimum size.
pub fn min_size(pg: PaneGrid, s: Float) -> PaneGrid {
  PaneGrid(..pg, min_size: option.Some(s))
}

/// Set the divider color.
pub fn divider_color(pg: PaneGrid, c: String) -> PaneGrid {
  PaneGrid(..pg, divider_color: option.Some(c))
}

/// Set the divider width.
pub fn divider_width(pg: PaneGrid, w: Float) -> PaneGrid {
  PaneGrid(..pg, divider_width: option.Some(w))
}

/// Set the resize handle leeway in pixels.
pub fn leeway(pg: PaneGrid, l: Float) -> PaneGrid {
  PaneGrid(..pg, leeway: option.Some(l))
}

/// Set the event throttle rate in milliseconds.
pub fn event_rate(pg: PaneGrid, rate: Int) -> PaneGrid {
  PaneGrid(..pg, event_rate: option.Some(rate))
}

/// Add a child pane node.
pub fn push(pg: PaneGrid, child: Node) -> PaneGrid {
  PaneGrid(..pg, children: list.append(pg.children, [child]))
}

/// Add multiple child pane nodes.
pub fn extend(pg: PaneGrid, children: List(Node)) -> PaneGrid {
  PaneGrid(..pg, children: list.append(pg.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(pg: PaneGrid, a: A11y) -> PaneGrid {
  PaneGrid(..pg, a11y: option.Some(a))
}

/// Option type for pane grid properties.
pub type Opt {
  Panes(List(String))
  Spacing(Int)
  Width(Length)
  Height(Length)
  MinSize(Float)
  DividerColor(String)
  DividerWidth(Float)
  Leeway(Float)
  EventRate(Int)
  A11y(A11y)
}

/// Apply a list of options to a pane grid builder.
pub fn with_opts(pg: PaneGrid, opts: List(Opt)) -> PaneGrid {
  list.fold(opts, pg, fn(p, opt) {
    case opt {
      Panes(v) -> panes(p, v)
      Spacing(s) -> spacing(p, s)
      Width(w) -> width(p, w)
      Height(h) -> height(p, h)
      MinSize(s) -> min_size(p, s)
      DividerColor(c) -> divider_color(p, c)
      DividerWidth(w) -> divider_width(p, w)
      Leeway(l) -> leeway(p, l)
      EventRate(r) -> event_rate(p, r)
      A11y(a) -> a11y(p, a)
    }
  })
}

/// Build the pane grid into a renderable Node.
pub fn build(pg: PaneGrid) -> Node {
  let props =
    dict.new()
    |> build.put_optional("panes", pg.panes, fn(p) {
      ListVal(list.map(p, StringVal))
    })
    |> build.put_optional_int("spacing", pg.spacing)
    |> build.put_optional("width", pg.width, length.to_prop_value)
    |> build.put_optional("height", pg.height, length.to_prop_value)
    |> build.put_optional_float("min_size", pg.min_size)
    |> build.put_optional_string("divider_color", pg.divider_color)
    |> build.put_optional_float("divider_width", pg.divider_width)
    |> build.put_optional_float("leeway", pg.leeway)
    |> build.put_optional_int("event_rate", pg.event_rate)
    |> build.put_optional("a11y", pg.a11y, a11y.to_prop_value)
  Node(id: pg.id, kind: "pane_grid", props:, children: pg.children)
}
