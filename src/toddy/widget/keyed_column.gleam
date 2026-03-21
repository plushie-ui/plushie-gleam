//// Keyed column widget builder (column with keyed children for efficient diffing).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import toddy/node.{type Node, Node}
import toddy/prop/a11y.{type A11y}
import toddy/prop/alignment.{type Alignment}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/widget/build

pub opaque type KeyedColumn {
  KeyedColumn(
    id: String,
    children: List(Node),
    spacing: Option(Int),
    padding: Option(Padding),
    width: Option(Length),
    height: Option(Length),
    max_width: Option(Float),
    align_x: Option(Alignment),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> KeyedColumn {
  KeyedColumn(
    id:,
    children: [],
    spacing: None,
    padding: None,
    width: None,
    height: None,
    max_width: None,
    align_x: None,
    a11y: None,
  )
}

pub fn spacing(kc: KeyedColumn, s: Int) -> KeyedColumn {
  KeyedColumn(..kc, spacing: option.Some(s))
}

pub fn padding(kc: KeyedColumn, p: Padding) -> KeyedColumn {
  KeyedColumn(..kc, padding: option.Some(p))
}

pub fn width(kc: KeyedColumn, w: Length) -> KeyedColumn {
  KeyedColumn(..kc, width: option.Some(w))
}

pub fn height(kc: KeyedColumn, h: Length) -> KeyedColumn {
  KeyedColumn(..kc, height: option.Some(h))
}

pub fn max_width(kc: KeyedColumn, m: Float) -> KeyedColumn {
  KeyedColumn(..kc, max_width: option.Some(m))
}

pub fn align_x(kc: KeyedColumn, a: Alignment) -> KeyedColumn {
  KeyedColumn(..kc, align_x: option.Some(a))
}

/// Add a child node.
pub fn push(kc: KeyedColumn, child: Node) -> KeyedColumn {
  KeyedColumn(..kc, children: list.append(kc.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(kc: KeyedColumn, children: List(Node)) -> KeyedColumn {
  KeyedColumn(..kc, children: list.append(kc.children, children))
}

pub fn a11y(kc: KeyedColumn, a: A11y) -> KeyedColumn {
  KeyedColumn(..kc, a11y: option.Some(a))
}

pub fn build(kc: KeyedColumn) -> Node {
  let props =
    dict.new()
    |> build.put_optional_int("spacing", kc.spacing)
    |> build.put_optional("padding", kc.padding, padding.to_prop_value)
    |> build.put_optional("width", kc.width, length.to_prop_value)
    |> build.put_optional("height", kc.height, length.to_prop_value)
    |> build.put_optional_float("max_width", kc.max_width)
    |> build.put_optional("align_x", kc.align_x, alignment.to_prop_value)
    |> build.put_optional("a11y", kc.a11y, a11y.to_prop_value)
  Node(id: kc.id, kind: "keyed_column", props:, children: kc.children)
}
