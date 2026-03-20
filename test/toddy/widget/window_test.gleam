import gleam/dict
import toddy/node.{BoolVal, FloatVal, Node, StringVal}
import toddy/widget/window

pub fn new_builds_empty_window_test() {
  let node = window.new("main") |> window.build()

  assert node.id == "main"
  assert node.kind == "window"
  assert node.children == []
  assert dict.is_empty(node.props)
}

pub fn title_sets_string_prop_test() {
  let node =
    window.new("main")
    |> window.title("My App")
    |> window.build()

  assert dict.get(node.props, "title") == Ok(StringVal("My App"))
}

pub fn size_sets_width_and_height_test() {
  let node =
    window.new("main")
    |> window.size(800.0, 600.0)
    |> window.build()

  assert dict.get(node.props, "width") == Ok(FloatVal(800.0))
  assert dict.get(node.props, "height") == Ok(FloatVal(600.0))
}

pub fn exit_on_close_request_test() {
  let node =
    window.new("main")
    |> window.exit_on_close_request(True)
    |> window.build()

  assert dict.get(node.props, "exit_on_close_request") == Ok(BoolVal(True))
}

pub fn bool_props_test() {
  let node =
    window.new("main")
    |> window.maximized(False)
    |> window.resizable(True)
    |> window.decorations(True)
    |> window.transparent(False)
    |> window.build()

  assert dict.get(node.props, "maximized") == Ok(BoolVal(False))
  assert dict.get(node.props, "resizable") == Ok(BoolVal(True))
  assert dict.get(node.props, "decorations") == Ok(BoolVal(True))
  assert dict.get(node.props, "transparent") == Ok(BoolVal(False))
}

pub fn push_adds_child_test() {
  let child = Node(id: "c1", kind: "text", props: dict.new(), children: [])
  let node =
    window.new("main")
    |> window.push(child)
    |> window.build()

  assert node.children == [child]
}

pub fn extend_adds_multiple_children_test() {
  let c1 = Node(id: "c1", kind: "text", props: dict.new(), children: [])
  let c2 = Node(id: "c2", kind: "button", props: dict.new(), children: [])
  let node =
    window.new("main")
    |> window.extend([c1, c2])
    |> window.build()

  assert node.children == [c1, c2]
}

pub fn omitted_optionals_are_absent_test() {
  let node = window.new("main") |> window.build()

  assert dict.get(node.props, "title") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "maximized") == Error(Nil)
}
