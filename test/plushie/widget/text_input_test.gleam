import gleam/dict
import gleam/option
import plushie/node.{BoolVal, DictVal, FloatVal, StringVal}
import plushie/prop/alignment
import plushie/prop/color
import plushie/prop/font
import plushie/prop/length
import plushie/prop/line_height
import plushie/prop/padding
import plushie/widget/text_input

pub fn new_builds_minimal_text_input_test() {
  let node = text_input.new("email", "hello@example.com") |> text_input.build()

  assert node.id == "email"
  assert node.kind == "text_input"
  assert node.children == []
  assert dict.get(node.props, "value") == Ok(StringVal("hello@example.com"))
  assert dict.size(node.props) == 2
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
    |> text_input.line_height(line_height.relative(1.5))
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
  assert dict.get(node.props, "icon") == Error(Nil)
  assert dict.get(node.props, "placeholder_color") == Error(Nil)
  assert dict.get(node.props, "selection_color") == Error(Nil)
}

pub fn placeholder_color_sets_color_prop_test() {
  let node =
    text_input.new("in", "")
    |> text_input.placeholder_color(color.gray)
    |> text_input.build()

  assert dict.get(node.props, "placeholder_color")
    == Ok(color.to_prop_value(color.gray))
}

pub fn selection_color_sets_color_prop_test() {
  let node =
    text_input.new("in", "")
    |> text_input.selection_color(color.blue)
    |> text_input.build()

  assert dict.get(node.props, "selection_color")
    == Ok(color.to_prop_value(color.blue))
}

pub fn icon_sets_dict_prop_test() {
  let ic =
    text_input.TextInputIcon(
      code_point: "\u{F002}",
      size: option.Some(16.0),
      spacing: option.Some(4.0),
      side: option.Some(text_input.Left),
      font: option.Some(font.Family("icons")),
    )

  let node =
    text_input.new("search", "")
    |> text_input.icon(ic)
    |> text_input.build()

  let assert Ok(DictVal(icon_fields)) = dict.get(node.props, "icon")
  assert dict.get(icon_fields, "code_point") == Ok(StringVal("\u{F002}"))
  assert dict.get(icon_fields, "size") == Ok(FloatVal(16.0))
  assert dict.get(icon_fields, "spacing") == Ok(FloatVal(4.0))
  assert dict.get(icon_fields, "side") == Ok(StringVal("left"))
  assert dict.get(icon_fields, "font")
    == Ok(font.to_prop_value(font.Family("icons")))
}

pub fn icon_minimal_has_only_code_point_test() {
  let ic =
    text_input.TextInputIcon(
      code_point: "X",
      size: option.None,
      spacing: option.None,
      side: option.None,
      font: option.None,
    )

  let node =
    text_input.new("in", "")
    |> text_input.icon(ic)
    |> text_input.build()

  let assert Ok(DictVal(icon_fields)) = dict.get(node.props, "icon")
  assert dict.size(icon_fields) == 1
  assert dict.get(icon_fields, "code_point") == Ok(StringVal("X"))
}
