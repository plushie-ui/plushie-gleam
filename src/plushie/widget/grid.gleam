//// Grid layout widget builder.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/widget/build

pub opaque type Grid {
  Grid(
    id: String,
    children: List(Node),
    columns: Option(Int),
    column_count: Option(Int),
    spacing: Option(Int),
    padding: Option(Padding),
    width: Option(Length),
    height: Option(Length),
    column_width: Option(Length),
    row_height: Option(Length),
    fluid: Option(Float),
    a11y: Option(A11y),
  )
}

/// Create a new grid builder.
pub fn new(id: String) -> Grid {
  Grid(
    id:,
    children: [],
    columns: None,
    column_count: None,
    spacing: None,
    padding: None,
    width: None,
    height: None,
    column_width: None,
    row_height: None,
    fluid: None,
    a11y: None,
  )
}

/// Set the number of columns.
pub fn columns(g: Grid, n: Int) -> Grid {
  Grid(..g, columns: option.Some(n))
}

/// Set the count on a column definition.
pub fn column_count(g: Grid, n: Int) -> Grid {
  Grid(..g, column_count: option.Some(n))
}

/// Set the spacing between children.
pub fn spacing(g: Grid, s: Int) -> Grid {
  Grid(..g, spacing: option.Some(s))
}

/// Set the padding.
pub fn padding(g: Grid, p: Padding) -> Grid {
  Grid(..g, padding: option.Some(p))
}

/// Set the width.
pub fn width(g: Grid, w: Length) -> Grid {
  Grid(..g, width: option.Some(w))
}

/// Set the height.
pub fn height(g: Grid, h: Length) -> Grid {
  Grid(..g, height: option.Some(h))
}

/// Set the width on a column definition.
pub fn column_width(g: Grid, w: Length) -> Grid {
  Grid(..g, column_width: option.Some(w))
}

/// Set the height of each row.
pub fn row_height(g: Grid, h: Length) -> Grid {
  Grid(..g, row_height: option.Some(h))
}

/// Enable fluid mode with the given max cell width.
pub fn fluid(g: Grid, max_cell_width: Float) -> Grid {
  Grid(..g, fluid: option.Some(max_cell_width))
}

/// Add a child node.
pub fn push(g: Grid, child: Node) -> Grid {
  Grid(..g, children: list.append(g.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(g: Grid, children: List(Node)) -> Grid {
  Grid(..g, children: list.append(g.children, children))
}

/// Set accessibility properties for this widget.
pub fn a11y(g: Grid, a: A11y) -> Grid {
  Grid(..g, a11y: option.Some(a))
}

/// Option type for grid properties.
pub type Opt {
  Columns(Int)
  ColumnCount(Int)
  Spacing(Int)
  Padding(Padding)
  Width(Length)
  Height(Length)
  ColumnWidth(Length)
  RowHeight(Length)
  Fluid(Float)
  A11y(A11y)
}

/// Apply a list of options to a grid builder.
pub fn with_opts(g: Grid, opts: List(Opt)) -> Grid {
  list.fold(opts, g, fn(gr, opt) {
    case opt {
      Columns(n) -> columns(gr, n)
      ColumnCount(n) -> column_count(gr, n)
      Spacing(s) -> spacing(gr, s)
      Padding(p) -> padding(gr, p)
      Width(w) -> width(gr, w)
      Height(h) -> height(gr, h)
      ColumnWidth(w) -> column_width(gr, w)
      RowHeight(h) -> row_height(gr, h)
      Fluid(v) -> fluid(gr, v)
      A11y(a) -> a11y(gr, a)
    }
  })
}

/// Build the grid into a renderable Node.
pub fn build(g: Grid) -> Node {
  let props =
    dict.new()
    |> build.put_optional_int("columns", g.columns)
    |> build.put_optional_int("column_count", g.column_count)
    |> build.put_optional_int("spacing", g.spacing)
    |> build.put_optional("padding", g.padding, padding.to_prop_value)
    |> build.put_optional("width", g.width, length.to_prop_value)
    |> build.put_optional("height", g.height, length.to_prop_value)
    |> build.put_optional("column_width", g.column_width, length.to_prop_value)
    |> build.put_optional("row_height", g.row_height, length.to_prop_value)
    |> build.put_optional_float("fluid", g.fluid)
    |> build.put_optional("a11y", g.a11y, a11y.to_prop_value)
  Node(id: g.id, kind: "grid", props:, children: g.children)
}
