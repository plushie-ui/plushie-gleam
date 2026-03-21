//// Position type for tooltip and overlay placement.

import plushie/node.{type PropValue, StringVal}

pub type Position {
  Top
  Bottom
  PositionLeft
  PositionRight
  FollowCursor
}

/// Encode a Position to its wire-format PropValue.
pub fn to_prop_value(p: Position) -> PropValue {
  StringVal(to_string(p))
}

pub fn to_string(p: Position) -> String {
  case p {
    Top -> "top"
    Bottom -> "bottom"
    PositionLeft -> "left"
    PositionRight -> "right"
    FollowCursor -> "follow_cursor"
  }
}
