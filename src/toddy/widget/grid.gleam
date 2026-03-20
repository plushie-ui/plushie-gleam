//// Grid layout widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/widget/build

pub opaque type Grid {
  Grid(
    id: String,
    children: List(Node),
    column_count: Option(Int),
    spacing: Option(Int),
    padding: Option(Padding),
    width: Option(Length),
  )
}

pub fn new(id: String) -> Grid {
  Grid(
    id:,
    children: [],
    column_count: None,
    spacing: None,
    padding: None,
    width: None,
  )
}

pub fn column_count(g: Grid, n: Int) -> Grid {
  Grid(..g, column_count: option.Some(n))
}

pub fn spacing(g: Grid, s: Int) -> Grid {
  Grid(..g, spacing: option.Some(s))
}

pub fn padding(g: Grid, p: Padding) -> Grid {
  Grid(..g, padding: option.Some(p))
}

pub fn width(g: Grid, w: Length) -> Grid {
  Grid(..g, width: option.Some(w))
}

/// Add a child node.
pub fn push(g: Grid, child: Node) -> Grid {
  Grid(..g, children: list.append(g.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(g: Grid, children: List(Node)) -> Grid {
  Grid(..g, children: list.append(g.children, children))
}

pub fn build(g: Grid) -> Node {
  let props =
    dict.new()
    |> build.put_optional_int("column_count", g.column_count)
    |> build.put_optional_int("spacing", g.spacing)
    |> build.put_optional("padding", g.padding, padding.to_prop_value)
    |> build.put_optional("width", g.width, length.to_prop_value)
  Node(id: g.id, kind: "grid", props:, children: g.children)
}
