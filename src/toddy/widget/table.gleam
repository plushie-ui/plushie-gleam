//// Table widget builder. Data table with typed columns and row maps.
////
//// Columns and rows are encoded as props (list of maps), not as child nodes.
//// The Rust renderer expects this structure.

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import toddy/node.{
  type Node, type PropValue, BoolVal, DictVal, ListVal, Node, StringVal,
}
import toddy/prop/a11y.{type A11y}
import toddy/prop/color.{type Color}
import toddy/prop/length.{type Length}
import toddy/prop/padding.{type Padding}
import toddy/widget/build

// --- Column ------------------------------------------------------------------

/// A table column definition.
pub type Column {
  Column(
    key: String,
    label: String,
    align: Option(String),
    width: Option(Length),
    sortable: Option(Bool),
  )
}

/// Create a column with a key and display label.
pub fn column(key: String, label: String) -> Column {
  Column(key:, label:, align: None, width: None, sortable: None)
}

pub fn column_align(c: Column, align: String) -> Column {
  Column(..c, align: Some(align))
}

pub fn column_width(c: Column, w: Length) -> Column {
  Column(..c, width: Some(w))
}

pub fn column_sortable(c: Column, s: Bool) -> Column {
  Column(..c, sortable: Some(s))
}

/// Encode a column to a PropValue dict.
pub fn column_to_prop_value(c: Column) -> PropValue {
  let fields =
    dict.from_list([
      #("key", StringVal(c.key)),
      #("label", StringVal(c.label)),
    ])
  let fields = case c.align {
    Some(a) -> dict.insert(fields, "align", StringVal(a))
    None -> fields
  }
  let fields = case c.width {
    Some(w) -> dict.insert(fields, "width", length.to_prop_value(w))
    None -> fields
  }
  let fields = case c.sortable {
    Some(s) -> dict.insert(fields, "sortable", BoolVal(s))
    None -> fields
  }
  DictVal(fields)
}

// --- SortOrder ---------------------------------------------------------------

pub type SortOrder {
  Asc
  Desc
}

fn sort_order_to_prop_value(order: SortOrder) -> PropValue {
  case order {
    Asc -> StringVal("asc")
    Desc -> StringVal("desc")
  }
}

// --- Row encoding ------------------------------------------------------------

/// Encode a row (string-keyed dict of PropValues) to a PropValue dict.
fn row_to_prop_value(row: Dict(String, PropValue)) -> PropValue {
  DictVal(row)
}

// --- Table -------------------------------------------------------------------

pub opaque type Table {
  Table(
    id: String,
    columns: Option(List(Column)),
    rows: Option(List(Dict(String, PropValue))),
    header: Option(Bool),
    separator: Option(Bool),
    width: Option(Length),
    height: Option(Length),
    padding: Option(Padding),
    sort_by: Option(String),
    sort_order: Option(SortOrder),
    header_text_size: Option(Float),
    row_text_size: Option(Float),
    cell_spacing: Option(Float),
    row_spacing: Option(Float),
    separator_thickness: Option(Float),
    separator_color: Option(Color),
    a11y: Option(A11y),
  )
}

pub fn new(id: String) -> Table {
  Table(
    id:,
    columns: None,
    rows: None,
    header: None,
    separator: None,
    width: None,
    height: None,
    padding: None,
    sort_by: None,
    sort_order: None,
    header_text_size: None,
    row_text_size: None,
    cell_spacing: None,
    row_spacing: None,
    separator_thickness: None,
    separator_color: None,
    a11y: None,
  )
}

pub fn columns(t: Table, cols: List(Column)) -> Table {
  Table(..t, columns: Some(cols))
}

pub fn rows(t: Table, r: List(Dict(String, PropValue))) -> Table {
  Table(..t, rows: Some(r))
}

pub fn header(t: Table, h: Bool) -> Table {
  Table(..t, header: Some(h))
}

pub fn separator(t: Table, s: Bool) -> Table {
  Table(..t, separator: Some(s))
}

pub fn width(t: Table, w: Length) -> Table {
  Table(..t, width: Some(w))
}

pub fn height(t: Table, h: Length) -> Table {
  Table(..t, height: Some(h))
}

pub fn padding(t: Table, p: Padding) -> Table {
  Table(..t, padding: Some(p))
}

pub fn sort_by(t: Table, key: String) -> Table {
  Table(..t, sort_by: Some(key))
}

pub fn sort_order(t: Table, order: SortOrder) -> Table {
  Table(..t, sort_order: Some(order))
}

pub fn header_text_size(t: Table, s: Float) -> Table {
  Table(..t, header_text_size: Some(s))
}

pub fn row_text_size(t: Table, s: Float) -> Table {
  Table(..t, row_text_size: Some(s))
}

pub fn cell_spacing(t: Table, s: Float) -> Table {
  Table(..t, cell_spacing: Some(s))
}

pub fn row_spacing(t: Table, s: Float) -> Table {
  Table(..t, row_spacing: Some(s))
}

pub fn separator_thickness(t: Table, s: Float) -> Table {
  Table(..t, separator_thickness: Some(s))
}

pub fn separator_color(t: Table, c: Color) -> Table {
  Table(..t, separator_color: Some(c))
}

pub fn a11y(t: Table, a: A11y) -> Table {
  Table(..t, a11y: Some(a))
}

pub fn build(t: Table) -> Node {
  let props =
    dict.new()
    |> build.put_optional("columns", t.columns, fn(cols) {
      ListVal(list.map(cols, column_to_prop_value))
    })
    |> build.put_optional("rows", t.rows, fn(row_list) {
      ListVal(list.map(row_list, row_to_prop_value))
    })
    |> build.put_optional_bool("header", t.header)
    |> build.put_optional_bool("separator", t.separator)
    |> build.put_optional("width", t.width, length.to_prop_value)
    |> build.put_optional("height", t.height, length.to_prop_value)
    |> build.put_optional("padding", t.padding, padding.to_prop_value)
    |> build.put_optional_string("sort_by", t.sort_by)
    |> build.put_optional("sort_order", t.sort_order, sort_order_to_prop_value)
    |> build.put_optional_float("header_text_size", t.header_text_size)
    |> build.put_optional_float("row_text_size", t.row_text_size)
    |> build.put_optional_float("cell_spacing", t.cell_spacing)
    |> build.put_optional_float("row_spacing", t.row_spacing)
    |> build.put_optional_float("separator_thickness", t.separator_thickness)
    |> build.put_optional(
      "separator_color",
      t.separator_color,
      color.to_prop_value,
    )
    |> build.put_optional("a11y", t.a11y, a11y.to_prop_value)
  Node(id: t.id, kind: "table", props:, children: [])
}
