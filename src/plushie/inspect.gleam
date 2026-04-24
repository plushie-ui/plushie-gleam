//// Inspect a plushie app's initial view tree without a renderer.
////
//// A debugging tool that runs the app's init and view functions,
//// normalizes the resulting tree, and prints it as JSON to stdout.
//// No plushie binary or renderer process is required; this runs
//// entirely in Gleam.
////
//// Useful for verifying the initial widget tree structure, checking
//// scoped IDs after normalization, and debugging view functions
//// without launching a full GUI.
////
//// ```gleam
//// import plushie/inspect
////
//// pub fn main() {
////   inspect.run(my_app.app())
//// }
//// ```

import gleam/dynamic
import gleam/io
import gleam/json
import gleam/result
import gleam/string
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/platform
import plushie/protocol/encode
import plushie/tree

pub opaque type InspectError {
  InspectError(phase: InspectPhase, reason: dynamic.Dynamic)
}

type InspectPhase {
  AppInit
  AppView
  TreeNormalization
  JsonEncoding
}

/// Inspect a plushie app's initial view tree.
///
/// Calls init with a nil argument, renders the view, normalizes
/// the tree, converts it to a PropValue, and prints as JSON.
pub fn run(app: App(model, Event)) -> Nil {
  case to_json(app) {
    Ok(json_string) -> io.println(json_string)
    Error(err) -> {
      io.println_error(error_message(err))
      halt(1)
    }
  }
}

/// Render a plushie app's initial view tree as JSON.
///
/// This is the testable form of `run`, returning inspect-specific
/// failures instead of printing to stderr and halting the VM.
pub fn to_json(app: App(model, Event)) -> Result(String, InspectError) {
  let init_fn = app.get_init(app)
  let view_fn = app.get_view(app)

  use #(model, _commands) <- result.try(
    try_phase(AppInit, fn() { init_fn(dynamic.nil()) }),
  )

  use raw_tree <- result.try(
    try_phase(AppView, fn() { tree.view_list_to_tree(view_fn(model)) }),
  )

  use normalized <- result.try(
    try_phase(TreeNormalization, fn() { tree.normalize(raw_tree) }),
  )

  try_phase(JsonEncoding, fn() {
    encode.node_to_prop_value(normalized)
    |> encode.prop_value_to_json
    |> json.to_string
  })
}

pub fn error_message(err: InspectError) -> String {
  "plushie inspect failed during "
  <> phase_name(err.phase)
  <> ": "
  <> string.inspect(err.reason)
}

fn try_phase(
  phase: InspectPhase,
  work: fn() -> value,
) -> Result(value, InspectError) {
  case platform.try_call(work) {
    Ok(value) -> Ok(value)
    Error(reason) -> Error(InspectError(phase:, reason:))
  }
}

fn phase_name(phase: InspectPhase) -> String {
  case phase {
    AppInit -> "app init"
    AppView -> "app view"
    TreeNormalization -> "tree normalization"
    JsonEncoding -> "JSON encoding"
  }
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
