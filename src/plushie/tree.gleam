//// Tree operations: normalization, diffing, and search.
////
//// After `view(model)` produces a `Node` tree, `normalize` applies scoped
//// IDs and resolves a11y references. After each update cycle, `diff`
//// compares old and new normalized trees to produce `PatchOp` lists for
//// the wire protocol.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import gleam/string
import plushie/node.{
  type Node, type PropValue, BoolVal, DictVal, IntVal, ListVal, Node, NullVal,
  OpaqueVal, StringVal,
}
import plushie/patch.{
  type PatchOp, InsertChild, RemoveChild, ReplaceNode, UpdateProps,
}
import plushie/platform
import plushie/telemetry
import plushie/widget

/// Cache of memo-ized subtrees from the previous render cycle. Maps
/// scoped memo ID to the dependency value, normalized subtree, and
/// the widget registry entries and window IDs accumulated while
/// normalizing that subtree. On cache hit (same dependency), the
/// subtree and its accumulated data are restored without
/// re-normalizing.
pub type MemoCache =
  Dict(String, MemoCacheEntry)

/// A single entry in the memo cache.
pub type MemoCacheEntry {
  MemoCacheEntry(
    dep: Dynamic,
    node: Node,
    registry: widget.Registry,
    windows: Set(String),
  )
}

/// Create an empty memo cache for the first render cycle.
pub fn empty_memo_cache() -> MemoCache {
  dict.new()
}

/// Result of a full view normalization including accumulated state.
pub type NormalizeResult {
  NormalizeResult(
    tree: Node,
    memo_cache: MemoCache,
    registry: widget.Registry,
    windows: Set(String),
  )
}

/// Internal context threaded through the normalize pipeline. Bundles
/// the immutable environment (registry, prev_cache) and the mutable
/// accumulators (new_cache, accumulated_registry, accumulated_windows)
/// alongside per-recursion state (scope, window_id, depth).
///
/// `accumulated_registry` collects widget registry entries as they are
/// rendered during normalization, eliminating the need for a separate
/// post-normalization tree walk.
///
/// `accumulated_windows` collects window node IDs encountered during
/// normalization, eliminating the separate `detect_windows` walk.
type NormalizeCtx {
  NormalizeCtx(
    scope: String,
    window_id: String,
    registry: widget.Registry,
    depth: Int,
    prev_cache: MemoCache,
    new_cache: MemoCache,
    accumulated_registry: widget.Registry,
    accumulated_windows: Set(String),
  )
}

/// Helper to build a fresh NormalizeCtx with the given registry and
/// memo cache. All accumulators start empty.
fn new_ctx(registry: widget.Registry, prev_cache: MemoCache) -> NormalizeCtx {
  NormalizeCtx(
    scope: "",
    window_id: "",
    registry:,
    depth: 0,
    prev_cache:,
    new_cache: dict.new(),
    accumulated_registry: widget.empty_registry(),
    accumulated_windows: set.new(),
  )
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
/// - Nodes with an empty `id` are assigned an auto-ID of the form
///   `auto:<kind>:<index>` and are transparent to scoping (like other
///   auto-IDs).
pub fn normalize(node: Node) -> Node {
  let ctx = new_ctx(widget.empty_registry(), dict.new())
  let #(normalized, _ctx) = normalize_ctx(assign_auto_id(node, 0), ctx)
  post_normalize(normalized)
}

/// Collapse a list of top-level window nodes into a single tree root.
///
/// `[]` becomes an empty container (loading, transition, error screens).
/// `[single]` promotes the single window to the root directly. Multiple
/// entries wrap under a synthetic `root` container so the diff and
/// normalize pipeline can treat the tree uniformly. Mirrors the
/// Elixir runtime's internal wrapping at `plushie-elixir/lib/plushie/tree.ex`.
pub fn view_list_to_tree(windows: List(Node)) -> Node {
  case windows {
    [] -> node.empty_container()
    [single] -> single
    _ ->
      node.new("root", "container")
      |> node.with_children(windows)
  }
}

/// Normalize a top-level app view and enforce explicit windows.
///
/// Accepts the previous render cycle's memo cache and returns the
/// normalized tree, new memo cache, accumulated widget registry,
/// and detected window IDs. The registry and windows are collected
/// during normalization itself, eliminating separate tree walks.
///
/// The runtime wraps the list-of-windows returned by `view` into a
/// single tree root before calling this function, so the root here is
/// either a `window` node, a synthetic `container` holding only
/// `window` children, or an empty `container` representing `[]`.
pub fn normalize_view(
  node: Node,
  registry: widget.Registry,
  prev_memo_cache: MemoCache,
) -> Result(NormalizeResult, String) {
  let result = normalize_with_memo(node, registry, prev_memo_cache)

  case result.tree.kind {
    "window" -> Ok(result)
    "container" ->
      case
        list.all(result.tree.children, fn(child) { child.kind == "window" })
      {
        True -> Ok(result)
        False ->
          Error("view must return a list of window nodes at the top level")
      }
    _ -> Error("view must return a list of window nodes at the top level")
  }
}

/// Normalize with a widget registry and memo cache. Returns the
/// normalized tree, new memo cache, accumulated widget registry,
/// and detected window IDs.
pub fn normalize_with_memo(
  node: Node,
  registry: widget.Registry,
  prev_memo_cache: MemoCache,
) -> NormalizeResult {
  let ctx = new_ctx(registry, prev_memo_cache)
  let #(normalized, ctx) = normalize_ctx(assign_auto_id(node, 0), ctx)
  NormalizeResult(
    tree: post_normalize(normalized),
    memo_cache: ctx.new_cache,
    registry: ctx.accumulated_registry,
    windows: ctx.accumulated_windows,
  )
}

/// Normalize with a widget registry. Widget placeholders
/// in the tree are rendered using stored state from the registry.
pub fn normalize_with_registry(node: Node, registry: widget.Registry) -> Node {
  let ctx = new_ctx(registry, dict.new())
  let #(normalized, _ctx) = normalize_ctx(assign_auto_id(node, 0), ctx)
  post_normalize(normalized)
}

fn normalize_ctx(node: Node, ctx: NormalizeCtx) -> #(Node, NormalizeCtx) {
  case ctx.depth >= 256 {
    True -> panic as "tree exceeds maximum depth of 256 levels"
    False ->
      case ctx.depth == 200 {
        True ->
          platform.log_warning(
            "plushie: tree depth reached 200 levels, maximum is 256",
          )
        False -> Nil
      }
  }

  let ctx = case node.kind {
    "window" -> NormalizeCtx(..ctx, window_id: node.id)
    _ -> ctx
  }

  // Validate user-provided IDs. Auto-IDs (assigned by `assign_auto_id`
  // for nodes the host left with an empty id) are exempt. Empty IDs
  // never reach here because entry points and `normalize_children`
  // stamp an `auto:<kind>:<index>` id first.
  case string.starts_with(node.id, "auto:") {
    True -> Nil
    False -> validate_user_id(node.id)
  }

  let scoped_id = apply_scope(node.id, ctx.scope)

  // Accumulate window IDs as we encounter them
  let ctx = case node.kind {
    "window" ->
      NormalizeCtx(
        ..ctx,
        accumulated_windows: set.insert(ctx.accumulated_windows, scoped_id),
      )
    _ -> ctx
  }

  // Memo nodes: check cache before normalizing children. The __memo__
  // wrapper is transparent; we return the normalized child directly.
  case node.kind {
    "__memo__" -> {
      case dict.get(node.meta, "__memo_dep__") {
        Ok(OpaqueVal(dep)) ->
          case dict.get(ctx.prev_cache, scoped_id) {
            Ok(MemoCacheEntry(
              dep: prev_dep,
              node: cached_node,
              registry: cached_registry,
              windows: cached_windows,
            ))
              if prev_dep == dep
            -> {
              // Cache hit: reuse the previously normalized subtree
              // and restore its accumulated registry/windows.
              let new_cache =
                dict.insert(
                  ctx.new_cache,
                  scoped_id,
                  MemoCacheEntry(
                    dep:,
                    node: cached_node,
                    registry: cached_registry,
                    windows: cached_windows,
                  ),
                )
              let accumulated_registry =
                dict.merge(ctx.accumulated_registry, cached_registry)
              let accumulated_windows =
                set.union(ctx.accumulated_windows, cached_windows)
              #(
                cached_node,
                NormalizeCtx(
                  ..ctx,
                  new_cache:,
                  accumulated_registry:,
                  accumulated_windows:,
                ),
              )
            }
            _ -> normalize_memo_child(node, scoped_id, ctx, dep)
          }
        _ ->
          // No dependency stored; always normalize fresh (no caching)
          normalize_memo_fresh(node, ctx)
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
          // Opt-in widget view cache: when the WidgetDef declares
          // `cache_key`, reuse the previously rendered subtree if the
          // dependency value is unchanged.
          let cache_key =
            widget.placeholder_cache_key(
              node,
              ctx.window_id,
              scoped_id,
              ctx.registry,
            )
          case cache_key {
            Some(dep) ->
              case dict.get(ctx.prev_cache, scoped_id) {
                Ok(MemoCacheEntry(
                  dep: prev_dep,
                  node: cached_node,
                  registry: cached_registry,
                  windows: cached_windows,
                ))
                  if prev_dep == dep
                -> {
                  emit_widget_cache_telemetry("hit", scoped_id)
                  let new_cache =
                    dict.insert(
                      ctx.new_cache,
                      scoped_id,
                      MemoCacheEntry(
                        dep:,
                        node: cached_node,
                        registry: cached_registry,
                        windows: cached_windows,
                      ),
                    )
                  let accumulated_registry =
                    dict.merge(ctx.accumulated_registry, cached_registry)
                  let accumulated_windows =
                    set.union(ctx.accumulated_windows, cached_windows)
                  #(
                    cached_node,
                    NormalizeCtx(
                      ..ctx,
                      new_cache:,
                      accumulated_registry:,
                      accumulated_windows:,
                    ),
                  )
                }
                _ -> {
                  emit_widget_cache_telemetry("miss", scoped_id)
                  normalize_placeholder(node, scoped_id, ctx, Some(dep))
                }
              }
            None -> normalize_placeholder(node, scoped_id, ctx, None)
          }
        }
        False -> normalize_regular(node, scoped_id, ctx)
      }
    }
  }
}

fn normalize_regular(
  node: Node,
  scoped_id: String,
  ctx: NormalizeCtx,
) -> #(Node, NormalizeCtx) {
  // Windows set child scope to "window_id#". Auto-ID nodes (transparent)
  // pass the parent scope through; named nodes create a scope boundary.
  let child_scope = case node.kind {
    "window" -> scoped_id <> "#"
    _ ->
      case string.starts_with(node.id, "auto:") {
        True -> ctx.scope
        False -> scoped_id
      }
  }

  let props = resolve_a11y_refs(node.props, ctx.scope)

  let child_ctx = NormalizeCtx(..ctx, scope: child_scope, depth: ctx.depth + 1)
  let #(children, child_ctx) = normalize_children(node.children, child_ctx)

  // Reject duplicate sibling IDs before diffing.
  check_duplicate_sibling_ids(children)

  let children = infer_radio_a11y(children)

  #(
    Node(id: scoped_id, kind: node.kind, props:, children:, meta: dict.new()),
    NormalizeCtx(
      ..ctx,
      new_cache: child_ctx.new_cache,
      accumulated_registry: child_ctx.accumulated_registry,
      accumulated_windows: child_ctx.accumulated_windows,
    ),
  )
}

/// Fold over children, threading the memo cache through each recursive
/// normalize_ctx call so earlier siblings' cache entries are visible to
/// later siblings.
///
/// Children with an empty `id` are assigned an auto-ID of the form
/// `auto:<kind>:<index>` before recursing; the sibling index keeps
/// them unique without creating a scope boundary.
fn normalize_children(
  children: List(Node),
  ctx: NormalizeCtx,
) -> #(List(Node), NormalizeCtx) {
  let #(_idx, children_rev, ctx) =
    list.fold(children, #(0, [], ctx), fn(acc, child) {
      let #(idx, kids, ctx) = acc
      let child = assign_auto_id(child, idx)
      let #(normalized_child, ctx) = normalize_ctx(child, ctx)
      #(idx + 1, [normalized_child, ..kids], ctx)
    })
  #(list.reverse(children_rev), ctx)
}

/// Replace an empty `id` with `auto:<kind>:<index>` so the node is
/// recognised as an auto-ID (transparent to scoping, exempt from user-ID
/// validation). Named nodes pass through unchanged.
fn assign_auto_id(node: Node, index: Int) -> Node {
  case node.id {
    "" -> Node(..node, id: "auto:" <> node.kind <> ":" <> int.to_string(index))
    _ -> node
  }
}

/// Normalize a memo node's first child and cache the result.
/// The cache entry captures the registry entries and window IDs
/// accumulated while normalizing this subtree, so they can be
/// restored on cache hit without re-walking.
fn normalize_memo_child(
  node: Node,
  scoped_id: String,
  ctx: NormalizeCtx,
  dep: Dynamic,
) -> #(Node, NormalizeCtx) {
  case node.children {
    [content, ..] -> {
      // Snapshot accumulators before normalizing the child so we can
      // capture the delta for the cache entry.
      let pre_registry = ctx.accumulated_registry
      let pre_windows = ctx.accumulated_windows
      let child_ctx = NormalizeCtx(..ctx, depth: ctx.depth + 1)
      let #(normalized_child, child_ctx) = normalize_ctx(content, child_ctx)
      // Delta: entries added during this subtree's normalization
      let registry_delta =
        dict.drop(child_ctx.accumulated_registry, dict.keys(pre_registry))
      let windows_delta =
        set.difference(child_ctx.accumulated_windows, pre_windows)
      let new_cache =
        dict.insert(
          child_ctx.new_cache,
          scoped_id,
          MemoCacheEntry(
            dep:,
            node: normalized_child,
            registry: registry_delta,
            windows: windows_delta,
          ),
        )
      #(
        normalized_child,
        NormalizeCtx(
          ..ctx,
          new_cache:,
          accumulated_registry: child_ctx.accumulated_registry,
          accumulated_windows: child_ctx.accumulated_windows,
        ),
      )
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
      let new_cache =
        dict.insert(
          ctx.new_cache,
          scoped_id,
          MemoCacheEntry(
            dep:,
            node: empty,
            registry: widget.empty_registry(),
            windows: set.new(),
          ),
        )
      #(empty, NormalizeCtx(..ctx, new_cache:))
    }
  }
}

/// Normalize a memo node's first child without caching (no dependency
/// was provided, so we can't determine staleness).
fn normalize_memo_fresh(node: Node, ctx: NormalizeCtx) -> #(Node, NormalizeCtx) {
  case node.children {
    [content, ..] -> {
      let child_ctx = NormalizeCtx(..ctx, depth: ctx.depth + 1)
      let #(normalized, child_ctx) = normalize_ctx(content, child_ctx)
      #(
        normalized,
        NormalizeCtx(
          ..ctx,
          new_cache: child_ctx.new_cache,
          accumulated_registry: child_ctx.accumulated_registry,
          accumulated_windows: child_ctx.accumulated_windows,
        ),
      )
    }
    [] -> #(
      Node(
        id: "auto:container:0",
        kind: "container",
        props: dict.new(),
        children: [],
        meta: dict.new(),
      ),
      ctx,
    )
  }
}

/// Render a widget placeholder and normalize its children. When
/// `cache_key` is `Some(dep)`, the rendered subtree's registry/windows
/// deltas are captured and stored in `new_cache` keyed by the
/// placeholder's scoped ID, so the next render with the same dep
/// hash can short-circuit via the cache-hit path above.
fn normalize_placeholder(
  node: Node,
  scoped_id: String,
  ctx: NormalizeCtx,
  cache_key: Option(Dynamic),
) -> #(Node, NormalizeCtx) {
  case
    widget.render_placeholder(
      node,
      ctx.window_id,
      scoped_id,
      node.id,
      ctx.registry,
    )
  {
    Some(#(rendered_node, entry)) -> {
      // Snapshot accumulators before this subtree so we can capture
      // the delta for the view cache.
      let pre_registry = ctx.accumulated_registry
      let pre_windows = ctx.accumulated_windows

      // Accumulate the widget registry entry
      let widget_reg_key = widget.widget_key(ctx.window_id, scoped_id)
      let ctx =
        NormalizeCtx(
          ..ctx,
          accumulated_registry: dict.insert(
            ctx.accumulated_registry,
            widget_reg_key,
            entry,
          ),
        )

      // The rendered node already has the scoped_id set and metadata
      // attached. Normalize its children at the same scope position
      // and resolve a11y references in its props.
      let child_scope = case rendered_node.kind {
        "window" -> scoped_id <> "#"
        _ ->
          case string.starts_with(rendered_node.id, "auto:") {
            True -> ctx.scope
            False -> scoped_id
          }
      }
      // Forward standard widget props (a11y, event_rate) from the
      // placeholder to the rendered output so widget authors don't
      // need to handle them manually.
      let props = widget.merge_standard_props(rendered_node.props, node.props)
      let props = resolve_a11y_refs(props, ctx.scope)
      let child_ctx =
        NormalizeCtx(..ctx, scope: child_scope, depth: ctx.depth + 1)
      let #(children, child_ctx) =
        normalize_children(rendered_node.children, child_ctx)
      check_duplicate_sibling_ids(children)
      let final_node = Node(..rendered_node, props:, children:)

      // Capture deltas and write to cache if the widget opted in.
      let new_cache = case cache_key {
        Some(dep) -> {
          let registry_delta =
            dict.drop(child_ctx.accumulated_registry, dict.keys(pre_registry))
          let windows_delta =
            set.difference(child_ctx.accumulated_windows, pre_windows)
          dict.insert(
            child_ctx.new_cache,
            scoped_id,
            MemoCacheEntry(
              dep:,
              node: final_node,
              registry: registry_delta,
              windows: windows_delta,
            ),
          )
        }
        None -> child_ctx.new_cache
      }

      #(
        final_node,
        NormalizeCtx(
          ..ctx,
          new_cache:,
          accumulated_registry: child_ctx.accumulated_registry,
          accumulated_windows: child_ctx.accumulated_windows,
        ),
      )
    }
    _ -> {
      // Fallback: normalize as a regular node
      normalize_regular(node, scoped_id, ctx)
    }
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

/// Validate a user-provided widget ID. Called for non-auto-generated
/// IDs during normalization. Panics on invalid IDs (programming error).
///
/// Rules (canonical, shared across all host SDKs):
/// - Must not be empty
/// - Must not contain `/` (reserved for scope separators)
/// - Must not contain `#` (reserved for window-qualified paths)
/// - Must not exceed 1024 bytes
fn validate_user_id(id: String) -> Nil {
  case id {
    "" -> panic as "widget ID must not be empty"
    _ -> Nil
  }
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
}

fn apply_scope(id: String, scope: String) -> String {
  case scope, id {
    "", _ -> id
    _, "" -> id
    _, _ ->
      // Auto-IDs are transparent: they stay as-is regardless of scope
      // so they neither create a scope boundary nor get prefixed.
      case string.starts_with(id, "auto:") {
        True -> id
        False ->
          case string.ends_with(scope, "#") {
            // Window boundary: scope is "window#", join without "/"
            True -> scope <> id
            // Normal scope: join with "/"
            False -> scope <> "/" <> id
          }
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

// --- Post-normalize pass -----------------------------------------------------
//
// Runs after the first pass produces a fully scoped tree. Mirrors the
// Rust SDK:
//
//   - Auto-populate a11y.role from the widget type when unset.
//   - Rewrite cross-widget a11y refs on active_descendant and every
//     element of radio_group through the same scope-prefix logic
//     already applied to labelled_by, described_by, error_message.
//   - Populate implicit a11y.radio_group when radios share a `group`
//     prop in the same enclosing scope.
//   - Emit a11y_ref_unresolved warnings for refs that don't match any
//     declared widget ID.
//   - Emit missing_accessible_name warnings for interactive widgets
//     that carry no label, text child, a11y.label, or a11y.labelled_by.

fn post_normalize(tree: Node) -> Node {
  let declared = collect_ids(tree, set.new())
  let radio_groups = collect_radio_groups(tree, "", dict.new())
  let rewritten = rewrite_a11y(tree, "", declared, radio_groups)
  check_missing_accessible_name(rewritten)
  rewritten
}

fn collect_ids(node: Node, acc: set.Set(String)) -> set.Set(String) {
  let acc = case node.id {
    "" -> acc
    id ->
      case string.starts_with(id, "auto:") {
        True -> acc
        False -> set.insert(acc, id)
      }
  }
  list.fold(node.children, acc, fn(inner, child) { collect_ids(child, inner) })
}

fn collect_radio_groups(
  node: Node,
  scope: String,
  acc: Dict(String, List(String)),
) -> Dict(String, List(String)) {
  let acc = case node.kind, fetch_group_prop(node.props) {
    "radio", Some(group) -> {
      let key = scope <> "\t" <> group
      case dict.get(acc, key) {
        Ok(ids) -> dict.insert(acc, key, list.append(ids, [node.id]))
        Error(_) -> dict.insert(acc, key, [node.id])
      }
    }
    _, _ -> acc
  }
  let child_scope = child_scope_of(node, scope)
  list.fold(node.children, acc, fn(inner, child) {
    collect_radio_groups(child, child_scope, inner)
  })
}

fn child_scope_of(node: Node, scope: String) -> String {
  case node.kind, node.id {
    "window", id -> id <> "#"
    _, "" -> scope
    _, id ->
      case string.starts_with(id, "auto:") {
        True -> scope
        False -> id
      }
  }
}

fn fetch_group_prop(props: Dict(String, PropValue)) -> Option(String) {
  case dict.get(props, "group") {
    Ok(StringVal(group)) if group != "" -> Some(group)
    _ -> None
  }
}

fn rewrite_a11y(
  node: Node,
  scope: String,
  declared: set.Set(String),
  radio_groups: Dict(String, List(String)),
) -> Node {
  rewrite_a11y_with_parent(node, scope, declared, radio_groups, None)
}

fn rewrite_a11y_with_parent(
  node: Node,
  scope: String,
  declared: set.Set(String),
  radio_groups: Dict(String, List(String)),
  tooltip_parent_id: Option(String),
) -> Node {
  let child_scope = child_scope_of(node, scope)
  let tooltip_for_children = case node.kind {
    "tooltip" -> Some(node.id)
    _ -> None
  }
  let children =
    list.map(node.children, fn(child) {
      rewrite_a11y_with_parent(
        child,
        child_scope,
        declared,
        radio_groups,
        tooltip_for_children,
      )
    })

  let props =
    apply_a11y_rewrites(
      node.props,
      node.kind,
      node.id,
      scope,
      declared,
      radio_groups,
      tooltip_parent_id,
    )

  Node(..node, props:, children:)
}

fn placeholder_description(
  kind: String,
  props: Dict(String, PropValue),
) -> Option(String) {
  case kind {
    "text_input" | "text_editor" | "combo_box" | "pick_list" ->
      case dict.get(props, "placeholder") {
        Ok(StringVal(s)) if s != "" -> Some(s)
        _ -> None
      }
    _ -> None
  }
}

fn required_from_props(
  kind: String,
  props: Dict(String, PropValue),
) -> Option(Bool) {
  case kind {
    "text_input" | "text_editor" | "checkbox" | "pick_list" | "combo_box" ->
      case dict.get(props, "required") {
        Ok(BoolVal(b)) -> Some(b)
        _ -> None
      }
    _ -> None
  }
}

/// Project a :validation prop onto (invalid, error_message).
///
/// Accepts author-facing forms plus their wire-encoded equivalents
/// (atoms encode to strings, tuples to lists):
///
///   "valid"                            -> (Some(False), None)
///   "pending"                          -> (None, None)
///   ["invalid", message]               -> (Some(True), Some(message))
///   {state: "invalid", message: m}     -> (Some(True), Some(m))
fn invalid_from_props(
  kind: String,
  props: Dict(String, PropValue),
) -> #(Option(Bool), Option(String)) {
  case kind {
    "text_input" | "text_editor" | "checkbox" | "pick_list" | "combo_box" ->
      case dict.get(props, "validation") {
        Ok(StringVal("valid")) -> #(Some(False), None)
        Ok(StringVal("pending")) -> #(None, None)
        Ok(ListVal([StringVal("invalid"), StringVal(msg)])) -> #(
          Some(True),
          Some(msg),
        )
        Ok(DictVal(m)) -> invalid_from_validation_dict(m)
        _ -> #(None, None)
      }
    _ -> #(None, None)
  }
}

fn invalid_from_validation_dict(
  m: Dict(String, PropValue),
) -> #(Option(Bool), Option(String)) {
  case dict.get(m, "state") {
    Ok(StringVal("valid")) -> #(Some(False), None)
    Ok(StringVal("pending")) -> #(None, None)
    Ok(StringVal("invalid")) -> {
      let msg = case dict.get(m, "message") {
        Ok(StringVal(s)) -> Some(s)
        _ -> None
      }
      #(Some(True), msg)
    }
    _ -> #(None, None)
  }
}

fn apply_a11y_rewrites(
  props: Dict(String, PropValue),
  kind: String,
  owner_id: String,
  scope: String,
  declared: set.Set(String),
  radio_groups: Dict(String, List(String)),
  tooltip_parent_id: Option(String),
) -> Dict(String, PropValue) {
  let role_default = widget_type_to_role(kind)

  let radio_ids = case kind, fetch_group_prop(props) {
    "radio", Some(group) -> {
      let key = scope <> "\t" <> group
      case dict.get(radio_groups, key) {
        Ok(ids) -> Some(ids)
        Error(_) -> None
      }
    }
    _, _ -> None
  }

  let placeholder_desc = placeholder_description(kind, props)
  let required_prop = required_from_props(kind, props)
  let #(invalid_prop, error_text) = invalid_from_props(kind, props)

  let a11y_in = case dict.get(props, "a11y") {
    Ok(DictVal(m)) -> Some(m)
    _ -> None
  }

  let needs_update =
    a11y_in != None
    || role_default != None
    || radio_ids != None
    || placeholder_desc != None
    || required_prop != None
    || invalid_prop != None
    || error_text != None
    || tooltip_parent_id != None

  case needs_update {
    False -> props
    True -> {
      let a11y = case a11y_in {
        Some(m) -> m
        None -> dict.new()
      }

      // Auto-populate role if unset.
      let a11y = case role_default, dict.has_key(a11y, "role") {
        Some(role), False -> dict.insert(a11y, "role", StringVal(role))
        _, _ -> a11y
      }

      let a11y =
        rewrite_single_ref(a11y, "labelled_by", owner_id, scope, declared)
      let a11y =
        rewrite_single_ref(a11y, "described_by", owner_id, scope, declared)
      let a11y =
        rewrite_single_ref(a11y, "error_message", owner_id, scope, declared)
      let a11y =
        rewrite_single_ref(a11y, "active_descendant", owner_id, scope, declared)

      let a11y = rewrite_radio_group_list(a11y, owner_id, scope, declared)

      let a11y = case radio_ids, dict.has_key(a11y, "radio_group") {
        Some(ids), False -> {
          let list_vals = list.map(ids, StringVal)
          dict.insert(a11y, "radio_group", ListVal(list_vals))
        }
        _, _ -> a11y
      }

      let a11y = case placeholder_desc, dict.has_key(a11y, "description") {
        Some(desc), False -> dict.insert(a11y, "description", StringVal(desc))
        _, _ -> a11y
      }

      let a11y = case required_prop, dict.has_key(a11y, "required") {
        Some(True), False -> dict.insert(a11y, "required", BoolVal(True))
        _, _ -> a11y
      }

      let a11y = case invalid_prop, dict.has_key(a11y, "invalid") {
        Some(b), False -> dict.insert(a11y, "invalid", BoolVal(b))
        _, _ -> a11y
      }

      let a11y = case error_text, dict.has_key(a11y, "error_message") {
        Some(msg), False -> dict.insert(a11y, "error_message", StringVal(msg))
        _, _ -> a11y
      }

      let a11y = case tooltip_parent_id, dict.has_key(a11y, "described_by") {
        Some(parent_id), False ->
          dict.insert(a11y, "described_by", StringVal(parent_id))
        _, _ -> a11y
      }

      dict.insert(props, "a11y", DictVal(a11y))
    }
  }
}

fn rewrite_single_ref(
  a11y: Dict(String, PropValue),
  key: String,
  owner_id: String,
  scope: String,
  declared: set.Set(String),
) -> Dict(String, PropValue) {
  case dict.get(a11y, key) {
    Ok(StringVal(ref_id)) if ref_id != "" -> {
      let rewritten = scope_ref_string(ref_id, scope)
      case set.contains(declared, rewritten) {
        True -> Nil
        False ->
          platform.log_warning(
            "plushie a11y: a11y."
            <> key
            <> " \""
            <> ref_id
            <> "\" on \""
            <> owner_id
            <> "\" does not match any declared widget ID",
          )
      }
      dict.insert(a11y, key, StringVal(rewritten))
    }
    _ -> a11y
  }
}

fn rewrite_radio_group_list(
  a11y: Dict(String, PropValue),
  owner_id: String,
  scope: String,
  declared: set.Set(String),
) -> Dict(String, PropValue) {
  case dict.get(a11y, "radio_group") {
    Ok(ListVal(refs)) -> {
      let rewritten =
        list.map(refs, fn(item) {
          case item {
            StringVal(ref_id) if ref_id != "" -> {
              let r = scope_ref_string(ref_id, scope)
              case set.contains(declared, r) {
                True -> Nil
                False ->
                  platform.log_warning(
                    "plushie a11y: a11y.radio_group member \""
                    <> ref_id
                    <> "\" on \""
                    <> owner_id
                    <> "\" does not match any declared widget ID",
                  )
              }
              StringVal(r)
            }
            other -> other
          }
        })
      dict.insert(a11y, "radio_group", ListVal(rewritten))
    }
    _ -> a11y
  }
}

fn scope_ref_string(ref: String, scope: String) -> String {
  case scope, ref {
    "", _ -> ref
    _, "" -> ref
    _, _ ->
      case string.contains(ref, "/") || string.contains(ref, "#") {
        True -> ref
        False ->
          case string.ends_with(scope, "#") {
            True -> scope <> ref
            False -> scope <> "/" <> ref
          }
      }
  }
}

fn widget_type_to_role(kind: String) -> Option(String) {
  case kind {
    "button" -> Some("button")
    "checkbox" -> Some("check_box")
    "toggler" -> Some("switch")
    "radio" -> Some("radio_button")
    "text_input" -> Some("text_input")
    "text_editor" -> Some("multiline_text_input")
    "text" -> Some("label")
    "rich_text" -> Some("label")
    "slider" -> Some("slider")
    "vertical_slider" -> Some("slider")
    "pick_list" -> Some("combo_box")
    "combo_box" -> Some("combo_box")
    "progress_bar" -> Some("progress_indicator")
    "image" -> Some("image")
    "svg" -> Some("image")
    "qr_code" -> Some("image")
    "scrollable" -> Some("scroll_view")
    "container" -> Some("generic_container")
    "column" -> Some("generic_container")
    "row" -> Some("generic_container")
    "stack" -> Some("generic_container")
    "grid" -> Some("generic_container")
    "pane_grid" -> Some("generic_container")
    "table" -> Some("table")
    "canvas" -> Some("canvas")
    "rule" -> Some("separator")
    _ -> None
  }
}

fn check_missing_accessible_name(node: Node) -> Nil {
  case requires_accessible_name(node.kind), has_accessible_name(node) {
    True, False ->
      platform.log_warning(
        "plushie a11y: missing_accessible_name: "
        <> node.kind
        <> " \""
        <> node.id
        <> "\" has no label, text child, a11y.label, or a11y.labelled_by; "
        <> "screen readers will announce no name",
      )
    _, _ -> Nil
  }
  list.each(node.children, check_missing_accessible_name)
}

fn requires_accessible_name(kind: String) -> Bool {
  case kind {
    "button" | "toggler" | "checkbox" | "pointer_area" -> True
    _ -> False
  }
}

fn has_accessible_name(node: Node) -> Bool {
  case dict.get(node.props, "label") {
    Ok(StringVal(s)) if s != "" -> True
    _ ->
      case dict.get(node.props, "a11y") {
        Ok(DictVal(a11y)) ->
          a11y_has_name(a11y) || has_text_child(node.children)
        _ -> has_text_child(node.children)
      }
  }
}

fn a11y_has_name(a11y: Dict(String, PropValue)) -> Bool {
  case dict.get(a11y, "label") {
    Ok(StringVal(s)) if s != "" -> True
    _ ->
      case dict.get(a11y, "labelled_by") {
        Ok(StringVal(s)) if s != "" -> True
        _ -> False
      }
  }
}

fn has_text_child(children: List(Node)) -> Bool {
  list.any(children, fn(child) {
    case child.kind, dict.get(child.props, "content") {
      "text", Ok(StringVal(s)) if s != "" -> True
      _, _ -> has_text_child(child.children)
    }
  })
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
        False -> {
          let prop_ops = diff_props(old.props, new.props, path)
          let child_ops = diff_children(old.children, new.children, path)
          list.append(prop_ops, child_ops)
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

/// Diff children using three strategies:
///
/// - **Fast**: ID sequences match -> pairwise prop diff, O(n)
/// - **Medium**: no reorder among common IDs -> insert/remove only
/// - **Slow**: reorder detected -> LIS for minimal moves, O(n log n)
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
    True -> diff_children_same_order(old_children, new_children, parent_path)
    False -> {
      let old_set = set.from_list(old_ids)
      let new_set = set.from_list(new_ids)
      let common_old =
        list.filter(old_ids, fn(id) { set.contains(new_set, id) })
      let common_new =
        list.filter(new_ids, fn(id) { set.contains(old_set, id) })

      case common_old == common_new {
        // Medium path: common IDs in same relative order
        True -> {
          let old_by_id = build_indexed_lookup(old_children)
          let old_only = set.difference(old_set, new_set)
          diff_children_no_reorder(
            old_by_id,
            new_children,
            old_only,
            parent_path,
          )
        }
        // Slow path: reorder detected, use LIS
        False -> {
          let old_by_id = build_indexed_lookup(old_children)
          let old_only = set.difference(old_set, new_set)
          diff_children_reorder(
            old_by_id,
            new_children,
            common_new,
            old_only,
            parent_path,
          )
        }
      }
    }
  }
}

fn build_indexed_lookup(children: List(Node)) -> Dict(String, #(Node, Int)) {
  list.index_fold(children, dict.new(), fn(acc, child, idx) {
    dict.insert(acc, child.id, #(child, idx))
  })
}

/// Fast path: old and new have identical ID lists. Diff props per child.
fn diff_children_same_order(
  old_children: List(Node),
  new_children: List(Node),
  parent_path: List(Int),
) -> List(PatchOp) {
  list.zip(old_children, new_children)
  |> list.index_map(fn(pair, idx) {
    let #(old_child, new_child) = pair
    diff_node(old_child, new_child, list.append(parent_path, [idx]))
  })
  |> list.flatten()
}

/// Medium path: common IDs maintain relative order. Pure inserts and
/// removes with no moves needed.
fn diff_children_no_reorder(
  old_by_id: Dict(String, #(Node, Int)),
  new_children: List(Node),
  old_only: Set(String),
  parent_path: List(Int),
) -> List(PatchOp) {
  let removed_indices =
    old_by_id
    |> dict.fold([], fn(acc, id, entry) {
      let #(_, idx) = entry
      case set.contains(old_only, id) {
        True -> list.append(acc, [idx])
        False -> acc
      }
    })
    |> list.sort(int.compare)

  let remove_ops =
    list.reverse(removed_indices)
    |> list.map(fn(idx) { RemoveChild(path: parent_path, index: idx) })

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

/// Slow path: reordering detected. Use LIS to find the largest subset
/// of common elements that maintain relative order. Elements in the LIS
/// stay in place; elements not in the LIS are removed and re-inserted
/// at their new positions.
fn diff_children_reorder(
  old_by_id: Dict(String, #(Node, Int)),
  new_children: List(Node),
  common_new: List(String),
  old_only: Set(String),
  parent_path: List(Int),
) -> List(PatchOp) {
  // For common IDs in new order, get their old indices
  let old_indices_of_common =
    list.map(common_new, fn(id) {
      case dict.get(old_by_id, id) {
        Ok(#(_, idx)) -> idx
        Error(_) -> 0
      }
    })

  // Find LIS positions (indices into common_new that form the LIS)
  let lis_positions = longest_increasing_subsequence(old_indices_of_common)
  let lis_set = set.from_list(lis_positions)

  // IDs that stay in place (in the LIS)
  let lis_ids =
    common_new
    |> list.index_map(fn(id, i) { #(id, i) })
    |> list.filter(fn(entry) {
      let #(_, i) = entry
      set.contains(lis_set, i)
    })
    |> list.map(fn(entry) {
      let #(id, _) = entry
      id
    })
    |> set.from_list()

  // IDs that need to move: common but not in LIS
  let moved_ids = set.difference(set.from_list(common_new), lis_ids)

  // All indices to remove: old-only IDs + moved IDs
  let all_remove_ids = set.union(old_only, moved_ids)

  let removed_indices =
    all_remove_ids
    |> set.fold([], fn(acc, id) {
      case dict.get(old_by_id, id) {
        Ok(#(_, idx)) -> list.append(acc, [idx])
        Error(_) -> acc
      }
    })
    |> list.sort(int.compare)

  let remove_ops =
    list.reverse(removed_indices)
    |> list.map(fn(idx) { RemoveChild(path: parent_path, index: idx) })

  // Build new child lookup for O(1) access
  let new_child_by_id =
    list.fold(new_children, dict.new(), fn(acc, c) { dict.insert(acc, c.id, c) })

  // Update ops for LIS elements (they survive removals, need adjusted indices)
  let update_ops =
    set.fold(lis_ids, [], fn(acc, id) {
      case dict.get(old_by_id, id), dict.get(new_child_by_id, id) {
        Ok(#(old_child, old_idx)), Ok(new_child) -> {
          let child_path =
            list.append(parent_path, [
              index_after_removals(old_idx, removed_indices),
            ])
          list.append(acc, diff_node(old_child, new_child, child_path))
        }
        _, _ -> acc
      }
    })

  // Insert ops: new-only IDs and moved IDs, at their new positions
  let insert_ops =
    new_children
    |> list.index_map(fn(child, idx) { #(child, idx) })
    |> list.filter(fn(entry) {
      let #(child, _) = entry
      !dict.has_key(old_by_id, child.id) || set.contains(moved_ids, child.id)
    })
    |> list.map(fn(entry) {
      let #(child, idx) = entry
      InsertChild(path: parent_path, index: idx, node: child)
    })

  list.flatten([remove_ops, update_ops, insert_ops])
}

/// Compute the adjusted index of an old child after removals, using
/// binary search on a sorted list of removed indices. O(log r) per call.
fn index_after_removals(old_idx: Int, sorted_removed: List(Int)) -> Int {
  let count_below = bsearch_count_lt(sorted_removed, old_idx, 0)
  old_idx - count_below
}

/// Count elements in a sorted list that are strictly less than the
/// target value, using binary search. O(log n).
fn bsearch_count_lt(sorted: List(Int), target: Int, count: Int) -> Int {
  case sorted {
    [] -> count
    [head, ..rest] ->
      case head < target {
        True -> bsearch_count_lt(rest, target, count + 1)
        False -> count
      }
  }
}

/// Longest Increasing Subsequence using patience sorting.
/// Returns the indices (positions) in the input list that form the LIS.
/// O(n log n) time, O(n) space.
fn longest_increasing_subsequence(values: List(Int)) -> List(Int) {
  case values {
    [] -> []
    _ -> {
      let #(_, preds, lis_end, lis_len) =
        list.index_fold(values, #([], dict.new(), 0, 0), fn(acc, val, pos) {
          let #(tails, preds, current_lis_end, len) = acc
          let insert_pos = lis_bsearch(values, tails, val, 0, len)

          let preds = case insert_pos > 0 {
            True -> {
              let pred_idx = list_at(tails, insert_pos - 1)
              case pred_idx {
                Some(pi) -> dict.insert(preds, pos, pi)
                None -> preds
              }
            }
            False -> preds
          }

          let tails = list_set(tails, insert_pos, pos)
          let new_len = int.max(len, insert_pos + 1)
          let lis_end = case new_len > len {
            True -> pos
            False -> current_lis_end
          }

          #(tails, preds, lis_end, new_len)
        })

      reconstruct_lis(preds, lis_end, lis_len, [])
    }
  }
}

/// Binary search for the insertion point of val in tails.
/// tails[i] holds the index in the input whose value is the
/// smallest tail of an increasing subsequence of length i+1.
/// We dereference values[tails[mid]] to compare actual values.
fn lis_bsearch(
  values: List(Int),
  tails: List(Int),
  val: Int,
  lo: Int,
  hi: Int,
) -> Int {
  case lo >= hi {
    True -> lo
    False -> {
      let mid = lo + { hi - lo } / 2
      case list_at(tails, mid) {
        Some(tail_pos) -> {
          case list_at(values, tail_pos) {
            Some(tail_val) ->
              case tail_val < val {
                True -> lis_bsearch(values, tails, val, mid + 1, hi)
                False -> lis_bsearch(values, tails, val, lo, mid)
              }
            None -> lo
          }
        }
        None -> lo
      }
    }
  }
}

/// Get element at index from a list, O(n). For the LIS algorithm
/// on typical UI trees (under ~100 children), this is fast enough.
/// For very large lists, an array data structure would be better.
fn list_at(list: List(a), index: Int) -> Option(a) {
  case list {
    [] -> option.None
    [head, ..rest] ->
      case index == 0 {
        True -> option.Some(head)
        False -> list_at(rest, index - 1)
      }
  }
}

/// Set element at index in a list, returning a new list. O(n).
fn list_set(list: List(a), index: Int, value: a) -> List(a) {
  case list {
    [] -> [value]
    [head, ..rest] ->
      case index == 0 {
        True -> [value, ..rest]
        False -> [head, ..list_set(rest, index - 1, value)]
      }
  }
}

/// Reconstruct the LIS by following predecessors backward from the
/// last element.
fn reconstruct_lis(
  preds: Dict(Int, Int),
  idx: Int,
  remaining: Int,
  acc: List(Int),
) -> List(Int) {
  case remaining == 0 {
    True -> acc
    False ->
      case dict.get(preds, idx) {
        Ok(prev_idx) ->
          reconstruct_lis(preds, prev_idx, remaining - 1, [idx, ..acc])
        Error(_) -> [idx, ..acc]
      }
  }
}

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

/// Extract the local portion of a scoped ID. Takes the last segment
/// after "/" and, if that segment contains "#", the part after "#".
fn extract_local_id(id: String) -> String {
  let last_segment = case string.split(id, "/") {
    [] -> id
    segments ->
      case list.last(segments) {
        Ok(last) -> last
        Error(_) -> id
      }
  }
  case string.split_once(last_segment, "#") {
    Ok(#(_, after)) -> after
    Error(_) -> last_segment
  }
}

fn find_by_local(tree: Node, target: String) -> Option(Node) {
  let local = extract_local_id(tree.id)
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

// -- Telemetry helpers --------------------------------------------------------

/// Emit a `["plushie", "widget_cache", outcome]` telemetry event so
/// observers can count cache hits and misses without re-deriving them
/// from spans. Measurements carry a count of 1; metadata carries the
/// widget's scoped id for per-widget breakdowns.
fn emit_widget_cache_telemetry(outcome: String, scoped_id: String) -> Nil {
  telemetry.execute(
    ["plushie", "widget_cache", outcome],
    dict.from_list([#("count", dynamic.int(1))]),
    dict.from_list([#("id", dynamic.string(scoped_id))]),
  )
}
