import gleam/dict
import plushie/node.{FloatVal, ListVal, StringVal}
import plushie/prop/length
import plushie/widget/progress_bar

pub fn new_builds_minimal_progress_bar_test() {
  let node =
    progress_bar.new("loading", #(0.0, 100.0), 42.0) |> progress_bar.build()

  assert node.id == "loading"
  assert node.kind == "progress_bar"
  assert node.children == []
  assert dict.get(node.props, "value") == Ok(FloatVal(42.0))
  let range_val = ListVal([FloatVal(0.0), FloatVal(100.0)])
  assert dict.get(node.props, "range") == Ok(range_val)
  assert dict.size(node.props) == 2
}

pub fn width_sets_length_prop_test() {
  let node =
    progress_bar.new("pb", #(0.0, 1.0), 0.5)
    |> progress_bar.width(length.Fill)
    |> progress_bar.build()

  assert dict.get(node.props, "width") == Ok(length.to_prop_value(length.Fill))
}

pub fn height_sets_float_prop_test() {
  let node =
    progress_bar.new("pb", #(0.0, 1.0), 0.5)
    |> progress_bar.height(8.0)
    |> progress_bar.build()

  assert dict.get(node.props, "height") == Ok(FloatVal(8.0))
}

pub fn style_sets_string_prop_test() {
  let node =
    progress_bar.new("pb", #(0.0, 1.0), 0.5)
    |> progress_bar.style("custom")
    |> progress_bar.build()

  assert dict.get(node.props, "style") == Ok(StringVal("custom"))
}

pub fn chaining_multiple_setters_test() {
  let node =
    progress_bar.new("upload", #(0.0, 100.0), 75.0)
    |> progress_bar.width(length.Fixed(300.0))
    |> progress_bar.height(12.0)
    |> progress_bar.style("accent")
    |> progress_bar.build()

  assert dict.get(node.props, "value") == Ok(FloatVal(75.0))
  assert dict.get(node.props, "width")
    == Ok(length.to_prop_value(length.Fixed(300.0)))
  assert dict.get(node.props, "height") == Ok(FloatVal(12.0))
  assert dict.get(node.props, "style") == Ok(StringVal("accent"))
}

pub fn omitted_optionals_are_absent_test() {
  let node = progress_bar.new("pb", #(0.0, 1.0), 0.5) |> progress_bar.build()

  assert dict.get(node.props, "width") == Error(Nil)
  assert dict.get(node.props, "height") == Error(Nil)
  assert dict.get(node.props, "style") == Error(Nil)
}
