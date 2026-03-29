//// Tree node types for plushie's UI tree.
////
//// `PropValue` is a JSON-like union representing wire-compatible values.
//// `Node` is the fundamental tree building block -- widget builders produce
//// these, tree operations consume them, and the protocol encoder serializes
//// them to wire format.

import gleam/dict.{type Dict}
import gleam/list

// --- PropValue ---------------------------------------------------------------

/// A wire-compatible value. Covers all JSON/MessagePack primitive types.
/// Widget builders convert typed Gleam values (Length, Padding, Color, etc.)
/// into PropValue at `build()` time.
pub type PropValue {
  StringVal(String)
  IntVal(Int)
  FloatVal(Float)
  BoolVal(Bool)
  NullVal
  /// Raw binary data. Encoded as base64 on the JSON wire format and
  /// as raw bytes on the MessagePack wire format.
  BinaryVal(BitArray)
  ListVal(List(PropValue))
  DictVal(Dict(String, PropValue))
}

// --- Node --------------------------------------------------------------------

/// A node in the UI tree. Produced by widget builders, consumed by tree
/// operations and the protocol encoder.
///
/// - `id`: widget identifier (scoped during normalization)
/// - `kind`: widget type string ("button", "column", etc.)
/// - `props`: encoded property values (string-keyed)
/// - `children`: child nodes
/// - `meta`: runtime-only metadata, never sent to the renderer
pub type Node {
  Node(
    id: String,
    kind: String,
    props: Dict(String, PropValue),
    children: List(Node),
    /// Runtime-only metadata. Not sent to the renderer. Used by the
    /// widget system for state/def storage during normalization.
    /// Widget builders should leave this as `dict.new()`.
    meta: Dict(String, PropValue),
  )
}

// --- Constructors ------------------------------------------------------------

/// Create a node with no props and no children.
pub fn new(id: String, kind: String) -> Node {
  Node(id:, kind:, props: dict.new(), children: [], meta: dict.new())
}

/// Set a single prop on a node.
pub fn with_prop(node: Node, key: String, value: PropValue) -> Node {
  Node(..node, props: dict.insert(node.props, key, value))
}

/// Set multiple props on a node.
pub fn with_props(node: Node, props: List(#(String, PropValue))) -> Node {
  let merged =
    list.fold(props, node.props, fn(acc, pair) {
      dict.insert(acc, pair.0, pair.1)
    })
  Node(..node, props: merged)
}

/// Replace a node's children.
pub fn with_children(node: Node, children: List(Node)) -> Node {
  Node(..node, children:)
}

/// Append a child to a node.
pub fn add_child(node: Node, child: Node) -> Node {
  Node(..node, children: list.append(node.children, [child]))
}

/// An empty container node, useful as a default root.
pub fn empty_container() -> Node {
  new("", "container")
}
