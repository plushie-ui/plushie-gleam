import gleeunit/should
import plushie/node.{StringVal}
import plushie/prop/alignment.{Bottom, Center, Left, Right, Top}

pub fn all_variants_encode_correctly_test() {
  should.equal(alignment.to_prop_value(Left), StringVal("left"))
  should.equal(alignment.to_prop_value(Center), StringVal("center"))
  should.equal(alignment.to_prop_value(Right), StringVal("right"))
  should.equal(alignment.to_prop_value(Top), StringVal("top"))
  should.equal(alignment.to_prop_value(Bottom), StringVal("bottom"))
}
