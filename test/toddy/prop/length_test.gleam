import gleam/dict
import gleeunit/should
import toddy/node.{DictVal, FloatVal, IntVal, StringVal}
import toddy/prop/length.{Fill, FillPortion, Fixed, Shrink}

pub fn fill_encodes_to_string_test() {
  should.equal(length.to_prop_value(Fill), StringVal("fill"))
}

pub fn shrink_encodes_to_string_test() {
  should.equal(length.to_prop_value(Shrink), StringVal("shrink"))
}

pub fn fill_portion_encodes_to_dict_test() {
  let result = length.to_prop_value(FillPortion(3))
  should.equal(result, DictVal(dict.from_list([#("fill_portion", IntVal(3))])))
}

pub fn fixed_encodes_to_float_test() {
  should.equal(length.to_prop_value(Fixed(200.0)), FloatVal(200.0))
}
