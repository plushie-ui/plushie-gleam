import gleeunit/should
import plushie/node.{StringVal}
import plushie/prop/color

pub fn from_hex_six_digit_test() {
  let assert Ok(c) = color.from_hex("#ff0000")
  should.equal(color.to_hex(c), "#ff0000")
}

pub fn from_hex_without_hash_test() {
  let assert Ok(c) = color.from_hex("00ff00")
  should.equal(color.to_hex(c), "#00ff00")
}

pub fn from_hex_eight_digit_alpha_test() {
  let assert Ok(c) = color.from_hex("#ff000080")
  should.equal(color.to_hex(c), "#ff000080")
}

pub fn from_hex_short_rgb_test() {
  let assert Ok(c) = color.from_hex("#f00")
  should.equal(color.to_hex(c), "#ff0000")
}

pub fn from_hex_short_rgba_test() {
  let assert Ok(c) = color.from_hex("#f008")
  should.equal(color.to_hex(c), "#ff000088")
}

pub fn from_hex_normalizes_case_test() {
  let assert Ok(c) = color.from_hex("#FF8800")
  should.equal(color.to_hex(c), "#ff8800")
}

pub fn from_hex_rejects_invalid_test() {
  should.be_error(color.from_hex("#xyz"))
  should.be_error(color.from_hex("#12345"))
  should.be_error(color.from_hex(""))
  should.be_error(color.from_hex("#gggggg"))
}

pub fn from_rgb_test() {
  let c = color.from_rgb(255, 128, 0)
  should.equal(color.to_hex(c), "#ff8000")
}

pub fn from_rgb_clamps_test() {
  let c = color.from_rgb(300, -10, 128)
  should.equal(color.to_hex(c), "#ff0080")
}

pub fn from_rgba_test() {
  let c = color.from_rgba(255, 0, 0, 0.5)
  // alpha 0.5 * 255 = 127.5, rounded to 128 = 0x80
  should.equal(color.to_hex(c), "#ff000080")
}

pub fn named_constants_test() {
  should.equal(color.to_hex(color.black), "#000000")
  should.equal(color.to_hex(color.white), "#ffffff")
  should.equal(color.to_hex(color.transparent), "#00000000")
  should.equal(color.to_hex(color.red), "#ff0000")
}

pub fn from_rgb_float_test() {
  let c = color.from_rgb_float(1.0, 0.5, 0.0)
  // 1.0 -> 255, 0.5 -> 128 (0x80), 0.0 -> 0
  should.equal(color.to_hex(c), "#ff8000")
}

pub fn from_rgb_float_clamps_test() {
  let c = color.from_rgb_float(2.0, -0.5, 0.5)
  // 2.0 clamped to 1.0 -> 255, -0.5 clamped to 0.0 -> 0
  should.equal(color.to_hex(c), "#ff0080")
}

pub fn from_rgba_float_test() {
  let c = color.from_rgba_float(1.0, 0.0, 0.0, 0.5)
  // alpha 0.5 * 255 = 127.5, rounded to 128 = 0x80
  should.equal(color.to_hex(c), "#ff000080")
}

pub fn from_rgba_float_full_opaque_test() {
  let c = color.from_rgba_float(0.0, 1.0, 0.0, 1.0)
  should.equal(color.to_hex(c), "#00ff00ff")
}

pub fn to_prop_value_test() {
  should.equal(color.to_prop_value(color.blue), StringVal("#0000ff"))
}
