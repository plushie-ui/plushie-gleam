import gleeunit/should
import plushie/node.{StringVal}
import plushie/prop/ellipsis

pub fn none_encodes_test() {
  should.equal(ellipsis.to_prop_value(ellipsis.None), StringVal("none"))
}

pub fn start_encodes_test() {
  should.equal(ellipsis.to_prop_value(ellipsis.Start), StringVal("start"))
}

pub fn middle_encodes_test() {
  should.equal(ellipsis.to_prop_value(ellipsis.Middle), StringVal("middle"))
}

pub fn end_encodes_test() {
  should.equal(ellipsis.to_prop_value(ellipsis.End), StringVal("end"))
}
