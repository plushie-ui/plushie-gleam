//// Patch operations for tree diffs.
////
//// Produced by `tree.diff` and consumed by `protocol/encode` to send
//// incremental updates to the Rust binary. Each operation targets a
//// node by its path -- a list of integer child indices from the root.
//// For example, `[0, 2]` means "root's first child, then that node's
//// third child".

import gleam/dict.{type Dict}
import plushie/node.{type Node, type PropValue}

/// A single patch operation.
///
/// Operations match the Rust binary's expected format:
/// - `replace_node`: swap an entire subtree
/// - `update_props`: merge changed props (removed keys set to null)
/// - `insert_child`: add a new child at a specific index
/// - `remove_child`: remove a child at a specific index
pub type PatchOp {
  /// Replace the entire subtree at `path` with `node`.
  ReplaceNode(path: List(Int), node: Node)
  /// Merge `props` into the node at `path`. Keys with `NullVal`
  /// signal removal.
  UpdateProps(path: List(Int), props: Dict(String, PropValue))
  /// Insert `node` as a child at `index` under the node at `path`.
  InsertChild(path: List(Int), index: Int, node: Node)
  /// Remove the child at `index` from the node at `path`.
  RemoveChild(path: List(Int), index: Int)
}
