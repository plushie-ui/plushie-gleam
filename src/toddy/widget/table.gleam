//// Table widget builder. Children are column definitions.

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/widget/build

pub opaque type Table {
  Table(
    id: String,
    children: List(Node),
    width: Option(Length),
    height: Option(Length),
    spacing: Option(Int),
    padding: Option(Padding),
  )
}

pub fn new(id: String) -> Table {
  Table(
    id:,
    children: [],
    width: None,
    height: None,
    spacing: None,
    padding: None,
  )
}

pub fn width(t: Table, w: Length) -> Table {
  Table(..t, width: option.Some(w))
}

pub fn height(t: Table, h: Length) -> Table {
  Table(..t, height: option.Some(h))
}

pub fn spacing(t: Table, s: Int) -> Table {
  Table(..t, spacing: option.Some(s))
}

pub fn padding(t: Table, p: Padding) -> Table {
  Table(..t, padding: option.Some(p))
}

/// Add a child node (column definition).
pub fn push(t: Table, child: Node) -> Table {
  Table(..t, children: list.append(t.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(t: Table, children: List(Node)) -> Table {
  Table(..t, children: list.append(t.children, children))
}

pub fn build(t: Table) -> Node {
  let props =
    dict.new()
    |> build.put_optional("width", t.width, length.to_prop_value)
    |> build.put_optional("height", t.height, length.to_prop_value)
    |> build.put_optional_int("spacing", t.spacing)
    |> build.put_optional("padding", t.padding, padding.to_prop_value)
  Node(id: t.id, kind: "table", props:, children: t.children)
}
