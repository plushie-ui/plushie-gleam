import gleam/dict
import gleam/list
import gleam/option
import gleeunit/should
import plushie/node.{DictVal, NullVal, StringVal}
import plushie/patch.{InsertChild, RemoveChild, ReplaceNode, UpdateProps}
import plushie/platform
import plushie/tree

// --- normalize ---------------------------------------------------------------

pub fn normalize_simple_node_no_scope_test() {
  let n = node.new("btn", "button")
  let result = tree.normalize(n)
  should.equal(result.id, "btn")
}

pub fn normalize_child_gets_scoped_id_test() {
  let child = node.new("email", "text_input")
  let parent =
    node.new("form", "container")
    |> node.with_children([child])

  let result = tree.normalize(parent)
  let assert [scoped_child] = result.children
  should.equal(scoped_child.id, "form/email")
}

pub fn normalize_nested_scoping_test() {
  let leaf = node.new("c", "text")
  let mid =
    node.new("b", "container")
    |> node.with_children([leaf])
  let root =
    node.new("a", "container")
    |> node.with_children([mid])

  let result = tree.normalize(root)
  let assert [mid_result] = result.children
  let assert [leaf_result] = mid_result.children
  should.equal(result.id, "a")
  should.equal(mid_result.id, "a/b")
  should.equal(leaf_result.id, "a/b/c")
}

pub fn normalize_window_does_not_propagate_scope_test() {
  let child = node.new("t", "text")
  let win =
    node.new("main", "window")
    |> node.with_children([child])

  let result = tree.normalize(win)
  let assert [scoped_child] = result.children
  // Window resets scope, so "t" stays "t", not "main/t".
  should.equal(scoped_child.id, "t")
}

pub fn normalize_empty_id_does_not_create_scope_boundary_test() {
  let leaf = node.new("leaf", "text")
  let anon =
    node.new("", "container")
    |> node.with_children([leaf])
  let root =
    node.new("root", "container")
    |> node.with_children([anon])

  let result = tree.normalize(root)
  let assert [anon_result] = result.children
  let assert [leaf_result] = anon_result.children
  should.equal(anon_result.id, "")
  should.equal(leaf_result.id, "root/leaf")
}

pub fn normalize_a11y_labelled_by_gets_scope_prefix_test() {
  let a11y_props = dict.from_list([#("labelled_by", StringVal("lbl"))])
  let child =
    node.new("input", "text_input")
    |> node.with_prop("a11y", DictVal(a11y_props))
  let parent =
    node.new("form", "container")
    |> node.with_children([child])

  let result = tree.normalize(parent)
  let assert [scoped_child] = result.children

  let assert Ok(DictVal(resolved_a11y)) = dict.get(scoped_child.props, "a11y")
  should.equal(
    dict.get(resolved_a11y, "labelled_by"),
    Ok(StringVal("form/lbl")),
  )
}

pub fn normalize_a11y_already_scoped_ref_unchanged_test() {
  let a11y_props = dict.from_list([#("labelled_by", StringVal("other/lbl"))])
  let child =
    node.new("input", "text_input")
    |> node.with_prop("a11y", DictVal(a11y_props))
  let parent =
    node.new("form", "container")
    |> node.with_children([child])

  let result = tree.normalize(parent)
  let assert [scoped_child] = result.children

  let assert Ok(DictVal(resolved_a11y)) = dict.get(scoped_child.props, "a11y")
  should.equal(
    dict.get(resolved_a11y, "labelled_by"),
    Ok(StringVal("other/lbl")),
  )
}

pub fn normalize_a11y_empty_scope_leaves_ref_alone_test() {
  let a11y_props = dict.from_list([#("described_by", StringVal("help"))])
  let n =
    node.new("input", "text_input")
    |> node.with_prop("a11y", DictVal(a11y_props))

  let result = tree.normalize(n)
  let assert Ok(DictVal(resolved_a11y)) = dict.get(result.props, "a11y")
  should.equal(dict.get(resolved_a11y, "described_by"), Ok(StringVal("help")))
}

pub fn normalize_warns_on_slash_in_user_id_test() {
  // A node with "/" in its user-provided ID should still normalize
  // (we warn, not crash), but the ID ends up in the tree as-is.
  let n = node.new("bad/id", "button")
  let result = tree.normalize(n)
  // Normalization continues despite the warning
  should.equal(result.id, "bad/id")
}

pub fn normalize_no_warning_on_empty_id_test() {
  // Empty IDs are auto-generated equivalents -- no slash warning.
  let n = node.new("", "container")
  let result = tree.normalize(n)
  should.equal(result.id, "")
}

pub fn normalize_warns_on_duplicate_sibling_ids_test() {
  // Two children with the same ID should fail loudly instead of drifting into diffing.
  let a = node.new("dup", "text")
  let b = node.new("dup", "text")
  let root =
    node.new("root", "container")
    |> node.with_children([a, b])

  platform.try_call(fn() { tree.normalize(root) })
  |> should.be_error
}

pub fn normalize_no_warning_on_unique_sibling_ids_test() {
  let a = node.new("a", "text")
  let b = node.new("b", "text")
  let root =
    node.new("root", "container")
    |> node.with_children([a, b])

  let result = tree.normalize(root)
  should.equal(result.children |> list.map(fn(c) { c.id }), ["root/a", "root/b"])
}

// --- diff --------------------------------------------------------------------

pub fn diff_same_tree_produces_no_ops_test() {
  let n =
    node.new("btn", "button")
    |> node.with_prop("label", StringVal("Click"))
  should.equal(tree.diff(n, n), [])
}

pub fn diff_changed_prop_produces_update_props_test() {
  let old =
    node.new("t", "text")
    |> node.with_prop("content", StringVal("old"))
  let new =
    node.new("t", "text")
    |> node.with_prop("content", StringVal("new"))

  let ops = tree.diff(old, new)
  should.equal(ops, [
    UpdateProps(
      path: [],
      props: dict.from_list([#("content", StringVal("new"))]),
    ),
  ])
}

pub fn diff_added_prop_produces_update_props_test() {
  let old = node.new("t", "text")
  let new =
    node.new("t", "text")
    |> node.with_prop("bold", node.BoolVal(True))

  let ops = tree.diff(old, new)
  should.equal(ops, [
    UpdateProps(
      path: [],
      props: dict.from_list([#("bold", node.BoolVal(True))]),
    ),
  ])
}

pub fn diff_removed_prop_produces_null_val_test() {
  let old =
    node.new("t", "text")
    |> node.with_prop("bold", node.BoolVal(True))
  let new = node.new("t", "text")

  let ops = tree.diff(old, new)
  should.equal(ops, [
    UpdateProps(path: [], props: dict.from_list([#("bold", NullVal)])),
  ])
}

pub fn diff_added_child_produces_insert_child_test() {
  let old = node.new("col", "column")
  let child = node.new("btn", "button")
  let new =
    node.new("col", "column")
    |> node.with_children([child])

  let ops = tree.diff(old, new)
  should.equal(ops, [InsertChild(path: [], index: 0, node: child)])
}

pub fn diff_removed_child_produces_remove_child_test() {
  let child = node.new("btn", "button")
  let old =
    node.new("col", "column")
    |> node.with_children([child])
  let new = node.new("col", "column")

  let ops = tree.diff(old, new)
  should.equal(ops, [RemoveChild(path: [], index: 0)])
}

pub fn diff_changed_child_prop_produces_nested_update_test() {
  let old_child =
    node.new("t", "text")
    |> node.with_prop("content", StringVal("old"))
  let new_child =
    node.new("t", "text")
    |> node.with_prop("content", StringVal("new"))
  let old =
    node.new("col", "column")
    |> node.with_children([old_child])
  let new =
    node.new("col", "column")
    |> node.with_children([new_child])

  let ops = tree.diff(old, new)
  should.equal(ops, [
    UpdateProps(
      path: [0],
      props: dict.from_list([#("content", StringVal("new"))]),
    ),
  ])
}

pub fn diff_different_root_id_produces_replace_node_test() {
  let old = node.new("a", "container")
  let new = node.new("b", "container")

  let ops = tree.diff(old, new)
  should.equal(ops, [ReplaceNode(path: [], node: new)])
}

pub fn diff_different_root_kind_produces_replace_node_test() {
  let old = node.new("x", "column")
  let new = node.new("x", "row")

  let ops = tree.diff(old, new)
  should.equal(ops, [ReplaceNode(path: [], node: new)])
}

pub fn diff_reordered_children_produces_replace_node_test() {
  let a = node.new("a", "text")
  let b = node.new("b", "text")
  let old =
    node.new("col", "column")
    |> node.with_children([a, b])
  let new =
    node.new("col", "column")
    |> node.with_children([b, a])

  let ops = tree.diff(old, new)
  should.equal(ops, [ReplaceNode(path: [], node: new)])
}

pub fn diff_multiple_changes_test() {
  // old: col > [text("a", content="hello"), button("b")]
  // new: col > [text("a", content="world"), text("c")]
  // Expected: remove "b" at index 1, update "a" content, insert "c" at index 1
  let old_a =
    node.new("a", "text")
    |> node.with_prop("content", StringVal("hello"))
  let old_b = node.new("b", "button")
  let old =
    node.new("col", "column")
    |> node.with_children([old_a, old_b])

  let new_a =
    node.new("a", "text")
    |> node.with_prop("content", StringVal("world"))
  let new_c = node.new("c", "text")
  let new =
    node.new("col", "column")
    |> node.with_children([new_a, new_c])

  let ops = tree.diff(old, new)
  // Removals first (descending), then updates, then insertions.
  should.equal(ops, [
    RemoveChild(path: [], index: 1),
    UpdateProps(
      path: [0],
      props: dict.from_list([#("content", StringVal("world"))]),
    ),
    InsertChild(path: [], index: 1, node: new_c),
  ])
}

pub fn diff_unchanged_props_no_ops_test() {
  let n =
    node.new("t", "text")
    |> node.with_prop("content", StringVal("same"))
    |> node.with_prop("size", node.FloatVal(14.0))

  should.equal(tree.diff(n, n), [])
}

pub fn diff_deeply_nested_path_test() {
  // root > mid > leaf (change leaf's prop)
  let old_leaf =
    node.new("leaf", "text")
    |> node.with_prop("v", StringVal("old"))
  let new_leaf =
    node.new("leaf", "text")
    |> node.with_prop("v", StringVal("new"))
  let old =
    node.new("root", "container")
    |> node.with_children([
      node.new("mid", "container")
      |> node.with_children([old_leaf]),
    ])
  let new =
    node.new("root", "container")
    |> node.with_children([
      node.new("mid", "container")
      |> node.with_children([new_leaf]),
    ])

  let ops = tree.diff(old, new)
  should.equal(ops, [
    UpdateProps(path: [0, 0], props: dict.from_list([#("v", StringVal("new"))])),
  ])
}

// --- search ------------------------------------------------------------------

pub fn find_root_by_id_test() {
  let root = node.new("root", "container")
  should.equal(tree.find(root, "root"), option.Some(root))
}

pub fn find_nested_child_by_id_test() {
  let leaf = node.new("leaf", "text")
  let mid =
    node.new("mid", "container")
    |> node.with_children([leaf])
  let root =
    node.new("root", "container")
    |> node.with_children([mid])

  should.equal(tree.find(root, "leaf"), option.Some(leaf))
}

pub fn find_returns_none_for_missing_id_test() {
  let root = node.new("root", "container")
  should.equal(tree.find(root, "nope"), option.None)
}

pub fn find_by_local_segment_fallback_test() {
  // When the target has no "/" and no exact match, fall back to matching
  // the local segment (part after last "/") of each node's ID.
  let leaf = node.new("form/email", "text_input")
  let root =
    node.new("root", "container")
    |> node.with_children([leaf])

  should.equal(tree.find(root, "email"), option.Some(leaf))
}

pub fn find_local_segment_no_fallback_when_target_has_slash_test() {
  // If the target itself contains "/", no local-segment fallback.
  let leaf = node.new("form/email", "text_input")
  let root =
    node.new("root", "container")
    |> node.with_children([leaf])

  should.equal(tree.find(root, "x/email"), option.None)
}

pub fn find_exact_match_preferred_over_local_segment_test() {
  // Exact match should win over local-segment match.
  let exact = node.new("email", "text_input")
  let scoped = node.new("form/email", "text_input")
  let root =
    node.new("root", "container")
    |> node.with_children([scoped, exact])

  should.equal(tree.find(root, "email"), option.Some(exact))
}

pub fn find_local_segment_deep_test() {
  // Local-segment fallback works at any depth.
  let deep = node.new("a/b/target", "text")
  let mid =
    node.new("mid", "container")
    |> node.with_children([deep])
  let root =
    node.new("root", "container")
    |> node.with_children([mid])

  should.equal(tree.find(root, "target"), option.Some(deep))
}

pub fn exists_returns_true_test() {
  let child = node.new("btn", "button")
  let root =
    node.new("root", "container")
    |> node.with_children([child])

  should.be_true(tree.exists(root, "btn"))
}

pub fn exists_returns_false_test() {
  let root = node.new("root", "container")
  should.be_false(tree.exists(root, "ghost"))
}

pub fn find_all_with_predicate_test() {
  let a = node.new("a", "button")
  let b = node.new("b", "text")
  let c = node.new("c", "button")
  let root =
    node.new("root", "container")
    |> node.with_children([a, b, c])

  let buttons = tree.find_all(root, fn(n) { n.kind == "button" })
  should.equal(buttons, [a, c])
}

pub fn find_all_no_matches_test() {
  let root = node.new("root", "container")
  let result = tree.find_all(root, fn(n) { n.kind == "slider" })
  should.equal(result, [])
}

pub fn ids_returns_all_ids_depth_first_test() {
  let leaf1 = node.new("l1", "text")
  let leaf2 = node.new("l2", "text")
  let mid =
    node.new("mid", "container")
    |> node.with_children([leaf1])
  let root =
    node.new("root", "container")
    |> node.with_children([mid, leaf2])

  should.equal(tree.ids(root), ["root", "mid", "l1", "l2"])
}
