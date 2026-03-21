import gleeunit/should
import toddy/node.{StringVal}
import toddy/prop/shaping

pub fn auto_encodes_test() {
  should.equal(shaping.to_prop_value(shaping.Auto), StringVal("auto"))
}

pub fn basic_encodes_test() {
  should.equal(shaping.to_prop_value(shaping.Basic), StringVal("basic"))
}

pub fn advanced_encodes_test() {
  should.equal(shaping.to_prop_value(shaping.Advanced), StringVal("advanced"))
}
