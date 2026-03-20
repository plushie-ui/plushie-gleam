import gleam/dict
import gleam/list
import toddy/node.{FloatVal, IntVal, StringVal}
import toddy/prop/length
import toddy/widget/pane_grid

pub fn new_builds_minimal_pane_grid_test() {
  let node = pane_grid.new("pg") |> pane_grid.build()

  assert node.id == "pg"
  assert node.kind == "pane_grid"
  assert node.children == []
  assert dict.size(node.props) == 0
}

pub fn spacing_sets_prop_test() {
  let node =
    pane_grid.new("pg")
    |> pane_grid.spacing(4)
    |> pane_grid.build()

  assert dict.get(node.props, "spacing") == Ok(IntVal(4))
}

pub fn width_and_height_set_props_test() {
  let node =
    pane_grid.new("pg")
    |> pane_grid.width(length.Fill)
    |> pane_grid.height(length.Fixed(400.0))
    |> pane_grid.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(400.0)))
}

pub fn min_size_sets_prop_test() {
  let node =
    pane_grid.new("pg")
    |> pane_grid.min_size(50.0)
    |> pane_grid.build()

  assert dict.get(node.props, "min_size") == Ok(FloatVal(50.0))
}

pub fn divider_props_test() {
  let node =
    pane_grid.new("pg")
    |> pane_grid.divider_color("#cccccc")
    |> pane_grid.divider_width(2.0)
    |> pane_grid.build()

  assert dict.get(node.props, "divider_color") == Ok(StringVal("#cccccc"))
  assert dict.get(node.props, "divider_width") == Ok(FloatVal(2.0))
}

pub fn leeway_sets_prop_test() {
  let node =
    pane_grid.new("pg")
    |> pane_grid.leeway(10.0)
    |> pane_grid.build()

  assert dict.get(node.props, "leeway") == Ok(FloatVal(10.0))
}

pub fn push_adds_child_test() {
  let child = node.new("pane1", "container")
  let node =
    pane_grid.new("pg")
    |> pane_grid.push(child)
    |> pane_grid.build()

  assert list.length(node.children) == 1
  let assert [first] = node.children
  assert first.id == "pane1"
}

pub fn extend_adds_children_test() {
  let c1 = node.new("p1", "container")
  let c2 = node.new("p2", "container")
  let node =
    pane_grid.new("pg")
    |> pane_grid.extend([c1, c2])
    |> pane_grid.build()

  assert list.length(node.children) == 2
}

pub fn omitted_optionals_are_absent_test() {
  let node = pane_grid.new("pg") |> pane_grid.build()

  assert dict.get(node.props, "spacing") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "height") == Error(Nil)
  assert dict.get(node.props, "min_size") == Error(Nil)
  assert dict.get(node.props, "divider_color") == Error(Nil)
  assert dict.get(node.props, "divider_width") == Error(Nil)
  assert dict.get(node.props, "leeway") == Error(Nil)
}
