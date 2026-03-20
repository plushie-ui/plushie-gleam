import gleeunit/should
import toddy/node.{StringVal}
import toddy/prop/content_fit

pub fn contain_encodes_test() {
  should.equal(
    content_fit.to_prop_value(content_fit.Contain),
    StringVal("contain"),
  )
}

pub fn cover_encodes_test() {
  should.equal(content_fit.to_prop_value(content_fit.Cover), StringVal("cover"))
}

pub fn fill_encodes_test() {
  should.equal(
    content_fit.to_prop_value(content_fit.FitFill),
    StringVal("fill"),
  )
}

pub fn scale_down_encodes_test() {
  should.equal(
    content_fit.to_prop_value(content_fit.ScaleDown),
    StringVal("scale_down"),
  )
}

pub fn none_encodes_test() {
  should.equal(content_fit.to_prop_value(content_fit.NoFit), StringVal("none"))
}
