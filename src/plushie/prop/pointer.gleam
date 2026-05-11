//// Pointer type parsing for unified pointer events.
////
//// Provides wire-format parsing for pointer types and buttons.

import plushie/event.{
  type MouseButton, type PointerType, BackButton, ForwardButton, LeftButton,
  MiddleButton, Mouse, Pen, RightButton, Touch,
}

/// Parse a pointer type from a canonical wire string.
pub fn parse_pointer(value: String) -> Result(PointerType, Nil) {
  case value {
    "mouse" -> Ok(Mouse)
    "touch" -> Ok(Touch)
    "pen" -> Ok(Pen)
    _ -> Error(Nil)
  }
}

/// Parse a mouse button from a canonical wire string.
pub fn parse_button(value: String) -> Result(MouseButton, Nil) {
  case value {
    "left" -> Ok(LeftButton)
    "right" -> Ok(RightButton)
    "middle" -> Ok(MiddleButton)
    "back" -> Ok(BackButton)
    "forward" -> Ok(ForwardButton)
    _ -> Error(Nil)
  }
}
