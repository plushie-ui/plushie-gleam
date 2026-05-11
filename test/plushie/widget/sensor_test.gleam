import gleam/dict
import plushie/node.{BoolVal}
import plushie/widget/sensor

pub fn on_resize_sets_bool_prop_test() {
  let node =
    sensor.new("size")
    |> sensor.on_resize(True)
    |> sensor.build()

  assert dict.get(node.props, "on_resize") == Ok(BoolVal(True))
}

pub fn on_resize_opt_sets_bool_prop_test() {
  let node =
    sensor.new("size")
    |> sensor.with_opts([sensor.OnResize(True)])
    |> sensor.build()

  assert dict.get(node.props, "on_resize") == Ok(BoolVal(True))
}
