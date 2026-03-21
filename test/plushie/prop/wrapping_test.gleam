import gleeunit/should
import plushie/node.{StringVal}
import plushie/prop/wrapping

pub fn no_wrap_encodes_test() {
  should.equal(wrapping.to_prop_value(wrapping.NoWrap), StringVal("none"))
}

pub fn word_encodes_test() {
  should.equal(wrapping.to_prop_value(wrapping.Word), StringVal("word"))
}

pub fn glyph_encodes_test() {
  should.equal(wrapping.to_prop_value(wrapping.Glyph), StringVal("glyph"))
}

pub fn word_or_glyph_encodes_test() {
  should.equal(
    wrapping.to_prop_value(wrapping.WordOrGlyph),
    StringVal("word_or_glyph"),
  )
}
