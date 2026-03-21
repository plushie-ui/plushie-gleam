import gleam/dict
import plushie/node.{FloatVal, ListVal, StringVal}
import plushie/prop/length
import plushie/widget/slider

pub fn new_builds_minimal_slider_test() {
  let node = slider.new("vol", #(0.0, 100.0), 50.0) |> slider.build()

  assert node.id == "vol"
  assert node.kind == "slider"
  assert node.children == []
  assert dict.get(node.props, "value") == Ok(FloatVal(50.0))
  let range_val = ListVal([FloatVal(0.0), FloatVal(100.0)])
  assert dict.get(node.props, "range") == Ok(range_val)
  assert dict.size(node.props) == 2
}

pub fn step_sets_float_prop_test() {
  let node =
    slider.new("s", #(0.0, 1.0), 0.5)
    |> slider.step(0.1)
    |> slider.build()

  assert dict.get(node.props, "step") == Ok(FloatVal(0.1))
}

pub fn shift_step_sets_float_prop_test() {
  let node =
    slider.new("s", #(0.0, 1.0), 0.5)
    |> slider.shift_step(0.01)
    |> slider.build()

  assert dict.get(node.props, "shift_step") == Ok(FloatVal(0.01))
}

pub fn default_value_sets_float_prop_test() {
  let node =
    slider.new("s", #(0.0, 100.0), 75.0)
    |> slider.default_value(50.0)
    |> slider.build()

  assert dict.get(node.props, "default") == Ok(FloatVal(50.0))
}

pub fn width_sets_length_prop_test() {
  let node =
    slider.new("s", #(0.0, 1.0), 0.5)
    |> slider.width(length.Fill)
    |> slider.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
}

pub fn height_sets_float_prop_test() {
  let node =
    slider.new("s", #(0.0, 1.0), 0.5)
    |> slider.height(20.0)
    |> slider.build()

  assert dict.get(node.props, "height") == Ok(FloatVal(20.0))
}

pub fn style_sets_string_prop_test() {
  let node =
    slider.new("s", #(0.0, 1.0), 0.5)
    |> slider.style("custom")
    |> slider.build()

  assert dict.get(node.props, "style") == Ok(StringVal("custom"))
}

pub fn chaining_multiple_setters_test() {
  let node =
    slider.new("brightness", #(0.0, 255.0), 128.0)
    |> slider.step(1.0)
    |> slider.shift_step(10.0)
    |> slider.default_value(128.0)
    |> slider.width(length.Fixed(200.0))
    |> slider.build()

  assert dict.get(node.props, "step") == Ok(FloatVal(1.0))
  assert dict.get(node.props, "shift_step") == Ok(FloatVal(10.0))
  assert dict.get(node.props, "default") == Ok(FloatVal(128.0))
  assert dict.get(node.props, "width")
    == Ok(length.to_prop_value(length.Fixed(200.0)))
}

pub fn omitted_optionals_are_absent_test() {
  let node = slider.new("s", #(0.0, 1.0), 0.5) |> slider.build()

  assert dict.get(node.props, "step") == Error(Nil)
  assert dict.get(node.props, "shift_step") == Error(Nil)
  assert dict.get(node.props, "default") == Error(Nil)
  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "height") == Error(Nil)
  assert dict.get(node.props, "style") == Error(Nil)
}
