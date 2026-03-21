import gleam/dict
import plushie/prop/length
import plushie/widget/space

pub fn new_builds_empty_space_test() {
  let node = space.new("gap") |> space.build()

  assert node.id == "gap"
  assert node.kind == "space"
  assert node.children == []
  assert dict.is_empty(node.props)
}

pub fn width_sets_length_prop_test() {
  let node =
    space.new("gap")
    |> space.width(length.Fill)
    |> space.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
}

pub fn height_sets_length_prop_test() {
  let node =
    space.new("gap")
    |> space.height(length.Fixed(20.0))
    |> space.build()

  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(20.0)))
}

pub fn width_and_height_together_test() {
  let node =
    space.new("gap")
    |> space.width(length.Fixed(10.0))
    |> space.height(length.Fixed(10.0))
    |> space.build()

  assert dict.get(node.props, "width")
    == Ok(length.to_prop_value(length.Fixed(10.0)))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(10.0)))
  assert dict.size(node.props) == 2
}

pub fn omitted_optionals_are_absent_test() {
  let node = space.new("gap") |> space.build()

  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "height") == Error(Nil)
}
