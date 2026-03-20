import gleam/dict
import toddy/node.{BoolVal, IntVal, Node, StringVal}
import toddy/prop/direction
import toddy/prop/length
import toddy/widget/scrollable

pub fn new_builds_empty_scrollable_test() {
  let node = scrollable.new("scroll") |> scrollable.build()

  assert node.id == "scroll"
  assert node.kind == "scrollable"
  assert node.children == []
  assert dict.is_empty(node.props)
}

pub fn width_and_height_set_length_props_test() {
  let node =
    scrollable.new("scroll")
    |> scrollable.width(length.Fill)
    |> scrollable.height(length.Fixed(400.0))
    |> scrollable.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(400.0)))
}

pub fn direction_sets_direction_prop_test() {
  let node =
    scrollable.new("scroll")
    |> scrollable.direction(direction.Vertical)
    |> scrollable.build()

  assert dict.get(node.props, "direction")
    == Ok(direction.to_prop_value(direction.Vertical))
}

pub fn direction_horizontal_test() {
  let node =
    scrollable.new("scroll")
    |> scrollable.direction(direction.Horizontal)
    |> scrollable.build()

  assert dict.get(node.props, "direction")
    == Ok(direction.to_prop_value(direction.Horizontal))
}

pub fn direction_both_test() {
  let node =
    scrollable.new("scroll")
    |> scrollable.direction(direction.Both)
    |> scrollable.build()

  assert dict.get(node.props, "direction")
    == Ok(direction.to_prop_value(direction.Both))
}

pub fn spacing_sets_int_prop_test() {
  let node =
    scrollable.new("scroll")
    |> scrollable.spacing(8)
    |> scrollable.build()

  assert dict.get(node.props, "spacing") == Ok(IntVal(8))
}

pub fn on_scroll_sets_bool_prop_test() {
  let node =
    scrollable.new("scroll")
    |> scrollable.on_scroll(True)
    |> scrollable.build()

  assert dict.get(node.props, "on_scroll") == Ok(BoolVal(True))
}

pub fn push_adds_child_test() {
  let child = Node(id: "item", kind: "text", props: dict.new(), children: [])
  let node =
    scrollable.new("scroll")
    |> scrollable.push(child)
    |> scrollable.build()

  assert node.children == [child]
}

pub fn extend_adds_multiple_children_test() {
  let c1 = Node(id: "c1", kind: "text", props: dict.new(), children: [])
  let c2 = Node(id: "c2", kind: "text", props: dict.new(), children: [])
  let node =
    scrollable.new("scroll")
    |> scrollable.extend([c1, c2])
    |> scrollable.build()

  assert node.children == [c1, c2]
}

pub fn push_preserves_order_test() {
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
    scrollable.new("scroll")
    |> scrollable.push(c1)
    |> scrollable.push(c2)
    |> scrollable.build()

  assert node.children == [c1, c2]
}

pub fn omitted_optionals_are_absent_test() {
  let node = scrollable.new("scroll") |> scrollable.build()

  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "height") == Error(Nil)
  assert dict.get(node.props, "direction") == Error(Nil)
  assert dict.get(node.props, "spacing") == Error(Nil)
  assert dict.get(node.props, "on_scroll") == Error(Nil)
}
