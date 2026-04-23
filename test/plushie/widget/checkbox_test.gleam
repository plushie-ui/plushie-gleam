import gleam/dict
import plushie/node.{BoolVal, DictVal, FloatVal, IntVal, StringVal}
import plushie/prop/a11y
import plushie/prop/length
import plushie/widget/checkbox

pub fn new_builds_minimal_checkbox_test() {
  let node = checkbox.new("agree", "I agree", False) |> checkbox.build()

  assert node.id == "agree"
  assert node.kind == "checkbox"
  assert node.children == []
  assert dict.get(node.props, "label") == Ok(StringVal("I agree"))
  assert dict.get(node.props, "checked") == Ok(BoolVal(False))
  assert dict.size(node.props) == 3
}

pub fn default_a11y_includes_label_and_toggled_state_test() {
  let node = checkbox.new("agree", "I agree", True) |> checkbox.build()

  let assert Ok(DictVal(props)) = dict.get(node.props, "a11y")
  assert dict.get(props, "role") == Ok(StringVal("check_box"))
  assert dict.get(props, "label") == Ok(StringVal("I agree"))
  assert dict.get(props, "toggled") == Ok(BoolVal(True))
}

pub fn explicit_a11y_replaces_checkbox_defaults_test() {
  let node =
    checkbox.new("agree", "I agree", True)
    |> checkbox.a11y(a11y.new() |> a11y.label("Custom"))
    |> checkbox.build()

  let assert Ok(DictVal(props)) = dict.get(node.props, "a11y")
  assert dict.get(props, "label") == Ok(StringVal("Custom"))
  assert dict.get(props, "role") == Error(Nil)
  assert dict.get(props, "toggled") == Error(Nil)
}

pub fn toggled_true_sets_bool_prop_test() {
  let node = checkbox.new("cb", "Check", True) |> checkbox.build()

  assert dict.get(node.props, "checked") == Ok(BoolVal(True))
}

pub fn spacing_sets_int_prop_test() {
  let node =
    checkbox.new("cb", "Check", False)
    |> checkbox.spacing(12)
    |> checkbox.build()

  assert dict.get(node.props, "spacing") == Ok(IntVal(12))
}

pub fn width_sets_length_prop_test() {
  let node =
    checkbox.new("cb", "Check", False)
    |> checkbox.width(length.Fill)
    |> checkbox.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
}

pub fn size_sets_float_prop_test() {
  let node =
    checkbox.new("cb", "Check", False)
    |> checkbox.size(20.0)
    |> checkbox.build()

  assert dict.get(node.props, "size") == Ok(FloatVal(20.0))
}

pub fn text_size_sets_float_prop_test() {
  let node =
    checkbox.new("cb", "Check", False)
    |> checkbox.text_size(14.0)
    |> checkbox.build()

  assert dict.get(node.props, "text_size") == Ok(FloatVal(14.0))
}

pub fn style_sets_string_prop_test() {
  let node =
    checkbox.new("cb", "Check", False)
    |> checkbox.style("custom")
    |> checkbox.build()

  assert dict.get(node.props, "style") == Ok(StringVal("custom"))
}

pub fn disabled_sets_bool_prop_test() {
  let node =
    checkbox.new("cb", "Check", False)
    |> checkbox.disabled(True)
    |> checkbox.build()

  assert dict.get(node.props, "disabled") == Ok(BoolVal(True))
}

pub fn chaining_multiple_setters_test() {
  let node =
    checkbox.new("cb", "Accept", True)
    |> checkbox.spacing(8)
    |> checkbox.size(24.0)
    |> checkbox.disabled(False)
    |> checkbox.build()

  assert dict.get(node.props, "label") == Ok(StringVal("Accept"))
  assert dict.get(node.props, "checked") == Ok(BoolVal(True))
  assert dict.get(node.props, "spacing") == Ok(IntVal(8))
  assert dict.get(node.props, "size") == Ok(FloatVal(24.0))
  assert dict.get(node.props, "disabled") == Ok(BoolVal(False))
}

pub fn omitted_optionals_are_absent_test() {
  let node = checkbox.new("cb", "Check", False) |> checkbox.build()

  assert dict.get(node.props, "spacing") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "size") == Error(Nil)
  assert dict.get(node.props, "style") == Error(Nil)
  assert dict.get(node.props, "disabled") == Error(Nil)
}
