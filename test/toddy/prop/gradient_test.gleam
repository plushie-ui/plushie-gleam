import gleam/dict
import gleeunit/should
import toddy/node.{DictVal, FloatVal, ListVal, StringVal}
import toddy/prop/gradient

pub fn linear_constructs_test() {
  let g =
    gradient.linear(45.0, [
      gradient.stop(0.0, "#000"),
      gradient.stop(1.0, "#fff"),
    ])
  should.equal(g.angle, 45.0)
  should.equal(g.stops, [
    gradient.GradientStop(0.0, "#000"),
    gradient.GradientStop(1.0, "#fff"),
  ])
}

pub fn to_prop_value_encodes_correctly_test() {
  let g =
    gradient.linear(90.0, [
      gradient.stop(0.0, "#ff0000"),
      gradient.stop(1.0, "#0000ff"),
    ])
  let result = gradient.to_prop_value(g)
  let expected =
    DictVal(
      dict.from_list([
        #("type", StringVal("linear")),
        #("angle", FloatVal(90.0)),
        #(
          "stops",
          ListVal([
            DictVal(
              dict.from_list([
                #("offset", FloatVal(0.0)),
                #("color", StringVal("#ff0000")),
              ]),
            ),
            DictVal(
              dict.from_list([
                #("offset", FloatVal(1.0)),
                #("color", StringVal("#0000ff")),
              ]),
            ),
          ]),
        ),
      ]),
    )
  should.equal(result, expected)
}

pub fn empty_stops_test() {
  let g = gradient.linear(0.0, [])
  let result = gradient.to_prop_value(g)
  let expected =
    DictVal(
      dict.from_list([
        #("type", StringVal("linear")),
        #("angle", FloatVal(0.0)),
        #("stops", ListVal([])),
      ]),
    )
  should.equal(result, expected)
}
