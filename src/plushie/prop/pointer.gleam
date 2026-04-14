//// Pointer type parsing for unified pointer events.
////
//// Provides wire-format parsing for pointer types and buttons.

import plushie/event.{
  type MouseButton, type PointerType, BackButton, ForwardButton, LeftButton,
  MiddleButton, Mouse, OtherButton, Pen, RightButton, Touch,
}

/// Parse a pointer type from a wire string. Defaults to Mouse for
/// unrecognized values.
pub fn parse_pointer(value: String) -> PointerType {
  case value {
    "mouse" -> Mouse
    "touch" -> Touch
    "pen" -> Pen
    _ -> Mouse
  }
}

/// Parse a mouse button from a wire string. Defaults to LeftButton for
/// unrecognized values.
pub fn parse_button(value: String) -> MouseButton {
  case value {
    "left" -> LeftButton
    "right" -> RightButton
    "middle" -> MiddleButton
    "back" -> BackButton
    "forward" -> ForwardButton
    _ -> OtherButton(value)
  }
}
