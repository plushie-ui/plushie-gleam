import gleam/dict
import plushie/node.{BoolVal, FloatVal, Node, StringVal}
import plushie/prop/alignment
import plushie/prop/border
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/prop/shadow
import plushie/widget/container

pub fn new_builds_empty_container_test() {
  let node = container.new("box") |> container.build()

  assert node.id == "box"
  assert node.kind == "container"
  assert node.children == []
  assert dict.is_empty(node.props)
}

pub fn padding_sets_padding_prop_test() {
  let p = padding.all(16.0)
  let node =
    container.new("box")
    |> container.padding(p)
    |> container.build()

  assert dict.get(node.props, "padding") == Ok(padding.to_prop_value(p))
}

pub fn width_and_height_set_length_props_test() {
  let node =
    container.new("box")
    |> container.width(length.Fill)
    |> container.height(length.Fixed(100.0))
    |> container.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(100.0)))
}

pub fn max_width_and_max_height_set_float_props_test() {
  let node =
    container.new("box")
    |> container.max_width(800.0)
    |> container.max_height(600.0)
    |> container.build()

  assert dict.get(node.props, "max_width") == Ok(FloatVal(800.0))
  assert dict.get(node.props, "max_height") == Ok(FloatVal(600.0))
}

pub fn center_sets_bool_prop_test() {
  let node =
    container.new("box")
    |> container.center(True)
    |> container.build()

  assert dict.get(node.props, "center") == Ok(BoolVal(True))
}

pub fn clip_sets_bool_prop_test() {
  let node =
    container.new("box")
    |> container.clip(True)
    |> container.build()

  assert dict.get(node.props, "clip") == Ok(BoolVal(True))
}

pub fn align_x_and_align_y_set_alignment_props_test() {
  let node =
    container.new("box")
    |> container.align_x(alignment.Center)
    |> container.align_y(alignment.End)
    |> container.build()

  assert dict.get(node.props, "align_x")
    == Ok(alignment.to_prop_value(alignment.Center))
  assert dict.get(node.props, "align_y")
    == Ok(alignment.to_prop_value(alignment.End))
}

pub fn background_sets_color_prop_test() {
  let node =
    container.new("box")
    |> container.background(color.red)
    |> container.build()

  assert dict.get(node.props, "background")
    == Ok(color.to_prop_value(color.red))
}

pub fn color_sets_text_color_prop_test() {
  let node =
    container.new("box")
    |> container.color(color.white)
    |> container.build()

  assert dict.get(node.props, "color") == Ok(color.to_prop_value(color.white))
}

pub fn border_sets_border_prop_test() {
  let b = border.new() |> border.width(2.0) |> border.radius(4.0)
  let node =
    container.new("box")
    |> container.border(b)
    |> container.build()

  assert dict.get(node.props, "border") == Ok(border.to_prop_value(b))
}

pub fn shadow_sets_shadow_prop_test() {
  let s = shadow.new() |> shadow.blur_radius(8.0)
  let node =
    container.new("box")
    |> container.shadow(s)
    |> container.build()

  assert dict.get(node.props, "shadow") == Ok(shadow.to_prop_value(s))
}

pub fn style_sets_string_prop_test() {
  let node =
    container.new("box")
    |> container.style("card")
    |> container.build()

  assert dict.get(node.props, "style") == Ok(StringVal("card"))
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
    container.new("box")
    |> container.push(child)
    |> container.build()

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
    container.new("box")
    |> container.extend([c1, c2])
    |> container.build()

  assert node.children == [c1, c2]
}

pub fn push_preserves_order_test() {
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
    container.new("box")
    |> container.push(c1)
    |> container.push(c2)
    |> container.build()

  assert node.children == [c1, c2]
}

pub fn omitted_optionals_are_absent_test() {
  let node = container.new("box") |> container.build()

  assert dict.get(node.props, "padding") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "height") == Error(Nil)
  assert dict.get(node.props, "background") == Error(Nil)
  assert dict.get(node.props, "border") == Error(Nil)
  assert dict.get(node.props, "shadow") == Error(Nil)
  assert dict.get(node.props, "style") == Error(Nil)
}
