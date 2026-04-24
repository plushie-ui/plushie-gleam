import gleeunit/should
import plushie/node.{StringVal}
import plushie/prop/text_direction

pub fn auto_encodes_test() {
  should.equal(
    text_direction.to_prop_value(text_direction.Auto),
    StringVal("auto"),
  )
}

pub fn ltr_encodes_test() {
  should.equal(
    text_direction.to_prop_value(text_direction.Ltr),
    StringVal("ltr"),
  )
}

pub fn rtl_encodes_test() {
  should.equal(
    text_direction.to_prop_value(text_direction.Rtl),
    StringVal("rtl"),
  )
}
