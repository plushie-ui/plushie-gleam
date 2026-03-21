//// Column widget builder (vertical layout).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/alignment.{type Alignment}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/widget/build

pub opaque type Column {
  Column(
    id: String,
    children: List(Node),
    spacing: Option(Int),
    padding: Option(Padding),
    width: Option(Length),
    height: Option(Length),
    max_width: Option(Float),
    align_x: Option(Alignment),
    clip: Option(Bool),
    wrap: Option(Bool),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Column {
  Column(
    id:,
    children: [],
    spacing: None,
    padding: None,
    width: None,
    height: None,
    max_width: None,
    align_x: None,
    clip: None,
    wrap: None,
    a11y: None,
  )
}

pub fn spacing(col: Column, s: Int) -> Column {
  Column(..col, spacing: option.Some(s))
}

pub fn padding(col: Column, p: Padding) -> Column {
  Column(..col, padding: option.Some(p))
}

pub fn width(col: Column, w: Length) -> Column {
  Column(..col, width: option.Some(w))
}

pub fn height(col: Column, h: Length) -> Column {
  Column(..col, height: option.Some(h))
}

pub fn max_width(col: Column, m: Float) -> Column {
  Column(..col, max_width: option.Some(m))
}

pub fn align_x(col: Column, a: Alignment) -> Column {
  Column(..col, align_x: option.Some(a))
}

pub fn clip(col: Column, c: Bool) -> Column {
  Column(..col, clip: option.Some(c))
}

pub fn wrap(col: Column, w: Bool) -> Column {
  Column(..col, wrap: option.Some(w))
}

/// Add a child node.
pub fn push(col: Column, child: Node) -> Column {
  Column(..col, children: list.append(col.children, [child]))
}

/// Add multiple child nodes.
pub fn extend(col: Column, children: List(Node)) -> Column {
  Column(..col, children: list.append(col.children, children))
}

pub fn a11y(col: Column, a: A11y) -> Column {
  Column(..col, a11y: option.Some(a))
}

pub fn build(col: Column) -> Node {
  let props =
    dict.new()
    |> build.put_optional_int("spacing", col.spacing)
    |> build.put_optional("padding", col.padding, padding.to_prop_value)
    |> build.put_optional("width", col.width, length.to_prop_value)
    |> build.put_optional("height", col.height, length.to_prop_value)
    |> build.put_optional_float("max_width", col.max_width)
    |> build.put_optional("align_x", col.align_x, alignment.to_prop_value)
    |> build.put_optional_bool("clip", col.clip)
    |> build.put_optional_bool("wrap", col.wrap)
    |> build.put_optional("a11y", col.a11y, a11y.to_prop_value)
  Node(id: col.id, kind: "column", props:, children: col.children)
}
