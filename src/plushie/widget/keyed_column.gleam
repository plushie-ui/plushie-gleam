//// Keyed column widget builder (column with keyed children for efficient diffing).

import gleam/dict
import gleam/list
import gleam/option.{type Option, None}
import plushie/node.{type Node, Node}
import plushie/prop/a11y.{type A11y}
import plushie/prop/alignment.{type Alignment}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/widget/build

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

/// Create a new keyed column builder.
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

/// Set the spacing between children.
pub fn spacing(kc: KeyedColumn, s: Int) -> KeyedColumn {
  KeyedColumn(..kc, spacing: option.Some(s))
}

/// Set the padding.
pub fn padding(kc: KeyedColumn, p: Padding) -> KeyedColumn {
  KeyedColumn(..kc, padding: option.Some(p))
}

/// Set the width.
pub fn width(kc: KeyedColumn, w: Length) -> KeyedColumn {
  KeyedColumn(..kc, width: option.Some(w))
}

/// Set the height.
pub fn height(kc: KeyedColumn, h: Length) -> KeyedColumn {
  KeyedColumn(..kc, height: option.Some(h))
}

/// Set the maximum width.
pub fn max_width(kc: KeyedColumn, m: Float) -> KeyedColumn {
  KeyedColumn(..kc, max_width: option.Some(m))
}

/// Set the horizontal alignment.
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

/// Set accessibility properties for this widget.
pub fn a11y(kc: KeyedColumn, a: A11y) -> KeyedColumn {
  KeyedColumn(..kc, a11y: option.Some(a))
}

/// Option type for keyed column properties.
pub type Opt {
  Spacing(Int)
  Padding(Padding)
  Width(Length)
  Height(Length)
  MaxWidth(Float)
  AlignX(Alignment)
  A11y(A11y)
}

/// Apply a list of options to a keyed column builder.
pub fn with_opts(kc: KeyedColumn, opts: List(Opt)) -> KeyedColumn {
  list.fold(opts, kc, fn(k, opt) {
    case opt {
      Spacing(s) -> spacing(k, s)
      Padding(p) -> padding(k, p)
      Width(w) -> width(k, w)
      Height(h) -> height(k, h)
      MaxWidth(m) -> max_width(k, m)
      AlignX(a) -> align_x(k, a)
      A11y(a) -> a11y(k, a)
    }
  })
}

/// Build the keyed column into a renderable Node.
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
