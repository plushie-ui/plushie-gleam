import gleam/dict
import toddy/node.{BoolVal, FloatVal, StringVal}
import toddy/prop/alignment
import toddy/prop/length
import toddy/prop/padding
import toddy/widget/text_input

pub fn new_builds_minimal_text_input_test() {
  let node = text_input.new("email", "hello@example.com") |> text_input.build()

  assert node.id == "email"
  assert node.kind == "text_input"
  assert node.children == []
  assert dict.get(node.props, "value") == Ok(StringVal("hello@example.com"))
  assert dict.size(node.props) == 1
}

pub fn placeholder_sets_string_prop_test() {
  let node =
    text_input.new("name", "")
    |> text_input.placeholder("Enter name")
    |> text_input.build()

  assert dict.get(node.props, "placeholder") == Ok(StringVal("Enter name"))
}

pub fn padding_sets_padding_prop_test() {
  let p = padding.all(8.0)
  let node =
    text_input.new("in", "")
    |> text_input.padding(p)
    |> text_input.build()

  assert dict.get(node.props, "padding") == Ok(padding.to_prop_value(p))
}

pub fn width_sets_length_prop_test() {
  let node =
    text_input.new("in", "")
    |> text_input.width(length.Fill)
    |> text_input.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
}

pub fn size_sets_float_prop_test() {
  let node =
    text_input.new("in", "")
    |> text_input.size(18.0)
    |> text_input.build()

  assert dict.get(node.props, "size") == Ok(FloatVal(18.0))
}

pub fn align_x_sets_alignment_prop_test() {
  let node =
    text_input.new("in", "")
    |> text_input.align_x(alignment.Center)
    |> text_input.build()

  assert dict.get(node.props, "align_x")
    == Ok(alignment.to_prop_value(alignment.Center))
}

pub fn on_submit_sets_bool_prop_test() {
  let node =
    text_input.new("in", "")
    |> text_input.on_submit(True)
    |> text_input.build()

  assert dict.get(node.props, "on_submit") == Ok(BoolVal(True))
}

pub fn secure_sets_bool_prop_test() {
  let node =
    text_input.new("pw", "")
    |> text_input.secure(True)
    |> text_input.build()

  assert dict.get(node.props, "secure") == Ok(BoolVal(True))
}

pub fn on_paste_sets_bool_prop_test() {
  let node =
    text_input.new("in", "")
    |> text_input.on_paste(True)
    |> text_input.build()

  assert dict.get(node.props, "on_paste") == Ok(BoolVal(True))
}

pub fn style_sets_string_prop_test() {
  let node =
    text_input.new("in", "")
    |> text_input.style("custom")
    |> text_input.build()

  assert dict.get(node.props, "style") == Ok(StringVal("custom"))
}

pub fn line_height_sets_float_prop_test() {
  let node =
    text_input.new("in", "")
    |> text_input.line_height(1.5)
    |> text_input.build()

  assert dict.get(node.props, "line_height") == Ok(FloatVal(1.5))
}

pub fn chaining_multiple_setters_test() {
  let node =
    text_input.new("search", "query")
    |> text_input.placeholder("Search...")
    |> text_input.on_submit(True)
    |> text_input.secure(False)
    |> text_input.width(length.Fill)
    |> text_input.build()

  assert dict.get(node.props, "value") == Ok(StringVal("query"))
  assert dict.get(node.props, "placeholder") == Ok(StringVal("Search..."))
  assert dict.get(node.props, "on_submit") == Ok(BoolVal(True))
  assert dict.get(node.props, "secure") == Ok(BoolVal(False))
  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
}

pub fn omitted_optionals_are_absent_test() {
  let node = text_input.new("in", "v") |> text_input.build()

  assert dict.get(node.props, "placeholder") == Error(Nil)
  assert dict.get(node.props, "on_submit") == Error(Nil)
  assert dict.get(node.props, "secure") == Error(Nil)
  assert dict.get(node.props, "style") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
}
