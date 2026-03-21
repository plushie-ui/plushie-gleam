import gleam/dict
import gleam/list
import plushie/node.{BoolVal, DictVal, FloatVal, ListVal, StringVal}
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/widget/table

pub fn new_builds_minimal_table_test() {
  let node = table.new("tbl1") |> table.build()

  assert node.id == "tbl1"
  assert node.kind == "table"
  assert node.children == []
  assert dict.size(node.props) == 0
}

pub fn columns_encoded_as_list_of_dicts_test() {
  let c1 = table.column("name", "Name")
  let c2 =
    table.column("age", "Age")
    |> table.column_align("right")
    |> table.column_width(length.Fixed(80.0))
    |> table.column_sortable(True)

  let node =
    table.new("tbl2")
    |> table.columns([c1, c2])
    |> table.build()

  let assert Ok(ListVal(col_list)) = dict.get(node.props, "columns")
  assert list.length(col_list) == 2

  // First column: key + label only
  let assert [DictVal(first), _] = col_list
  assert dict.get(first, "key") == Ok(StringVal("name"))
  assert dict.get(first, "label") == Ok(StringVal("Name"))
  assert dict.get(first, "align") == Error(Nil)
  assert dict.get(first, "width") == Error(Nil)
  assert dict.get(first, "sortable") == Error(Nil)

  // Second column: all fields
  let assert [_, DictVal(second)] = col_list
  assert dict.get(second, "key") == Ok(StringVal("age"))
  assert dict.get(second, "label") == Ok(StringVal("Age"))
  assert dict.get(second, "align") == Ok(StringVal("right"))
  assert dict.get(second, "width")
    == Ok(length.to_prop_value(length.Fixed(80.0)))
  assert dict.get(second, "sortable") == Ok(BoolVal(True))
}

pub fn rows_encoded_as_list_of_dicts_test() {
  let row1 =
    dict.from_list([
      #("name", StringVal("Arthur")),
      #("age", StringVal("42")),
    ])
  let row2 =
    dict.from_list([
      #("name", StringVal("Ford")),
      #("age", StringVal("200")),
    ])

  let node =
    table.new("tbl3")
    |> table.rows([row1, row2])
    |> table.build()

  let assert Ok(ListVal(row_list)) = dict.get(node.props, "rows")
  assert list.length(row_list) == 2
  let assert [DictVal(first), _] = row_list
  assert dict.get(first, "name") == Ok(StringVal("Arthur"))
}

pub fn header_and_separator_booleans_test() {
  let node =
    table.new("tbl4")
    |> table.header(False)
    |> table.separator(True)
    |> table.build()

  assert dict.get(node.props, "header") == Ok(BoolVal(False))
  assert dict.get(node.props, "separator") == Ok(BoolVal(True))
}

pub fn sort_props_test() {
  let node =
    table.new("tbl5")
    |> table.sort_by("name")
    |> table.sort_order(table.Asc)
    |> table.build()

  assert dict.get(node.props, "sort_by") == Ok(StringVal("name"))
  assert dict.get(node.props, "sort_order") == Ok(StringVal("asc"))
}

pub fn sort_order_desc_test() {
  let node =
    table.new("tbl6")
    |> table.sort_order(table.Desc)
    |> table.build()

  assert dict.get(node.props, "sort_order") == Ok(StringVal("desc"))
}

pub fn numeric_props_test() {
  let node =
    table.new("tbl7")
    |> table.header_text_size(14.0)
    |> table.row_text_size(12.0)
    |> table.cell_spacing(8.0)
    |> table.row_spacing(4.0)
    |> table.separator_thickness(1.0)
    |> table.build()

  assert dict.get(node.props, "header_text_size") == Ok(FloatVal(14.0))
  assert dict.get(node.props, "row_text_size") == Ok(FloatVal(12.0))
  assert dict.get(node.props, "cell_spacing") == Ok(FloatVal(8.0))
  assert dict.get(node.props, "row_spacing") == Ok(FloatVal(4.0))
  assert dict.get(node.props, "separator_thickness") == Ok(FloatVal(1.0))
}

pub fn layout_props_test() {
  let node =
    table.new("tbl8")
    |> table.width(length.Fill)
    |> table.height(length.Fixed(400.0))
    |> table.padding(padding.all(10.0))
    |> table.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(400.0)))
  assert dict.get(node.props, "padding")
    == Ok(padding.to_prop_value(padding.all(10.0)))
}

pub fn separator_color_test() {
  let node =
    table.new("tbl9")
    |> table.separator_color(color.gray)
    |> table.build()

  assert dict.get(node.props, "separator_color")
    == Ok(color.to_prop_value(color.gray))
}

pub fn omitted_optionals_are_absent_test() {
  let node = table.new("tbl10") |> table.build()

  assert dict.get(node.props, "columns") == Error(Nil)
  assert dict.get(node.props, "rows") == Error(Nil)
  assert dict.get(node.props, "header") == Error(Nil)
  assert dict.get(node.props, "sort_by") == Error(Nil)
  assert dict.get(node.props, "header_text_size") == Error(Nil)
}

pub fn no_children_on_wire_test() {
  let node =
    table.new("tbl11")
    |> table.columns([table.column("k", "K")])
    |> table.build()

  assert node.children == []
}
