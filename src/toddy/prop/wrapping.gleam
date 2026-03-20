//// Text wrapping strategy type.

import toddy/node.{type PropValue, StringVal}

pub type Wrapping {
  NoWrap
  Word
  Glyph
  WordOrGlyph
}

/// Encode a Wrapping to its wire-format PropValue.
pub fn to_prop_value(w: Wrapping) -> PropValue {
  StringVal(to_string(w))
}

pub fn to_string(w: Wrapping) -> String {
  case w {
    NoWrap -> "none"
    Word -> "word"
    Glyph -> "glyph"
    WordOrGlyph -> "word_or_glyph"
  }
}
