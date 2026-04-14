//// Tree operations: normalization, diffing, and search.
////
//// After `view(model)` produces a `Node` tree, `normalize` applies scoped
//// IDs and resolves a11y references. After each update cycle, `diff`
//// compares old and new normalized trees to produce `PatchOp` lists for
//// the wire protocol.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, Some}
import gleam/set
import gleam/string
import plushie/node.{
  type Node, type PropValue, DictVal, IntVal, ListVal, Node, NullVal, OpaqueVal,
  StringVal,
}
import plushie/patch.{
  type PatchOp, InsertChild, RemoveChild, ReplaceNode, UpdateProps,
}
import plushie/platform
import plushie/widget

/// Cache of memo-ized subtrees from the previous render cycle. Maps
/// scoped memo ID to (dependency_value, normalized_subtree). On cache
/// hit (same dependency), the subtree is returned without re-normalizing.
pub type MemoCache =
  Dict(String, #(Dynamic, Node))

/// Create an empty memo cache for the first render cycle.
pub fn empty_memo_cache() -> MemoCache {
  dict.new()
}

// --- Normalize ---------------------------------------------------------------

/// Normalize a node tree by applying scoped IDs and resolving a11y
/// references. Call this on the output of `view(model)` before diffing.
///
/// Scoping rules:
/// - Window nodes keep bare IDs. Their children get `window#child_id`.
/// - Named (non-empty-ID) non-window nodes create scope boundaries.
///   Deeper descendants get `window#parent/child` (the `#` separator
///   only appears at the window boundary).
/// - Empty-ID nodes don't create scope boundaries.
pub fn normalize(node: Node) -> Node {
  let #(normalized, _cache) =
    normalize_ctx(
      node,
      "",
      "",
      widget.empty_registry(),
      0,
      dict.new(),
      dict.new(),
    )
  normalized
}

/// Normalize a top-level app view and enforce explicit windows.
///
/// Accepts the previous render cycle's memo cache and returns the
/// new cache alongside the normalized tree. Memo nodes whose
/// dependency hasn't changed reuse the cached subtree.
///
/// A view must return either:
/// - a single `window` node
/// - a root node whose direct children are all `window` nodes
pub fn normalize_view(
  node: Node,
  registry: widget.Registry,
  prev_memo_cache: MemoCache,
) -> Result(#(Node, MemoCache), String) {
  let #(normalized, new_cache) =
    normalize_with_memo(node, registry, prev_memo_cache)

  case normalized.kind {
    "window" -> Ok(#(normalized, new_cache))
    _ -> {
      let direct_windows =
        !list.is_empty(normalized.children)
        && list.all(normalized.children, fn(child) { child.kind == "window" })

      case direct_windows {
        True -> Ok(#(normalized, new_cache))
        False ->
          Error(
            "view must return a window node or a root node whose direct children are window nodes",
          )
      }
    }
  }
}

/// Normalize with a widget registry and memo cache.
pub fn normalize_with_memo(
  node: Node,
  registry: widget.Registry,
  prev_memo_cache: MemoCache,
) -> #(Node, MemoCache) {
  let #(normalized, new_cache) =
    normalize_ctx(node, "", "", registry, 0, prev_memo_cache, dict.new())
  #(normalized, new_cache)
}

/// Normalize with a widget registry. Widget placeholders
/// in the tree are rendered using stored state from the registry.
pub fn normalize_with_registry(node: Node, registry: widget.Registry) -> Node {
  let #(normalized, _cache) =
    normalize_ctx(node, "", "", registry, 0, dict.new(), dict.new())
  normalized
}

fn normalize_ctx(
  node: Node,
  scope: String,
  window_id: String,
  registry: widget.Registry,
  depth: Int,
  prev_cache: MemoCache,
  new_cache: MemoCache,
) -> #(Node, MemoCache) {
  case depth >= 256 {
    True -> panic as "tree exceeds maximum depth of 256 levels"
    False ->
      case depth == 200 {
        True ->
          platform.log_warning(
            "plushie: tree depth reached 200 levels, maximum is 256",
          )
        False -> Nil
      }
  }

  let current_window_id = case node.kind {
    "window" -> node.id
    _ -> window_id
  }

  // Validate user-provided IDs (skip auto-generated IDs starting with "auto:")
  case node.id {
    "" -> Nil
    id ->
      case string.starts_with(id, "auto:") {
        True -> Nil
        False -> validate_user_id(id)
      }
  }

  let scoped_id = apply_scope(node.id, scope)

  // Memo nodes: check cache before normalizing children. The __memo__
  // wrapper is transparent; we return the normalized child directly.
  case node.kind {
    "__memo__" -> {
      case dict.get(node.meta, "__memo_dep__") {
        Ok(OpaqueVal(dep)) ->
          case dict.get(prev_cache, scoped_id) {
            Ok(#(prev_dep, cached_node)) if prev_dep == dep -> {
              // Cache hit: reuse the previously normalized subtree
              let new_cache =
                dict.insert(new_cache, scoped_id, #(dep, cached_node))
              #(cached_node, new_cache)
            }
            _ ->
              normalize_memo_child(
                node,
                scoped_id,
                scope,
                current_window_id,
                registry,
                depth,
                prev_cache,
                new_cache,
                dep,
              )
          }
        _ ->
          // No dependency stored; always normalize fresh (no caching)
          normalize_memo_fresh(
            node,
            scope,
            current_window_id,
            registry,
            depth,
            prev_cache,
            new_cache,
          )
      }
    }
    _ -> {
      // Widget rendering: if this node is a placeholder, render it
      // with stored state and normalize the output. The rendered node
      // has no __widget__ tags in its meta, so normalization won't
      // re-trigger rendering (no recursion). Widget metadata is
      // attached to the final node's meta for registry derivation.
      case widget.is_placeholder(node) {
        True -> {
          case
            widget.render_placeholder(
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
                "window", _ -> scoped_id <> "#"
                _, "" -> scope
                _, _ -> scoped_id
              }
              // Forward standard widget props (a11y, event_rate) from the
              // placeholder to the rendered output so widget authors don't
              // need to handle them manually.
              let props =
                widget.merge_standard_props(rendered_node.props, node.props)
              let props = resolve_a11y_refs(props, scope)
              let #(children, new_cache) =
                normalize_children(
                  rendered_node.children,
                  child_scope,
                  current_window_id,
                  registry,
                  depth + 1,
                  prev_cache,
                  new_cache,
                )
              check_duplicate_sibling_ids(children)
              #(Node(..rendered_node, props:, children:), new_cache)
            }
            _ -> {
              // Fallback: normalize as a regular node
              normalize_regular(
                node,
                scoped_id,
                scope,
                current_window_id,
                registry,
                depth,
                prev_cache,
                new_cache,
              )
            }
          }
        }
        False ->
          normalize_regular(
            node,
            scoped_id,
            scope,
            current_window_id,
            registry,
            depth,
            prev_cache,
            new_cache,
          )
      }
    }
  }
}

fn normalize_regular(
  node: Node,
  scoped_id: String,
  scope: String,
  window_id: String,
  registry: widget.Registry,
  depth: Int,
  prev_cache: MemoCache,
  new_cache: MemoCache,
) -> #(Node, MemoCache) {
  // Windows set child scope to "window_id#"; empty IDs are transparent.
  let child_scope = case node.kind, node.id {
    "window", _ -> scoped_id <> "#"
    _, "" -> scope
    _, _ -> scoped_id
  }

  let props = resolve_a11y_refs(node.props, scope)

  let #(children, new_cache) =
    normalize_children(
      node.children,
      child_scope,
      window_id,
      registry,
      depth + 1,
      prev_cache,
      new_cache,
    )

  // Reject duplicate sibling IDs before diffing.
  check_duplicate_sibling_ids(children)

  let children = infer_radio_a11y(children)

  #(
    Node(id: scoped_id, kind: node.kind, props:, children:, meta: dict.new()),
    new_cache,
  )
}

/// Fold over children, threading the memo cache through each recursive
/// normalize_ctx call so earlier siblings' cache entries are visible to
/// later siblings.
fn normalize_children(
  children: List(Node),
  scope: String,
  window_id: String,
  registry: widget.Registry,
  depth: Int,
  prev_cache: MemoCache,
  new_cache: MemoCache,
) -> #(List(Node), MemoCache) {
  let #(children_rev, new_cache) =
    list.fold(children, #([], new_cache), fn(acc, child) {
      let #(kids, cache) = acc
      let #(normalized_child, cache) =
        normalize_ctx(
          child,
          scope,
          window_id,
          registry,
          depth,
          prev_cache,
          cache,
        )
      #([normalized_child, ..kids], cache)
    })
  #(list.reverse(children_rev), new_cache)
}

/// Normalize a memo node's first child and cache the result.
fn normalize_memo_child(
  node: Node,
  scoped_id: String,
  scope: String,
  window_id: String,
  registry: widget.Registry,
  depth: Int,
  prev_cache: MemoCache,
  new_cache: MemoCache,
  dep: Dynamic,
) -> #(Node, MemoCache) {
  case node.children {
    [content, ..] -> {
      let #(normalized_child, new_cache) =
        normalize_ctx(
          content,
          scope,
          window_id,
          registry,
          depth + 1,
          prev_cache,
          new_cache,
        )
      let new_cache =
        dict.insert(new_cache, scoped_id, #(dep, normalized_child))
      #(normalized_child, new_cache)
    }
    [] -> {
      let empty =
        Node(
          id: scoped_id,
          kind: "container",
          props: dict.new(),
          children: [],
          meta: dict.new(),
        )
      let new_cache = dict.insert(new_cache, scoped_id, #(dep, empty))
      #(empty, new_cache)
    }
  }
}

/// Normalize a memo node's first child without caching (no dependency
/// was provided, so we can't determine staleness).
fn normalize_memo_fresh(
  node: Node,
  scope: String,
  window_id: String,
  registry: widget.Registry,
  depth: Int,
  prev_cache: MemoCache,
  new_cache: MemoCache,
) -> #(Node, MemoCache) {
  case node.children {
    [content, ..] ->
      normalize_ctx(
        content,
        scope,
        window_id,
        registry,
        depth + 1,
        prev_cache,
        new_cache,
      )
    [] -> #(
      Node(
        id: "",
        kind: "container",
        props: dict.new(),
        children: [],
        meta: dict.new(),
      ),
      new_cache,
    )
  }
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

/// Detect radio button siblings and auto-set position_in_set and
/// size_of_set a11y props. Non-radio children pass through unchanged.
fn infer_radio_a11y(children: List(Node)) -> List(Node) {
  let radio_count = list.count(children, fn(child) { child.kind == "radio" })
  case radio_count > 0 {
    False -> children
    True -> {
      let #(result_rev, _) =
        list.fold(children, #([], 0), fn(acc, child) {
          let #(nodes, pos) = acc
          case child.kind == "radio" {
            False -> #([child, ..nodes], pos)
            True -> {
              let new_pos = pos + 1
              let a11y_props = case dict.get(child.props, "a11y") {
                Ok(DictVal(existing)) -> existing
                _ -> dict.new()
              }
              let a11y_props =
                a11y_props
                |> dict.insert("position_in_set", IntVal(new_pos))
                |> dict.insert("size_of_set", IntVal(radio_count))
              let props = dict.insert(child.props, "a11y", DictVal(a11y_props))
              #([Node(..child, props:), ..nodes], new_pos)
            }
          }
        })
      list.reverse(result_rev)
    }
  }
}

/// Validate a user-provided widget ID. Called for non-auto-generated,
/// non-empty IDs during normalization. Panics on invalid IDs
/// (programming error).
fn validate_user_id(id: String) -> Nil {
  case string.contains(id, "/") {
    True ->
      panic as {
        "widget ID \""
        <> id
        <> "\" cannot contain \"/\": scoped paths are built automatically by named containers"
      }
    False -> Nil
  }
  case string.contains(id, "#") {
    True ->
      panic as {
        "widget ID \""
        <> id
        <> "\" cannot contain \"#\": \"#\" is reserved for window-qualified paths (e.g., \"window#widget\")"
      }
    False -> Nil
  }
  case string.byte_size(id) > 1024 {
    True ->
      panic as {
        "widget ID \"" <> id <> "\" exceeds maximum length of 1024 bytes"
      }
    False -> Nil
  }
  case is_printable_ascii(id) {
    False ->
      panic as {
        "widget ID \""
        <> id
        <> "\" contains invalid characters: IDs must contain only printable ASCII (0x21-0x7E)"
      }
    True -> Nil
  }
}

/// Check that all bytes in a string are printable ASCII (0x21-0x7E).
fn is_printable_ascii(s: String) -> Bool {
  s
  |> string.to_utf_codepoints
  |> list.all(fn(cp) {
    let v = string.utf_codepoint_to_int(cp)
    v >= 0x21 && v <= 0x7E
  })
}

fn apply_scope(id: String, scope: String) -> String {
  case scope, id {
    "", _ -> id
    _, "" -> id
    _, _ ->
      case string.ends_with(scope, "#") {
        // Window boundary: scope is "window#", join without "/"
        True -> scope <> id
        // Normal scope: join with "/"
        False -> scope <> "/" <> id
      }
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
            // Already a full scoped path; leave it alone.
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
/// replaced rather than computing minimal moves, a deliberate
/// simplicity-over-optimality tradeoff matching the reference implementation.
pub fn diff(old: Node, new: Node) -> List(PatchOp) {
  // Different ID at root -> full replace
  case old.id != new.id {
    True -> [ReplaceNode(path: [], node: new)]
    False -> diff_node(old, new, [])
  }
}

fn diff_node(old: Node, new: Node, path: List(Int)) -> List(PatchOp) {
  // Structural equality: when old and new are the same term (e.g. from
  // memo cache hit), the subtree is unchanged. On BEAM, == on identical
  // references is O(1).
  case old == new {
    True -> []
    False ->
      case old.kind != new.kind {
        // Different type -> full replacement
        True -> [ReplaceNode(path:, node: new)]
        False ->
          case children_reordered(old.children, new.children) {
            // Reordered children -> full replacement
            True -> [ReplaceNode(path:, node: new)]
            False -> {
              let prop_ops = diff_props(old.props, new.props, path)
              let child_ops = diff_children(old.children, new.children, path)
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
      // Changed or added keys. For list props where every element has
      // an "id" key, use ID-keyed comparison to avoid false positives
      // from reconstructed lists with identical content.
      let changed =
        dict.fold(new_props, dict.new(), fn(acc, k, v) {
          case dict.get(old_props, k) {
            Ok(old_v) if old_v == v -> acc
            Ok(old_v) ->
              case lists_equal_by_id(old_v, v) {
                True -> acc
                False -> dict.insert(acc, k, v)
              }
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

/// Second-chance comparison for list props where every element is a
/// DictVal with an "id" key. Compares elements by ID to detect that
/// a reconstructed list hasn't actually changed. This avoids resending
/// large shape lists when the canvas re-renders without shape changes.
fn lists_equal_by_id(old: PropValue, new: PropValue) -> Bool {
  case old, new {
    ListVal(old_items), ListVal(new_items) ->
      case list.length(old_items) == list.length(new_items) {
        False -> False
        True -> {
          // Check every element is a DictVal with an "id" key
          let all_have_ids =
            list.all(old_items, has_id_key) && list.all(new_items, has_id_key)
          case all_have_ids {
            False -> False
            True -> {
              // Build ID -> value map for old, then check each new element
              let old_by_id =
                list.fold(old_items, dict.new(), fn(acc, item) {
                  case item {
                    DictVal(d) ->
                      case dict.get(d, "id") {
                        Ok(StringVal(id)) -> dict.insert(acc, id, item)
                        _ -> acc
                      }
                    _ -> acc
                  }
                })
              list.all(new_items, fn(item) {
                case item {
                  DictVal(d) ->
                    case dict.get(d, "id") {
                      Ok(StringVal(id)) ->
                        case dict.get(old_by_id, id) {
                          Ok(old_item) -> old_item == item
                          Error(_) -> False
                        }
                      _ -> False
                    }
                  _ -> False
                }
              })
            }
          }
        }
      }
    _, _ -> False
  }
}

fn has_id_key(item: PropValue) -> Bool {
  case item {
    DictVal(d) -> dict.has_key(d, "id")
    _ -> False
  }
}

/// Check if common elements between old and new children maintain
/// their relative order. Returns True if reordered.
fn children_reordered(old: List(Node), new: List(Node)) -> Bool {
  let old_ids = list.map(old, fn(c) { c.id })
  let new_ids = list.map(new, fn(c) { c.id })
  let old_set = set.from_list(old_ids)
  let new_set = set.from_list(new_ids)
  let common_old = list.filter(old_ids, fn(id) { set.contains(new_set, id) })
  let common_new = list.filter(new_ids, fn(id) { set.contains(old_set, id) })
  common_old != common_new
}

/// Diff children using three strategies:
///
/// - **Fast**: ID sequences match -> pairwise prop diff, O(n)
/// - **General**: different sequences -> remove/insert/update using
///   ID-keyed lookup. Elements in both old and new are diffed in place;
///   elements only in old are removed; elements only in new are inserted.
///
/// Operation ordering is load-bearing:
/// 1. Removals in descending index order (avoids index shift)
/// 2. Updates with adjusted indices (accounting for removals)
/// 3. Insertions in ascending index order
fn diff_children(
  old_children: List(Node),
  new_children: List(Node),
  parent_path: List(Int),
) -> List(PatchOp) {
  let old_ids = list.map(old_children, fn(c) { c.id })
  let new_ids = list.map(new_children, fn(c) { c.id })

  // Fast path: same ID sequence -> pairwise diff only
  case old_ids == new_ids {
    True -> diff_children_pairwise(old_children, new_children, parent_path, 0)
    False -> diff_children_general(old_children, new_children, parent_path)
  }
}

/// Fast path: children have the same ID sequence. Walk both lists
/// in lockstep and diff each pair at their index.
fn diff_children_pairwise(
  old: List(Node),
  new: List(Node),
  parent_path: List(Int),
  idx: Int,
) -> List(PatchOp) {
  case old, new {
    [], [] -> []
    [old_child, ..old_rest], [new_child, ..new_rest] -> {
      let child_path = list.append(parent_path, [idx])
      let ops = diff_node(old_child, new_child, child_path)
      list.append(
        ops,
        diff_children_pairwise(old_rest, new_rest, parent_path, idx + 1),
      )
    }
    _, _ -> []
  }
}

/// General path: ID sequences differ. Handle removals, updates, and inserts.
fn diff_children_general(
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
  // Extract local ID: last segment after "/" and after "#"
  let local = case string.split(tree.id, "/") {
    [] -> tree.id
    segments ->
      case list.last(segments) {
        Ok(last) ->
          // Also strip the window# prefix if present
          case string.split_once(last, "#") {
            Ok(#(_, after)) -> after
            Error(_) -> last
          }
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
