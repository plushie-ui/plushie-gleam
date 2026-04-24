import gleam/dict
import plushie/node.{FloatVal, StringVal}
import plushie/prop/length
import plushie/prop/text_direction
import plushie/prop/wrapping
import plushie/widget/text_editor

pub fn new_builds_minimal_text_editor_test() {
  let node = text_editor.new("notes", "hello") |> text_editor.build()

  assert node.id == "notes"
  assert node.kind == "text_editor"
  assert node.children == []
  assert dict.get(node.props, "content") == Ok(StringVal("hello"))
  assert dict.size(node.props) == 2
}

pub fn placeholder_sets_string_prop_test() {
  let node =
    text_editor.new("notes", "")
    |> text_editor.placeholder("Write notes")
    |> text_editor.build()

  assert dict.get(node.props, "placeholder") == Ok(StringVal("Write notes"))
}

pub fn width_and_height_set_length_props_test() {
  let node =
    text_editor.new("notes", "")
    |> text_editor.width(length.Fill)
    |> text_editor.height(length.Fixed(240.0))
    |> text_editor.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
  assert dict.get(node.props, "height")
    == Ok(length.to_prop_value(length.Fixed(240.0)))
}

pub fn wrapping_sets_wrapping_prop_test() {
  let node =
    text_editor.new("notes", "")
    |> text_editor.wrapping(wrapping.WordOrGlyph)
    |> text_editor.build()

  assert dict.get(node.props, "wrapping")
    == Ok(wrapping.to_prop_value(wrapping.WordOrGlyph))
}

pub fn text_direction_sets_text_direction_prop_test() {
  let node =
    text_editor.new("notes", "")
    |> text_editor.text_direction(text_direction.Auto)
    |> text_editor.build()

  assert dict.get(node.props, "text_direction")
    == Ok(text_direction.to_prop_value(text_direction.Auto))
}

pub fn omitted_optionals_are_absent_test() {
  let node = text_editor.new("notes", "hello") |> text_editor.build()

  assert dict.get(node.props, "placeholder") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "height") == Error(Nil)
  assert dict.get(node.props, "wrapping") == Error(Nil)
  assert dict.get(node.props, "text_direction") == Error(Nil)
}

pub fn min_and_max_height_set_float_props_test() {
  let node =
    text_editor.new("notes", "")
    |> text_editor.min_height(120.0)
    |> text_editor.max_height(480.0)
    |> text_editor.build()

  assert dict.get(node.props, "min_height") == Ok(FloatVal(120.0))
  assert dict.get(node.props, "max_height") == Ok(FloatVal(480.0))
}
