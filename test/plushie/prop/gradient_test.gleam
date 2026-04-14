import gleam/dict
import gleeunit/should
import plushie/node.{DictVal, FloatVal, ListVal, StringVal}
import plushie/prop/color
import plushie/prop/gradient

pub fn linear_constructs_test() {
  let g =
    gradient.linear(#(0.0, 0.0), #(100.0, 100.0), [
      gradient.stop(0.0, color.black),
      gradient.stop(1.0, color.white),
    ])
  should.equal(g.from, #(0.0, 0.0))
  should.equal(g.to, #(100.0, 100.0))
  should.equal(g.stops, [
    gradient.GradientStop(0.0, color.black),
    gradient.GradientStop(1.0, color.white),
  ])
}

pub fn to_prop_value_encodes_correctly_test() {
  let g =
    gradient.linear(#(0.0, 0.0), #(100.0, 0.0), [
      gradient.stop(0.0, color.red),
      gradient.stop(1.0, color.blue),
    ])
  let result = gradient.to_prop_value(g)
  let expected =
    DictVal(
      dict.from_list([
        #("type", StringVal("linear")),
        #("start", ListVal([FloatVal(0.0), FloatVal(0.0)])),
        #("end", ListVal([FloatVal(100.0), FloatVal(0.0)])),
        #(
          "stops",
          ListVal([
            ListVal([FloatVal(0.0), StringVal("#ff0000")]),
            ListVal([FloatVal(1.0), StringVal("#0000ff")]),
          ]),
        ),
      ]),
    )
  should.equal(result, expected)
}

pub fn empty_stops_test() {
  let g = gradient.linear(#(0.0, 0.0), #(1.0, 0.0), [])
  let result = gradient.to_prop_value(g)
  let expected =
    DictVal(
      dict.from_list([
        #("type", StringVal("linear")),
        #("start", ListVal([FloatVal(0.0), FloatVal(0.0)])),
        #("end", ListVal([FloatVal(1.0), FloatVal(0.0)])),
        #("stops", ListVal([])),
      ]),
    )
  should.equal(result, expected)
}

pub fn stop_uses_color_type_test() {
  let assert Ok(c) = color.from_hex("#aabbcc")
  let s = gradient.stop(0.5, c)
  should.equal(s.offset, 0.5)
  should.equal(s.color, c)
}

pub fn linear_from_angle_horizontal_test() {
  let g =
    gradient.linear_from_angle(0.0, [
      gradient.stop(0.0, color.black),
      gradient.stop(1.0, color.white),
    ])
  // 0 degrees: left to right (cos=1, sin=0)
  should.equal(g.from.1, 0.5)
  should.equal(g.to.1, 0.5)
}
