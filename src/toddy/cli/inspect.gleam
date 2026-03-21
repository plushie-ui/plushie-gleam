//// Inspect a toddy app's initial view tree without a renderer.
////
//// A debugging tool that runs the app's init and view functions,
//// normalizes the resulting tree, and prints it as JSON to stdout.
//// No toddy binary or renderer process is required -- this runs
//// entirely in Gleam.
////
//// Useful for verifying the initial widget tree structure, checking
//// scoped IDs after normalization, and debugging view functions
//// without launching a full GUI.
////
//// ```gleam
//// import toddy/cli/inspect
////
//// pub fn main() {
////   inspect.run(my_app.app())
//// }
//// ```

import gleam/dynamic
import gleam/io
import gleam/json
import toddy/app.{type App}
import toddy/event.{type Event}
import toddy/protocol/encode
import toddy/tree

/// Inspect a toddy app's initial view tree.
///
/// Calls init with a nil argument, renders the view, normalizes
/// the tree, converts it to a PropValue, and prints as JSON.
pub fn run(app: App(model, Event)) -> Nil {
  let init_fn = app.get_init(app)
  let view_fn = app.get_view(app)

  // Initialize the app with nil opts
  let #(model, _commands) = init_fn(dynamic.nil())

  // Render and normalize the view tree
  let raw_tree = view_fn(model)
  let normalized = tree.normalize(raw_tree)

  // Convert to PropValue and encode as JSON
  let prop_value = encode.node_to_prop_value(normalized)
  let json_string =
    encode.prop_value_to_json(prop_value)
    |> json.to_string

  io.println(json_string)
}
