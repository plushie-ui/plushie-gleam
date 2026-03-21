import gleeunit/should
import plushie/node.{StringVal}
import plushie/prop/anchor

pub fn start_encodes_test() {
  should.equal(anchor.to_prop_value(anchor.AnchorStart), StringVal("start"))
}

pub fn end_encodes_test() {
  should.equal(anchor.to_prop_value(anchor.AnchorEnd), StringVal("end"))
}
