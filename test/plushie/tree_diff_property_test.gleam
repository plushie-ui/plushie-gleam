import gleam/dict
import gleam/int
import gleam/list
import gleeunit/should
import plushie/node.{
  type Node, type PropValue, BoolVal, FloatVal, IntVal, Node, NullVal, StringVal,
}
import plushie/patch.{InsertChild, RemoveChild, ReplaceNode, UpdateProps}
import plushie/tree
import qcheck

// -- Generators ---------------------------------------------------------------

/// Generate a PropValue (no nested structures, keeps shrinking tractable).
fn prop_value_gen() -> qcheck.Generator(PropValue) {
  qcheck.from_generators(qcheck.map(qcheck.bounded_int(0, 100), IntVal), [
    qcheck.map(
      qcheck.string_from(qcheck.alphanumeric_ascii_codepoint()),
      StringVal,
    ),
    qcheck.map(qcheck.bounded_float(0.0, 100.0), FloatVal),
    qcheck.map(qcheck.bool(), BoolVal),
  ])
}

/// Generate a small dict of string -> PropValue (0 to 3 entries).
fn props_gen() -> qcheck.Generator(dict.Dict(String, PropValue)) {
  let key_gen =
    qcheck.from_generators(qcheck.return("width"), [
      qcheck.return("height"),
      qcheck.return("label"),
      qcheck.return("color"),
      qcheck.return("visible"),
    ])
  qcheck.generic_dict(
    keys_from: key_gen,
    values_from: prop_value_gen(),
    size_from: qcheck.bounded_int(0, 3),
  )
}

/// Generate a node kind from a fixed set.
fn kind_gen() -> qcheck.Generator(String) {
  qcheck.from_generators(qcheck.return("container"), [
    qcheck.return("text"),
    qcheck.return("button"),
    qcheck.return("row"),
    qcheck.return("column"),
  ])
}

/// Generate a node tree. `depth` controls remaining depth (0 = leaf).
/// `counter` is threaded through to produce unique IDs.
fn node_gen(depth: Int, counter: Int) -> qcheck.Generator(#(Node, Int)) {
  let id = "n" <> int.to_string(counter)
  let next_counter = counter + 1

  case depth <= 0 {
    True -> {
      use kind <- qcheck.bind(kind_gen())
      use props <- qcheck.map(props_gen())
      let n = Node(id:, kind:, props:, children: [], meta: dict.new())
      #(n, next_counter)
    }
    False -> {
      use kind <- qcheck.bind(kind_gen())
      use props <- qcheck.bind(props_gen())
      use num_children <- qcheck.bind(qcheck.bounded_int(0, 2))
      use #(children, final_counter) <- qcheck.map(children_gen(
        num_children,
        depth - 1,
        next_counter,
      ))
      let n = Node(id:, kind:, props:, children:, meta: dict.new())
      #(n, final_counter)
    }
  }
}

/// Generate a list of `count` child nodes, threading the counter through
/// to keep IDs unique.
fn children_gen(
  count: Int,
  depth: Int,
  counter: Int,
) -> qcheck.Generator(#(List(Node), Int)) {
  case count <= 0 {
    True -> qcheck.return(#([], counter))
    False -> {
      use #(child, next_counter) <- qcheck.bind(node_gen(depth, counter))
      use #(rest, final_counter) <- qcheck.map(children_gen(
        count - 1,
        depth,
        next_counter,
      ))
      #([child, ..rest], final_counter)
    }
  }
}

/// Top-level generator for a pair of random trees. Uses separate counter
/// ranges so the two trees can share some IDs (enabling update/move diffs)
/// but also have unique-to-each IDs (enabling insert/remove diffs).
fn tree_pair_gen() -> qcheck.Generator(#(Node, Node)) {
  use depth_a <- qcheck.bind(qcheck.bounded_int(0, 2))
  use depth_b <- qcheck.bind(qcheck.bounded_int(0, 2))
  use #(tree_a, _) <- qcheck.bind(node_gen(depth_a, 0))
  use #(tree_b, _) <- qcheck.map(node_gen(depth_b, 0))
  #(tree_a, tree_b)
}

// -- Patch application --------------------------------------------------------

/// Navigate to the node at `path` (list of child indices from root) and
/// apply `f` to it, returning the modified root.
fn update_at(root: Node, path: List(Int), f: fn(Node) -> Node) -> Node {
  case path {
    [] -> f(root)
    [idx, ..rest] -> {
      let children =
        list.index_map(root.children, fn(child, i) {
          case i == idx {
            True -> update_at(child, rest, f)
            False -> child
          }
        })
      Node(..root, children:)
    }
  }
}

/// Insert `child` at `index` among the children of the node at `path`.
fn insert_child_at(root: Node, path: List(Int), index: Int, child: Node) -> Node {
  update_at(root, path, fn(parent) {
    let #(before, after) = list_split_at(parent.children, index)
    Node(..parent, children: list.flatten([before, [child], after]))
  })
}

/// Remove the child at `index` from the node at `path`.
fn remove_child_at(root: Node, path: List(Int), index: Int) -> Node {
  update_at(root, path, fn(parent) {
    let children =
      list.index_map(parent.children, fn(child, i) { #(child, i) })
      |> list.filter(fn(pair) { pair.1 != index })
      |> list.map(fn(pair) { pair.0 })
    Node(..parent, children:)
  })
}

/// Apply UpdateProps: merge in new values, remove keys with NullVal.
fn update_props_at(
  root: Node,
  path: List(Int),
  new_props: dict.Dict(String, PropValue),
) -> Node {
  update_at(root, path, fn(target) {
    let merged =
      dict.fold(new_props, target.props, fn(acc, k, v) {
        case v {
          NullVal -> dict.delete(acc, k)
          _ -> dict.insert(acc, k, v)
        }
      })
    Node(..target, props: merged)
  })
}

/// Split a list at index `n`: returns (first n elements, rest).
fn list_split_at(xs: List(a), n: Int) -> #(List(a), List(a)) {
  do_list_split_at(xs, n, [])
}

fn do_list_split_at(xs: List(a), n: Int, acc: List(a)) -> #(List(a), List(a)) {
  case n <= 0 {
    True -> #(list.reverse(acc), xs)
    False ->
      case xs {
        [] -> #(list.reverse(acc), [])
        [x, ..rest] -> do_list_split_at(rest, n - 1, [x, ..acc])
      }
  }
}

/// Apply a list of PatchOps to a tree, in order.
fn apply_patches(root: Node, ops: List(patch.PatchOp)) -> Node {
  list.fold(ops, root, fn(current, op) {
    case op {
      ReplaceNode(path:, node:) -> {
        case path {
          [] -> node
          _ -> update_at(current, path, fn(_) { node })
        }
      }
      UpdateProps(path:, props:) -> update_props_at(current, path, props)
      InsertChild(path:, index:, node:) ->
        insert_child_at(current, path, index, node)
      RemoveChild(path:, index:) -> remove_child_at(current, path, index)
    }
  })
}

// -- Structural comparison (ignoring meta) ------------------------------------

/// Compare two trees ignoring the `meta` dict, which is runtime-only and
/// not relevant to the diff algorithm.
fn trees_equal(a: Node, b: Node) -> Bool {
  a.id == b.id
  && a.kind == b.kind
  && a.props == b.props
  && list.length(a.children) == list.length(b.children)
  && list.zip(a.children, b.children)
  |> list.all(fn(pair) { trees_equal(pair.0, pair.1) })
}

// -- Property tests -----------------------------------------------------------

pub fn diff_apply_roundtrip_test() {
  use #(old, new) <- qcheck.given(tree_pair_gen())
  let ops = tree.diff(old, new)
  let result = apply_patches(old, ops)
  should.be_true(trees_equal(result, new))
}

pub fn diff_identical_trees_produces_no_ops_test() {
  use #(tree_node, _counter) <- qcheck.given(node_gen(2, 0))
  let ops = tree.diff(tree_node, tree_node)
  should.equal(ops, [])
}

pub fn diff_same_structure_different_props_test() {
  let gen = {
    use #(base, _) <- qcheck.bind(node_gen(1, 0))
    use new_props <- qcheck.map(props_gen())
    #(base, new_props)
  }
  use #(base, new_props) <- qcheck.given(gen)
  let modified = Node(..base, props: new_props)
  let ops = tree.diff(base, modified)
  let result = apply_patches(base, ops)
  should.be_true(trees_equal(result, modified))
}

pub fn diff_leaf_replace_roundtrip_test() {
  let gen = {
    use kind_a <- qcheck.bind(kind_gen())
    use kind_b <- qcheck.map(kind_gen())
    #(kind_a, kind_b)
  }
  use #(kind_a, kind_b) <- qcheck.given(gen)
  let old =
    Node(
      id: "r",
      kind: kind_a,
      props: dict.new(),
      children: [],
      meta: dict.new(),
    )
  let new =
    Node(
      id: "r",
      kind: kind_b,
      props: dict.new(),
      children: [],
      meta: dict.new(),
    )
  let ops = tree.diff(old, new)
  let result = apply_patches(old, ops)
  should.be_true(trees_equal(result, new))
}
