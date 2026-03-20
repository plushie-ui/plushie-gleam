import gleam/dict
import gleam/option.{None, Some}
import gleeunit/should
import toddy/node.{DictVal, FloatVal, StringVal}
import toddy/prop/border

pub fn new_has_defaults_test() {
  let b = border.new()
  should.equal(b.color, None)
  should.equal(b.width, 0.0)
  should.equal(b.radius, border.Uniform(0.0))
}

pub fn builder_sets_color_test() {
  let b = border.new() |> border.color("#ff0000")
  should.equal(b.color, Some("#ff0000"))
}

pub fn builder_sets_width_test() {
  let b = border.new() |> border.width(2.0)
  should.equal(b.width, 2.0)
}

pub fn builder_sets_uniform_radius_test() {
  let b = border.new() |> border.radius(8.0)
  should.equal(b.radius, border.Uniform(8.0))
}

pub fn builder_sets_per_corner_radius_test() {
  let b = border.new() |> border.radius_corners(1.0, 2.0, 3.0, 4.0)
  should.equal(b.radius, border.PerCorner(1.0, 2.0, 3.0, 4.0))
}

pub fn to_prop_value_without_color_test() {
  let result = border.new() |> border.width(1.0) |> border.to_prop_value()
  let expected =
    DictVal(
      dict.from_list([
        #("width", FloatVal(1.0)),
        #("radius", FloatVal(0.0)),
      ]),
    )
  should.equal(result, expected)
}

pub fn to_prop_value_with_color_test() {
  let result =
    border.new()
    |> border.color("#00ff00")
    |> border.width(2.0)
    |> border.to_prop_value()
  let expected =
    DictVal(
      dict.from_list([
        #("color", StringVal("#00ff00")),
        #("width", FloatVal(2.0)),
        #("radius", FloatVal(0.0)),
      ]),
    )
  should.equal(result, expected)
}

pub fn to_prop_value_per_corner_radius_test() {
  let result =
    border.new()
    |> border.radius_corners(1.0, 2.0, 3.0, 4.0)
    |> border.to_prop_value()
  let expected_radius =
    DictVal(
      dict.from_list([
        #("top_left", FloatVal(1.0)),
        #("top_right", FloatVal(2.0)),
        #("bottom_right", FloatVal(3.0)),
        #("bottom_left", FloatVal(4.0)),
      ]),
    )
  let expected =
    DictVal(
      dict.from_list([
        #("width", FloatVal(0.0)),
        #("radius", expected_radius),
      ]),
    )
  should.equal(result, expected)
}
