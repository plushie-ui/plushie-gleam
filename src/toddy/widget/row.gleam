//// Row widget builder (horizontal layout).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/alignment.{type Alignment}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/widget/build

pub opaque type Row {
  Row(
    id: String,
    children: List(Node),
    spacing: Option(Int),
    padding: Option(Padding),
    width: Option(Length),
    height: Option(Length),
    max_width: Option(Float),
    max_height: Option(Float),
    align_y: Option(Alignment),
    clip: Option(Bool),
    wrap: Option(Bool),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Row {
  Row(
    id:,
    children: [],
    spacing: None,
    padding: None,
    width: None,
    height: None,
    max_width: None,
    max_height: None,
    align_y: None,
    clip: None,
    wrap: None,
    a11y: None,
  )
}

pub fn spacing(row: Row, s: Int) -> Row {
  Row(..row, spacing: option.Some(s))
}

pub fn padding(row: Row, p: Padding) -> Row {
  Row(..row, padding: option.Some(p))
}

pub fn width(row: Row, w: Length) -> Row {
  Row(..row, width: option.Some(w))
}

pub fn height(row: Row, h: Length) -> Row {
  Row(..row, height: option.Some(h))
}

pub fn max_width(row: Row, m: Float) -> Row {
  Row(..row, max_width: option.Some(m))
}

pub fn max_height(row: Row, m: Float) -> Row {
  Row(..row, max_height: option.Some(m))
}

pub fn align_y(row: Row, a: Alignment) -> Row {
  Row(..row, align_y: option.Some(a))
}

pub fn clip(row: Row, c: Bool) -> Row {
  Row(..row, clip: option.Some(c))
}

pub fn wrap(row: Row, w: Bool) -> Row {
  Row(..row, wrap: option.Some(w))
}

/// Add a child node.
pub fn push(row: Row, child: Node) -> Row {
  Row(..row, children: list.append(row.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(row: Row, children: List(Node)) -> Row {
  Row(..row, children: list.append(row.children, children))
}

pub fn a11y(row: Row, a: A11y) -> Row {
  Row(..row, a11y: option.Some(a))
}

pub fn build(row: Row) -> Node {
  let props =
    dict.new()
    |> build.put_optional_int("spacing", row.spacing)
    |> build.put_optional("padding", row.padding, padding.to_prop_value)
    |> build.put_optional("width", row.width, length.to_prop_value)
    |> build.put_optional("height", row.height, length.to_prop_value)
    |> build.put_optional_float("max_width", row.max_width)
    |> build.put_optional_float("max_height", row.max_height)
    |> build.put_optional("align_y", row.align_y, alignment.to_prop_value)
    |> build.put_optional_bool("clip", row.clip)
    |> build.put_optional_bool("wrap", row.wrap)
    |> build.put_optional("a11y", row.a11y, a11y.to_prop_value)
  Node(id: row.id, kind: "row", props:, children: row.children)
}
