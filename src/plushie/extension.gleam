//// Extension system for custom widget types.
////
//// Plushie supports two kinds of extensions:
////
//// - **Native widgets**: backed by a Rust crate implementing the
////   `WidgetExtension` trait. The crate is compiled into the plushie
////   binary, and the widget communicates via the standard wire protocol.
////
//// - **Composite widgets**: pure Gleam widgets that compose built-in
////   widgets into reusable components. They produce standard Node trees
////   and require no Rust code.
////
//// ## Native widget extensions
////
//// A native widget is defined by creating an `ExtensionDef` and
//// registering it. The widget's Rust crate handles rendering and
//// event emission; the Gleam side provides the typed builder API.
////
//// ```gleam
//// import plushie/extension
//// import plushie/node.{type Node}
//// import plushie/prop/color
//// import plushie/prop/length
////
//// // Define the extension
//// pub const gauge_def = extension.ExtensionDef(
////   kind: "gauge",
////   rust_crate: "native/my_gauge",
////   rust_constructor: "my_gauge::GaugeExtension::new()",
////   props: [
////     extension.NumberProp("value"),
////     extension.NumberProp("min"),
////     extension.NumberProp("max"),
////     extension.ColorProp("color"),
////     extension.LengthProp("width"),
////   ],
////   commands: [
////     extension.CommandDef("set_value", [extension.NumberParam("value")]),
////   ],
//// )
////
//// // Build a gauge widget
//// pub fn gauge(id: String, value: Float, opts: List(GaugeOpt)) -> Node {
////   extension.build(gauge_def, id, [
////     #("value", node.FloatVal(value)),
////     ..gauge_opts_to_props(opts)
////   ])
//// }
////
//// // Send a command to a gauge
//// pub fn set_gauge_value(node_id: String, value: Float) -> Command(msg) {
////   extension.command(gauge_def, node_id, "set_value", [
////     #("value", node.FloatVal(value)),
////   ])
//// }
//// ```
////
//// ## Composite widget extensions
////
//// Composite widgets are simpler -- they're just functions that return
//// Node trees. No registration or Rust code needed.
////
//// ```gleam
//// import plushie/node.{type Node}
//// import plushie/ui
//// import plushie/prop/padding
////
//// // A labeled input composite widget
//// pub fn labeled_input(
////   id: String,
////   label: String,
////   value: String,
////   children: List(Node),
//// ) -> Node {
////   ui.column(id, [column.Spacing(4)], [
////     ui.text_(id <> "-label", label),
////     ui.text_input(id <> "-input", value, []),
////     ..children
////   ])
//// }
//// ```

import gleam/dict
import gleam/list
import plushie/command.{type Command}
import plushie/node.{type Node, type PropValue, Node}

// -- Extension definition ----------------------------------------------------

/// Definition of a native widget extension.
///
/// Describes the Rust crate, constructor, props, and commands that a
/// native widget supports. Used at compile time to configure the plushie
/// binary build and at runtime to construct nodes and commands.
pub type ExtensionDef {
  ExtensionDef(
    /// Widget kind string (e.g., "gauge"). Must match the Rust crate's
    /// registered widget type name.
    kind: String,
    /// Path to the Rust crate relative to the project root
    /// (e.g., "native/my_gauge").
    rust_crate: String,
    /// Rust expression to construct the extension instance
    /// (e.g., "my_gauge::GaugeExtension::new()").
    rust_constructor: String,
    /// Declared properties with their types, for documentation and
    /// build tooling validation.
    props: List(PropDef),
    /// Declared commands that can be sent to this widget type.
    commands: List(CommandDef),
  )
}

/// Property definition for an extension widget.
pub type PropDef {
  NumberProp(name: String)
  StringProp(name: String)
  BooleanProp(name: String)
  ColorProp(name: String)
  LengthProp(name: String)
  PaddingProp(name: String)
  AlignmentProp(name: String)
  FontProp(name: String)
  StyleProp(name: String)
  MapProp(name: String)
  AnyProp(name: String)
  ListProp(name: String, inner: String)
}

/// Command definition for an extension widget.
pub type CommandDef {
  CommandDef(name: String, params: List(ParamDef))
}

/// Parameter definition for extension commands.
pub type ParamDef {
  NumberParam(name: String)
  StringParam(name: String)
  BooleanParam(name: String)
}

// -- Runtime API -------------------------------------------------------------

/// Build a node for a native extension widget.
///
/// Creates a Node with the extension's kind and the given props.
/// Props are passed as key-value pairs already encoded to PropValue.
pub fn build(
  def: ExtensionDef,
  id: String,
  props: List(#(String, PropValue)),
) -> Node {
  Node(
    id:,
    kind: def.kind,
    props: dict.from_list(props),
    children: [],
    meta: dict.new(),
  )
}

/// Build a container node for a native extension widget with children.
pub fn build_container(
  def: ExtensionDef,
  id: String,
  props: List(#(String, PropValue)),
  children: List(Node),
) -> Node {
  Node(
    id:,
    kind: def.kind,
    props: dict.from_list(props),
    children:,
    meta: dict.new(),
  )
}

/// Create an extension command targeting a specific widget instance.
///
/// The command is sent via the wire protocol's `extension_command`
/// message type and delivered to the Rust widget by node ID.
pub fn command(
  _def: ExtensionDef,
  node_id: String,
  op: String,
  payload: List(#(String, PropValue)),
) -> Command(msg) {
  command.ExtensionCommand(node_id:, op:, payload: dict.from_list(payload))
}

/// Create a batch of extension commands.
pub fn commands(
  _def: ExtensionDef,
  cmds: List(#(String, String, List(#(String, PropValue)))),
) -> Command(msg) {
  command.ExtensionCommands(
    commands: list.map(cmds, fn(cmd) {
      let #(node_id, op, payload) = cmd
      #(node_id, op, dict.from_list(payload))
    }),
  )
}

/// Get the prop definition names from an extension definition.
pub fn prop_names(def: ExtensionDef) -> List(String) {
  list.map(def.props, prop_def_name)
}

/// Get the command definition names from an extension definition.
pub fn command_names(def: ExtensionDef) -> List(String) {
  list.map(def.commands, fn(cmd) { cmd.name })
}

/// Reserved property names that must not be used in extension definitions.
const reserved_names = ["id", "type", "children", "a11y"]

/// Validate an extension definition at runtime.
///
/// Returns `Ok(Nil)` when valid, or `Error(errors)` with a list of
/// human-readable validation failure messages.
///
/// Checks performed:
/// - `kind` must be non-empty
/// - No duplicate prop names
/// - No reserved prop names (id, type, children, a11y)
pub fn validate(def: ExtensionDef) -> Result(Nil, List(String)) {
  let names = list.map(def.props, prop_def_name)
  let kind_errors = case def.kind {
    "" -> ["kind must not be empty"]
    _ -> []
  }
  let duplicate_errors = find_duplicate_names(names, [], [])
  let reserved_errors =
    list.filter_map(names, fn(name) {
      case list.contains(reserved_names, name) {
        True -> Ok("prop name \"" <> name <> "\" is reserved")
        False -> Error(Nil)
      }
    })
  let all_errors =
    list.flatten([kind_errors, duplicate_errors, reserved_errors])
  case all_errors {
    [] -> Ok(Nil)
    errors -> Error(errors)
  }
}

fn find_duplicate_names(
  names: List(String),
  seen: List(String),
  dupes: List(String),
) -> List(String) {
  case names {
    [] -> dupes
    [name, ..rest] ->
      case list.contains(seen, name) {
        True ->
          case list.contains(dupes, name) {
            True -> find_duplicate_names(rest, seen, dupes)
            False ->
              find_duplicate_names(
                rest,
                seen,
                list.append(dupes, [
                  "duplicate prop name \"" <> name <> "\"",
                ]),
              )
          }
        False -> find_duplicate_names(rest, [name, ..seen], dupes)
      }
  }
}

fn prop_def_name(prop: PropDef) -> String {
  case prop {
    NumberProp(name:) -> name
    StringProp(name:) -> name
    BooleanProp(name:) -> name
    ColorProp(name:) -> name
    LengthProp(name:) -> name
    PaddingProp(name:) -> name
    AlignmentProp(name:) -> name
    FontProp(name:) -> name
    StyleProp(name:) -> name
    MapProp(name:) -> name
    AnyProp(name:) -> name
    ListProp(name:, ..) -> name
  }
}
