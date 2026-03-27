//// Tree operations: normalization, diffing, and search.
////
//// After `view(model)` produces a `Node` tree, `normalize` applies scoped
//// IDs and resolves a11y references. After each update cycle, `diff`
//// compares old and new normalized trees to produce `PatchOp` lists for
//// the wire protocol.

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, Some}
import gleam/set
import gleam/string
import plushie/canvas_widget
import plushie/node.{
  type Node, type PropValue, DictVal, Node, NullVal, StringVal,
}
import plushie/patch.{
  type PatchOp, InsertChild, RemoveChild, ReplaceNode, UpdateProps,
}
import plushie/platform

// --- Normalize ---------------------------------------------------------------

/// Normalize a node tree by applying scoped IDs and resolving a11y
/// references. Call this on the output of `view(model)` before diffing.
///
/// Scoping rules:
/// - Named (non-empty-ID) non-window nodes create scope boundaries.
///   Their children's IDs become `parent_id/child_id`.
/// - Window nodes reset scope -- children start with no scope prefix.
/// - Empty-ID nodes don't create scope boundaries.
pub fn normalize(node: Node) -> Node {
  normalize_ctx(node, "", "", canvas_widget.empty_registry())
}

/// Normalize a top-level app view and enforce explicit windows.
///
/// A view must return either:
/// - a single `window` node
/// - a root node whose direct children are all `window` nodes
pub fn normalize_view(
  node: Node,
  registry: canvas_widget.Registry,
) -> Result(Node, String) {
  let normalized = normalize_with_registry(node, registry)

  case normalized.kind {
    "window" -> Ok(normalized)
    _ -> {
      let direct_windows =
        !list.is_empty(normalized.children)
        && list.all(normalized.children, fn(child) { child.kind == "window" })

      case direct_windows {
        True -> Ok(normalized)
        False ->
          Error(
            "view must return a window node or a root node whose direct children are window nodes",
          )
      }
    }
  }
}

/// Normalize with a canvas widget registry. Canvas widget placeholders
/// in the tree are rendered using stored state from the registry.
pub fn normalize_with_registry(
  node: Node,
  registry: canvas_widget.Registry,
) -> Node {
  normalize_ctx(node, "", "", registry)
}

fn normalize_ctx(
  node: Node,
  scope: String,
  window_id: String,
  registry: canvas_widget.Registry,
) -> Node {
  let current_window_id = case node.kind {
    "window" -> node.id
    _ -> window_id
  }

  // Validate: user-provided IDs (non-empty) must not contain "/"
  case node.id {
    "" -> Nil
    id ->
      case string.contains(id, "/") {
        True ->
          platform.log_warning(
            "plushie: widget ID \""
            <> id
            <> "\" contains \"/\" -- scoped paths are built automatically by named containers",
          )
        False -> Nil
      }
  }

  let scoped_id = apply_scope(node.id, scope)

  // Canvas widget rendering: if this node is a placeholder, render it
  // with stored state and normalize the output. The rendered canvas
  // node has no __canvas_widget__ tags in its props, so normalization
  // won't re-trigger rendering (no recursion). Widget metadata is
  // attached to the final node's props for registry derivation.
  case canvas_widget.is_placeholder(node) {
    True -> {
      case
        canvas_widget.render_placeholder(
          node,
          current_window_id,
          scoped_id,
          node.id,
          registry,
        )
      {
        Some(#(rendered_node, _entry)) -> {
          // The rendered node already has the scoped_id set and metadata
          // attached. Normalize its children at the same scope position
          // and resolve a11y references in its props.
          let child_scope = case rendered_node.kind, rendered_node.id {
            "window", _ -> ""
            _, "" -> scope
            _, _ -> scoped_id
          }
          let props = resolve_a11y_refs(rendered_node.props, scope)
          let children =
            list.map(rendered_node.children, fn(child) {
              normalize_ctx(child, child_scope, current_window_id, registry)
            })
          check_duplicate_sibling_ids(children)
          Node(..rendered_node, props:, children:)
        }
        _ -> {
          // Fallback: normalize as a regular node
          normalize_regular(node, scoped_id, scope, current_window_id, registry)
        }
      }
    }
    False ->
      normalize_regular(node, scoped_id, scope, current_window_id, registry)
  }
}

fn normalize_regular(
  node: Node,
  scoped_id: String,
  scope: String,
  window_id: String,
  registry: canvas_widget.Registry,
) -> Node {
  // Windows reset scope; empty IDs don't create scope boundaries.
  let child_scope = case node.kind, node.id {
    "window", _ -> ""
    _, "" -> scope
    _, _ -> scoped_id
  }

  let props = resolve_a11y_refs(node.props, scope)

  let children =
    list.map(node.children, fn(child) {
      normalize_ctx(child, child_scope, window_id, registry)
    })

  // Reject duplicate sibling IDs before diffing.
  check_duplicate_sibling_ids(children)

  Node(id: scoped_id, kind: node.kind, props:, children:, meta: dict.new())
}

fn check_duplicate_sibling_ids(children: List(Node)) -> Nil {
  let ids = list.map(children, fn(child) { child.id })
  let unique = list.unique(ids)
  case list.length(ids) != list.length(unique) {
    False -> Nil
    True -> {
      let dupes =
        ids
        |> list.fold(#(set.new(), []), fn(acc, id) {
          let #(seen, found) = acc
          case set.contains(seen, id) {
            True -> #(seen, [id, ..found])
            False -> #(set.insert(seen, id), found)
          }
        })
        |> fn(pair) { pair.1 }
        |> list.unique
      let message =
        "plushie: duplicate sibling IDs detected during normalize: "
        <> string.inspect(dupes)
      panic as message
    }
  }
}

fn apply_scope(id: String, scope: String) -> String {
  case scope, id {
    "", _ -> id
    _, "" -> id
    _, _ -> scope <> "/" <> id
  }
}

fn resolve_a11y_refs(
  props: Dict(String, PropValue),
  scope: String,
) -> Dict(String, PropValue) {
  case dict.get(props, "a11y") {
    Ok(DictVal(a11y_props)) -> {
      let a11y_props = resolve_ref(a11y_props, "labelled_by", scope)
      let a11y_props = resolve_ref(a11y_props, "described_by", scope)
      let a11y_props = resolve_ref(a11y_props, "error_message", scope)
      dict.insert(props, "a11y", DictVal(a11y_props))
    }
    _ -> props
  }
}

fn resolve_ref(
  props: Dict(String, PropValue),
  key: String,
  scope: String,
) -> Dict(String, PropValue) {
  case scope, dict.get(props, key) {
    "", _ -> props
    _, Ok(StringVal(ref_id)) ->
      case ref_id {
        "" -> props
        _ ->
          case string.contains(ref_id, "/") {
            // Already a full scoped path -- leave it alone.
            True -> props
            False -> dict.insert(props, key, StringVal(scope <> "/" <> ref_id))
          }
      }
    _, _ -> props
  }
}

// --- Diff --------------------------------------------------------------------

/// Compare two normalized trees and return a list of patch operations
/// that transform `old` into `new`.
///
/// Paths are lists of integer child indices from the root. For example,
/// `[0, 2]` means "root's first child, then that node's third child".
///
/// The algorithm uses O(n) set comparison for reorder detection rather
/// than O(n^2) LCS. When children are reordered, the entire node is
/// replaced rather than computing minimal moves -- a deliberate
/// simplicity-over-optimality tradeoff matching the reference implementation.
pub fn diff(old: Node, new: Node) -> List(PatchOp) {
  // Different ID at root -> full replace
  case old.id != new.id {
    True -> [ReplaceNode(path: [], node: new)]
    False -> diff_node(old, new, [])
  }
}

fn diff_node(old: Node, new: Node, path: List(Int)) -> List(PatchOp) {
  // Different type -> full replacement at this path.
  case old.kind != new.kind {
    True -> [ReplaceNode(path:, node: new)]
    False -> {
      // Check for reordered children -- if so, replace the whole node.
      case children_reordered(old.children, new.children) {
        True -> [ReplaceNode(path:, node: new)]
        False -> {
          let prop_ops = diff_props(old.props, new.props, path)
          let child_ops =
            diff_children_ordered(old.children, new.children, path)
          list.append(prop_ops, child_ops)
        }
      }
    }
  }
}

fn diff_props(
  old_props: Dict(String, PropValue),
  new_props: Dict(String, PropValue),
  path: List(Int),
) -> List(PatchOp) {
  case old_props == new_props {
    True -> []
    False -> {
      // Changed or added keys.
      let changed =
        dict.fold(new_props, dict.new(), fn(acc, k, v) {
          case dict.get(old_props, k) {
            Ok(old_v) if old_v == v -> acc
            _ -> dict.insert(acc, k, v)
          }
        })

      // Removed keys -> NullVal.
      let removed =
        dict.fold(old_props, dict.new(), fn(acc, k, _v) {
          case dict.has_key(new_props, k) {
            True -> acc
            False -> dict.insert(acc, k, NullVal)
          }
        })

      let merged = dict.merge(changed, removed)

      case dict.is_empty(merged) {
        True -> []
        False -> [UpdateProps(path:, props: merged)]
      }
    }
  }
}

fn children_reordered(old: List(Node), new: List(Node)) -> Bool {
  let old_ids = list.map(old, fn(c) { c.id })
  let new_ids = list.map(new, fn(c) { c.id })
  let old_set = set.from_list(old_ids)
  let new_set = set.from_list(new_ids)
  let common_old = list.filter(old_ids, fn(id) { set.contains(new_set, id) })
  let common_new = list.filter(new_ids, fn(id) { set.contains(old_set, id) })
  common_old != common_new
}

/// Diff children when no reorder has occurred. Produces removal, update,
/// and insertion ops in the correct order.
///
/// Operation ordering is load-bearing:
/// 1. Removals in descending index order (avoids index shift)
/// 2. Updates with adjusted indices (accounting for removals)
/// 3. Insertions in ascending index order
fn diff_children_ordered(
  old_children: List(Node),
  new_children: List(Node),
  parent_path: List(Int),
) -> List(PatchOp) {
  let old_indexed =
    list.index_map(old_children, fn(child, idx) { #(child, idx) })
  let old_by_id =
    list.fold(old_indexed, dict.new(), fn(acc, pair) {
      dict.insert(acc, { pair.0 }.id, pair)
    })
  let new_by_id =
    list.fold(
      list.index_map(new_children, fn(child, idx) { #(child, idx) }),
      dict.new(),
      fn(acc, pair) { dict.insert(acc, { pair.0 }.id, pair) },
    )

  // Find removed child indices (old children not in new)
  let removed_indices =
    old_indexed
    |> list.filter(fn(pair) { !dict.has_key(new_by_id, { pair.0 }.id) })
    |> list.map(fn(pair) { pair.1 })

  // Removals: descending index order
  let remove_ops =
    removed_indices
    |> list.sort(fn(a, b) {
      case a > b {
        True -> order.Lt
        False ->
          case a == b {
            True -> order.Eq
            False -> order.Gt
          }
      }
    })
    |> list.map(fn(idx) { RemoveChild(path: parent_path, index: idx) })

  // Walk new children for updates and inserts
  let #(update_ops, insert_ops) =
    new_children
    |> list.index_map(fn(child, idx) { #(child, idx) })
    |> list.fold(#([], []), fn(acc, pair) {
      let #(updates, inserts) = acc
      let #(child, new_idx) = pair
      case dict.get(old_by_id, child.id) {
        Ok(#(old_child, old_idx)) -> {
          // Adjust index: subtract removals that were before this position
          let adjusted_idx = index_after_removals(old_idx, removed_indices)
          let child_path = list.append(parent_path, [adjusted_idx])
          let ops = diff_node(old_child, child, child_path)
          #(list.append(updates, ops), inserts)
        }
        Error(_) -> {
          let insert =
            InsertChild(path: parent_path, index: new_idx, node: child)
          #(updates, list.append(inserts, [insert]))
        }
      }
    })

  list.flatten([remove_ops, update_ops, insert_ops])
}

/// Compute the adjusted index of an old child after removals.
/// Counts how many removed indices were below the target index.
fn index_after_removals(old_idx: Int, removed_indices: List(Int)) -> Int {
  let count_below =
    list.count(removed_indices, fn(removed_idx) { removed_idx < old_idx })
  old_idx - count_below
}

import gleam/order

// --- Search ------------------------------------------------------------------

/// Find a node by its ID (depth-first). Returns the first match.
///
/// Matches against the full ID first. If no match is found and the
/// target does not contain "/", falls back to matching the local
/// segment (the part after the last "/") of each node's ID.
pub fn find(tree: Node, id: String) -> Option(Node) {
  case find_exact(tree, id) {
    option.Some(_) as found -> found
    option.None ->
      case string.contains(id, "/") {
        True -> option.None
        False -> find_by_local(tree, id)
      }
  }
}

fn find_exact(tree: Node, id: String) -> Option(Node) {
  case tree.id == id {
    True -> option.Some(tree)
    False -> find_exact_in_children(tree.children, id)
  }
}

fn find_exact_in_children(children: List(Node), id: String) -> Option(Node) {
  case children {
    [] -> option.None
    [child, ..rest] ->
      case find_exact(child, id) {
        option.Some(found) -> option.Some(found)
        option.None -> find_exact_in_children(rest, id)
      }
  }
}

fn find_by_local(tree: Node, target: String) -> Option(Node) {
  let local = case string.split(tree.id, "/") {
    [] -> tree.id
    segments ->
      case list.last(segments) {
        Ok(last) -> last
        Error(_) -> tree.id
      }
  }
  case local == target {
    True -> option.Some(tree)
    False -> find_by_local_in_children(tree.children, target)
  }
}

fn find_by_local_in_children(
  children: List(Node),
  target: String,
) -> Option(Node) {
  case children {
    [] -> option.None
    [child, ..rest] ->
      case find_by_local(child, target) {
        option.Some(found) -> option.Some(found)
        option.None -> find_by_local_in_children(rest, target)
      }
  }
}

/// Check whether a node with the given ID exists anywhere in the tree.
pub fn exists(tree: Node, id: String) -> Bool {
  option.is_some(find(tree, id))
}

/// Collect all nodes matching a predicate (depth-first order).
pub fn find_all(tree: Node, predicate: fn(Node) -> Bool) -> List(Node) {
  do_find_all(tree, predicate, [])
  |> list.reverse()
}

fn do_find_all(
  node: Node,
  predicate: fn(Node) -> Bool,
  acc: List(Node),
) -> List(Node) {
  let acc = case predicate(node) {
    True -> [node, ..acc]
    False -> acc
  }
  list.fold(node.children, acc, fn(a, child) {
    do_find_all(child, predicate, a)
  })
}

/// Return all node IDs in depth-first order.
pub fn ids(tree: Node) -> List(String) {
  [tree.id, ..list.flat_map(tree.children, ids)]
}
