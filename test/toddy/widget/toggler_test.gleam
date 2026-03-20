import gleam/dict
import toddy/node.{BoolVal, FloatVal, IntVal, StringVal}
import toddy/prop/length
import toddy/widget/toggler

pub fn new_builds_minimal_toggler_test() {
  let node = toggler.new("dark", "Dark mode", False) |> toggler.build()

  assert node.id == "dark"
  assert node.kind == "toggler"
  assert node.children == []
  assert dict.get(node.props, "label") == Ok(StringVal("Dark mode"))
  assert dict.get(node.props, "is_toggled") == Ok(BoolVal(False))
  assert dict.size(node.props) == 2
}

pub fn toggled_true_sets_bool_prop_test() {
  let node = toggler.new("t", "On", True) |> toggler.build()

  assert dict.get(node.props, "is_toggled") == Ok(BoolVal(True))
}

pub fn spacing_sets_int_prop_test() {
  let node =
    toggler.new("t", "Toggle", False)
    |> toggler.spacing(12)
    |> toggler.build()

  assert dict.get(node.props, "spacing") == Ok(IntVal(12))
}

pub fn width_sets_length_prop_test() {
  let node =
    toggler.new("t", "Toggle", False)
    |> toggler.width(length.Fill)
    |> toggler.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
}

pub fn size_sets_float_prop_test() {
  let node =
    toggler.new("t", "Toggle", False)
    |> toggler.size(24.0)
    |> toggler.build()

  assert dict.get(node.props, "size") == Ok(FloatVal(24.0))
}

pub fn text_size_sets_float_prop_test() {
  let node =
    toggler.new("t", "Toggle", False)
    |> toggler.text_size(14.0)
    |> toggler.build()

  assert dict.get(node.props, "text_size") == Ok(FloatVal(14.0))
}

pub fn style_sets_string_prop_test() {
  let node =
    toggler.new("t", "Toggle", False)
    |> toggler.style("custom")
    |> toggler.build()

  assert dict.get(node.props, "style") == Ok(StringVal("custom"))
}

pub fn chaining_multiple_setters_test() {
  let node =
    toggler.new("notif", "Notifications", True)
    |> toggler.spacing(8)
    |> toggler.size(20.0)
    |> toggler.text_size(16.0)
    |> toggler.build()

  assert dict.get(node.props, "label") == Ok(StringVal("Notifications"))
  assert dict.get(node.props, "is_toggled") == Ok(BoolVal(True))
  assert dict.get(node.props, "spacing") == Ok(IntVal(8))
  assert dict.get(node.props, "size") == Ok(FloatVal(20.0))
  assert dict.get(node.props, "text_size") == Ok(FloatVal(16.0))
}

pub fn omitted_optionals_are_absent_test() {
  let node = toggler.new("t", "X", False) |> toggler.build()

  assert dict.get(node.props, "spacing") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "size") == Error(Nil)
  assert dict.get(node.props, "text_size") == Error(Nil)
  assert dict.get(node.props, "style") == Error(Nil)
}
