//// Input purpose hint for IME keyboards.
////
//// Informs the platform which type of virtual keyboard or IME behavior
//// is appropriate for a text input or text editor. Matches the values
//// supported by the Rust renderer's `InputPurpose` type.

import plushie/node.{type PropValue, StringVal}

/// Keyboard/IME purpose hint for text inputs.
pub type InputPurpose {
  /// Default text input.
  Normal
  /// Secure input (passwords, pins). Hides typed characters.
  Secure
  /// Terminal/console input.
  Terminal
  /// Numeric input.
  Number
  /// Decimal number input.
  Decimal
  /// Phone number input.
  Phone
  /// Email address input.
  Email
  /// URL input.
  Url
  /// Search input.
  Search
}

/// Encode an InputPurpose to its wire-format PropValue.
pub fn to_prop_value(p: InputPurpose) -> PropValue {
  StringVal(to_string(p))
}

/// Convert an InputPurpose to its wire-format string representation.
pub fn to_string(p: InputPurpose) -> String {
  case p {
    Normal -> "normal"
    Secure -> "secure"
    Terminal -> "terminal"
    Number -> "number"
    Decimal -> "decimal"
    Phone -> "phone"
    Email -> "email"
    Url -> "url"
    Search -> "search"
  }
}
