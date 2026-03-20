import gleam/dict
import gleeunit/should
import toddy/node.{DictVal, FloatVal}
import toddy/prop/padding

pub fn all_creates_uniform_test() {
  let p = padding.all(8.0)
  should.equal(p, padding.Padding(8.0, 8.0, 8.0, 8.0))
}

pub fn xy_creates_two_axis_test() {
  let p = padding.xy(4.0, 12.0)
  should.equal(p, padding.Padding(4.0, 12.0, 4.0, 12.0))
}

pub fn none_creates_zero_test() {
  let p = padding.none()
  should.equal(p, padding.Padding(0.0, 0.0, 0.0, 0.0))
}

pub fn to_prop_value_is_full_map_test() {
  let result = padding.to_prop_value(padding.all(16.0))
  let expected =
    DictVal(
      dict.from_list([
        #("top", FloatVal(16.0)),
        #("right", FloatVal(16.0)),
        #("bottom", FloatVal(16.0)),
        #("left", FloatVal(16.0)),
      ]),
    )
  should.equal(result, expected)
}
