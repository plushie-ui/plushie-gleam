import gleam/dict
import gleeunit/should
import toddy/node.{DictVal, FloatVal, ListVal, StringVal}
import toddy/prop/shadow

pub fn new_has_defaults_test() {
  let s = shadow.new()
  should.equal(s.color, "#000000")
  should.equal(s.offset_x, 0.0)
  should.equal(s.offset_y, 0.0)
  should.equal(s.blur_radius, 0.0)
}

pub fn builder_chain_test() {
  let s =
    shadow.new()
    |> shadow.color("#ff0000")
    |> shadow.offset(2.0, 4.0)
    |> shadow.blur_radius(8.0)
  should.equal(s.color, "#ff0000")
  should.equal(s.offset_x, 2.0)
  should.equal(s.offset_y, 4.0)
  should.equal(s.blur_radius, 8.0)
}

pub fn to_prop_value_encodes_correctly_test() {
  let result =
    shadow.new()
    |> shadow.color("#aabbcc")
    |> shadow.offset(3.0, 5.0)
    |> shadow.blur_radius(10.0)
    |> shadow.to_prop_value()
  let expected =
    DictVal(
      dict.from_list([
        #("color", StringVal("#aabbcc")),
        #("offset", ListVal([FloatVal(3.0), FloatVal(5.0)])),
        #("blur_radius", FloatVal(10.0)),
      ]),
    )
  should.equal(result, expected)
}
