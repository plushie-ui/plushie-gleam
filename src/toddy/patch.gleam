//// Patch operations for tree diffs.
////
//// Produced by `tree.diff` and consumed by `protocol/encode` to send
//// incremental updates to the Rust binary. Each operation targets a
//// node by its path (list of child indices from the root).

import gleam/dict.{type Dict}
import toddy/node.{type Node, type PropValue}

/// A single patch operation.
pub type PatchOp {
  /// Replace an entire subtree at the given path.
  ReplaceNode(path: String, node: Node)
  /// Update specific props on the node at the given path.
  UpdateProps(path: String, props: Dict(String, PropValue))
  /// Insert a new child node at the given path and index.
  InsertChild(path: String, index: Int, node: Node)
  /// Remove the node at the given path.
  DeleteNode(path: String)
  /// Move the node at the given path to a new child index.
  MoveNode(path: String, index: Int)
}
