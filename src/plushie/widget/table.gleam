//// Table widget builder. Data table with typed columns and row maps.
////
//// Columns and rows are encoded as props (list of maps), not as child nodes.
//// The Rust renderer expects this structure.

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import plushie/node.{
  type Node, type PropValue, BoolVal, DictVal, ListVal, Node, StringVal,
}
import plushie/prop/a11y.{type A11y}
import plushie/prop/color.{type Color}
import plushie/prop/length.{type Length}
import plushie/prop/padding.{type Padding}
import plushie/widget/build

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

/// Set the column text alignment.
pub fn column_align(c: Column, align: String) -> Column {
  Column(..c, align: Some(align))
}

/// Set the column width.
pub fn column_width(c: Column, w: Length) -> Column {
  Column(..c, width: Some(w))
}

/// Set whether the column is sortable.
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

/// Create a new table builder.
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

/// Set the number of columns.
pub fn columns(t: Table, cols: List(Column)) -> Table {
  Table(..t, columns: Some(cols))
}

/// Set the table rows.
pub fn rows(t: Table, r: List(Dict(String, PropValue))) -> Table {
  Table(..t, rows: Some(r))
}

/// Set whether the header row is shown.
pub fn header(t: Table, h: Bool) -> Table {
  Table(..t, header: Some(h))
}

/// Set whether row separators are shown.
pub fn separator(t: Table, s: Bool) -> Table {
  Table(..t, separator: Some(s))
}

/// Set the width.
pub fn width(t: Table, w: Length) -> Table {
  Table(..t, width: Some(w))
}

/// Set the height.
pub fn height(t: Table, h: Length) -> Table {
  Table(..t, height: Some(h))
}

/// Set the padding.
pub fn padding(t: Table, p: Padding) -> Table {
  Table(..t, padding: Some(p))
}

/// Set the column key to sort by.
pub fn sort_by(t: Table, key: String) -> Table {
  Table(..t, sort_by: Some(key))
}

/// Set the sort order.
pub fn sort_order(t: Table, order: SortOrder) -> Table {
  Table(..t, sort_order: Some(order))
}

/// Set the header text size.
pub fn header_text_size(t: Table, s: Float) -> Table {
  Table(..t, header_text_size: Some(s))
}

/// Set the row text size.
pub fn row_text_size(t: Table, s: Float) -> Table {
  Table(..t, row_text_size: Some(s))
}

/// Set the horizontal spacing between cells.
pub fn cell_spacing(t: Table, s: Float) -> Table {
  Table(..t, cell_spacing: Some(s))
}

/// Set the vertical spacing between rows.
pub fn row_spacing(t: Table, s: Float) -> Table {
  Table(..t, row_spacing: Some(s))
}

/// Set the separator line thickness.
pub fn separator_thickness(t: Table, s: Float) -> Table {
  Table(..t, separator_thickness: Some(s))
}

/// Set the separator line color.
pub fn separator_color(t: Table, c: Color) -> Table {
  Table(..t, separator_color: Some(c))
}

/// Set accessibility properties for this widget.
pub fn a11y(t: Table, a: A11y) -> Table {
  Table(..t, a11y: Some(a))
}

/// Option type for table properties.
pub type Opt {
  Columns(List(Column))
  Rows(List(Dict(String, PropValue)))
  Header(Bool)
  Separator(Bool)
  Width(Length)
  Height(Length)
  Padding(Padding)
  SortBy(String)
  SortOrder(SortOrder)
  HeaderTextSize(Float)
  RowTextSize(Float)
  CellSpacing(Float)
  RowSpacing(Float)
  SeparatorThickness(Float)
  SeparatorColor(Color)
  A11y(A11y)
}

/// Apply a list of options to a table builder.
pub fn with_opts(t: Table, opts: List(Opt)) -> Table {
  list.fold(opts, t, fn(tb, opt) {
    case opt {
      Columns(cols) -> columns(tb, cols)
      Rows(r) -> rows(tb, r)
      Header(h) -> header(tb, h)
      Separator(s) -> separator(tb, s)
      Width(w) -> width(tb, w)
      Height(h) -> height(tb, h)
      Padding(p) -> padding(tb, p)
      SortBy(key) -> sort_by(tb, key)
      SortOrder(order) -> sort_order(tb, order)
      HeaderTextSize(s) -> header_text_size(tb, s)
      RowTextSize(s) -> row_text_size(tb, s)
      CellSpacing(s) -> cell_spacing(tb, s)
      RowSpacing(s) -> row_spacing(tb, s)
      SeparatorThickness(s) -> separator_thickness(tb, s)
      SeparatorColor(c) -> separator_color(tb, c)
      A11y(a) -> a11y(tb, a)
    }
  })
}

/// Build the table into a renderable Node.
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
  Node(id: t.id, kind: "table", props:, children: [], meta: dict.new())
}
