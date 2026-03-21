import gleam/dict
import plushie/node.{IntVal, Node, StringVal}
import plushie/prop/alignment
import plushie/prop/length
import plushie/prop/padding
import plushie/widget/column

pub fn new_builds_empty_column_test() {
  let node = column.new("col") |> column.build()

  assert node.id == "col"
  assert node.kind == "column"
  assert node.children == []
  assert dict.is_empty(node.props)
}

pub fn spacing_sets_int_prop_test() {
  let node =
    column.new("col")
    |> column.spacing(8)
    |> column.build()

  assert dict.get(node.props, "spacing") == Ok(IntVal(8))
}

pub fn padding_sets_padding_prop_test() {
  let p = padding.xy(4.0, 8.0)
  let node =
    column.new("col")
    |> column.padding(p)
    |> column.build()

  assert dict.get(node.props, "padding") == Ok(padding.to_prop_value(p))
}

pub fn push_adds_child_test() {
  let child = Node(id: "c1", kind: "text", props: dict.new(), children: [])
  let node =
    column.new("col")
    |> column.push(child)
    |> column.build()

  assert node.children == [child]
}

pub fn extend_adds_multiple_children_test() {
  let c1 =
    Node(
      id: "c1",
      kind: "text",
      props: dict.from_list([#("content", StringVal("A"))]),
      children: [],
    )
  let c2 =
    Node(
      id: "c2",
      kind: "text",
      props: dict.from_list([#("content", StringVal("B"))]),
      children: [],
    )
  let node =
    column.new("col")
    |> column.extend([c1, c2])
    |> column.build()

  assert node.children == [c1, c2]
}

pub fn push_preserves_order_test() {
  let c1 = Node(id: "c1", kind: "text", props: dict.new(), children: [])
  let c2 = Node(id: "c2", kind: "text", props: dict.new(), children: [])
  let node =
    column.new("col")
    |> column.push(c1)
    |> column.push(c2)
    |> column.build()

  assert node.children == [c1, c2]
}

pub fn width_and_align_x_test() {
  let node =
    column.new("col")
    |> column.width(length.Fill)
    |> column.align_x(alignment.Center)
    |> column.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
  assert dict.get(node.props, "align_x")
    == Ok(alignment.to_prop_value(alignment.Center))
}
