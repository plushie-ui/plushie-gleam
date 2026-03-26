import gleam/dict
import plushie/node.{IntVal, Node}
import plushie/prop/alignment
import plushie/prop/length
import plushie/widget/row

pub fn new_builds_empty_row_test() {
  let node = row.new("r") |> row.build()

  assert node.id == "r"
  assert node.kind == "row"
  assert node.children == []
  assert dict.is_empty(node.props)
}

pub fn spacing_sets_int_prop_test() {
  let node =
    row.new("r")
    |> row.spacing(12)
    |> row.build()

  assert dict.get(node.props, "spacing") == Ok(IntVal(12))
}

pub fn push_adds_child_test() {
  let child =
    Node(
      id: "c1",
      kind: "text",
      props: dict.new(),
      children: [],
      meta: dict.new(),
    )
  let node =
    row.new("r")
    |> row.push(child)
    |> row.build()

  assert node.children == [child]
}

pub fn extend_adds_multiple_children_test() {
  let c1 =
    Node(
      id: "c1",
      kind: "text",
      props: dict.new(),
      children: [],
      meta: dict.new(),
    )
  let c2 =
    Node(
      id: "c2",
      kind: "text",
      props: dict.new(),
      children: [],
      meta: dict.new(),
    )
  let node =
    row.new("r")
    |> row.extend([c1, c2])
    |> row.build()

  assert node.children == [c1, c2]
}

pub fn align_y_and_height_test() {
  let node =
    row.new("r")
    |> row.align_y(alignment.Center)
    |> row.height(length.Shrink)
    |> row.build()

  assert dict.get(node.props, "align_y")
    == Ok(alignment.to_prop_value(alignment.Center))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Shrink))
}
