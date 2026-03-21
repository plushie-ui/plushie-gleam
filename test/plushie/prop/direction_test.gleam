import gleeunit/should
import plushie/node.{StringVal}
import plushie/prop/direction

pub fn horizontal_encodes_test() {
  should.equal(
    direction.to_prop_value(direction.Horizontal),
    StringVal("horizontal"),
  )
}

pub fn vertical_encodes_test() {
  should.equal(
    direction.to_prop_value(direction.Vertical),
    StringVal("vertical"),
  )
}

pub fn both_encodes_test() {
  should.equal(direction.to_prop_value(direction.Both), StringVal("both"))
}
