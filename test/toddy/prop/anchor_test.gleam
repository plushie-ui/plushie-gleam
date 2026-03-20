import gleeunit/should
import toddy/node.{StringVal}
import toddy/prop/anchor

pub fn start_encodes_test() {
  should.equal(anchor.to_prop_value(anchor.AnchorStart), StringVal("start"))
}

pub fn end_encodes_test() {
  should.equal(anchor.to_prop_value(anchor.AnchorEnd), StringVal("end"))
}
