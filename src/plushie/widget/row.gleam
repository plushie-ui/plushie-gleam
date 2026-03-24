//// Row widget builder (horizontal layout).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/alignment.{type Alignment}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/widget/build

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

/// Create a new row builder.
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

/// Set the spacing between children.
pub fn spacing(row: Row, s: Int) -> Row {
  Row(..row, spacing: option.Some(s))
}

/// Set the padding.
pub fn padding(row: Row, p: Padding) -> Row {
  Row(..row, padding: option.Some(p))
}

/// Set the width.
pub fn width(row: Row, w: Length) -> Row {
  Row(..row, width: option.Some(w))
}

/// Set the height.
pub fn height(row: Row, h: Length) -> Row {
  Row(..row, height: option.Some(h))
}

/// Set the maximum width.
pub fn max_width(row: Row, m: Float) -> Row {
  Row(..row, max_width: option.Some(m))
}

/// Set the maximum height in pixels.
pub fn max_height(row: Row, m: Float) -> Row {
  Row(..row, max_height: option.Some(m))
}

/// Set the vertical alignment.
pub fn align_y(row: Row, a: Alignment) -> Row {
  Row(..row, align_y: option.Some(a))
}

/// Set whether overflowing content is clipped.
pub fn clip(row: Row, c: Bool) -> Row {
  Row(..row, clip: option.Some(c))
}

/// Set whether children wrap when they overflow.
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

/// Set accessibility properties for this widget.
pub fn a11y(row: Row, a: A11y) -> Row {
  Row(..row, a11y: option.Some(a))
}

/// Option type for row properties.
pub type Opt {
  Spacing(Int)
  Padding(Padding)
  Width(Length)
  Height(Length)
  MaxWidth(Float)
  MaxHeight(Float)
  AlignY(Alignment)
  Clip(Bool)
  Wrap(Bool)
  A11y(A11y)
}

/// Apply a list of options to a row builder.
pub fn with_opts(row: Row, opts: List(Opt)) -> Row {
  list.fold(opts, row, fn(r, opt) {
    case opt {
      Spacing(s) -> spacing(r, s)
      Padding(p) -> padding(r, p)
      Width(w) -> width(r, w)
      Height(h) -> height(r, h)
      MaxWidth(m) -> max_width(r, m)
      MaxHeight(m) -> max_height(r, m)
      AlignY(a) -> align_y(r, a)
      Clip(v) -> clip(r, v)
      Wrap(v) -> wrap(r, v)
      A11y(a) -> a11y(r, a)
    }
  })
}

/// Build the row into a renderable Node.
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
