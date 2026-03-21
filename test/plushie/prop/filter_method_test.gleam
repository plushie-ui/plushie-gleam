import gleeunit/should
import plushie/node.{StringVal}
import plushie/prop/filter_method

pub fn nearest_encodes_test() {
  should.equal(
    filter_method.to_prop_value(filter_method.Nearest),
    StringVal("nearest"),
  )
}

pub fn linear_encodes_test() {
  should.equal(
    filter_method.to_prop_value(filter_method.Linear),
    StringVal("linear"),
  )
}
