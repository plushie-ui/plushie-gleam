//// Inspect a toddy app's initial view tree without a renderer.
////
//// Calls init and view, normalizes the tree, and prints it as JSON.
//// No binary or renderer is required.
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
