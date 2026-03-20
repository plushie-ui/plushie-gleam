import gleeunit/should
import toddy/node.{StringVal}
import toddy/prop/position

pub fn top_encodes_test() {
  should.equal(position.to_prop_value(position.Top), StringVal("top"))
}

pub fn bottom_encodes_test() {
  should.equal(position.to_prop_value(position.Bottom), StringVal("bottom"))
}

pub fn left_encodes_test() {
  should.equal(position.to_prop_value(position.PositionLeft), StringVal("left"))
}

pub fn right_encodes_test() {
  should.equal(
    position.to_prop_value(position.PositionRight),
    StringVal("right"),
  )
}

pub fn follow_cursor_encodes_test() {
  should.equal(
    position.to_prop_value(position.FollowCursor),
    StringVal("follow_cursor"),
  )
}
