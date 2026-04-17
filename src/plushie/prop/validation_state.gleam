//// Form-validation state for input widgets.
////
//// Accepted by text_input, text_editor, checkbox, pick_list, and
//// combo_box builders. The normalizer projects this onto the `a11y`
//// map automatically (Valid -> a11y.invalid = False,
//// Invalid { message } -> a11y.invalid = True + a11y.error_message,
//// Pending -> a11y.busy via the widget).

import gleam/dict
import plushie/node.{type PropValue, DictVal, StringVal}

/// Form-validation state.
pub type ValidationState {
  Valid
  Pending
  Invalid(message: String)
}

/// Build an `Invalid` state from a message.
pub fn invalid(message: String) -> ValidationState {
  Invalid(message:)
}

/// Encode a `ValidationState` to its wire PropValue shape.
///
/// - `Valid`                       -> `DictVal({"state": "valid"})`
/// - `Pending`                     -> `DictVal({"state": "pending"})`
/// - `Invalid("...")`              -> `DictVal({"state": "invalid",
///                                               "message": "..."})`
pub fn to_prop_value(state: ValidationState) -> PropValue {
  case state {
    Valid -> DictVal(dict.from_list([#("state", StringVal("valid"))]))
    Pending -> DictVal(dict.from_list([#("state", StringVal("pending"))]))
    Invalid(message:) ->
      DictVal(
        dict.from_list([
          #("state", StringVal("invalid")),
          #("message", StringVal(message)),
        ]),
      )
  }
}
