import gleam/dict
import gleam/json
import gleam/string
import gleeunit/should
import plushie/node
import plushie/testing/snapshot

// -- node_to_json tests -------------------------------------------------------

pub fn node_to_json_simple_node_test() {
  let tree = node.new("btn", "button")
  let json_str = snapshot.node_to_json(tree) |> json.to_string()
  // Should contain the basic fields
  should.be_true(string.contains(json_str, "\"id\":\"btn\""))
  should.be_true(string.contains(json_str, "\"kind\":\"button\""))
  should.be_true(string.contains(json_str, "\"children\":[]"))
}

pub fn node_to_json_with_props_test() {
  let tree =
    node.new("txt", "text")
    |> node.with_prop("content", node.StringVal("hello"))
    |> node.with_prop("bold", node.BoolVal(True))
  let json_str = snapshot.node_to_json(tree) |> json.to_string()
  should.be_true(string.contains(json_str, "\"content\":\"hello\""))
  should.be_true(string.contains(json_str, "\"bold\":true"))
}

pub fn node_to_json_sorted_keys_test() {
  // Props should be alphabetically sorted for determinism
  let tree =
    node.new("x", "container")
    |> node.with_prop("zebra", node.StringVal("z"))
    |> node.with_prop("alpha", node.StringVal("a"))
  let json_str = snapshot.node_to_json(tree) |> json.to_string()
  // "alpha" should appear before "zebra" in the output
  let assert Ok(alpha_idx) = find_index(json_str, "alpha")
  let assert Ok(zebra_idx) = find_index(json_str, "zebra")
  should.be_true(alpha_idx < zebra_idx)
}

pub fn node_to_json_with_children_test() {
  let child1 = node.new("c1", "text")
  let child2 = node.new("c2", "button")
  let tree =
    node.Node(id: "root", kind: "column", props: dict.new(), children: [
      child1,
      child2,
    ])
  let json_str = snapshot.node_to_json(tree) |> json.to_string()
  should.be_true(string.contains(json_str, "\"id\":\"c1\""))
  should.be_true(string.contains(json_str, "\"id\":\"c2\""))
}

pub fn assert_tree_snapshot_creates_golden_file_test() {
  let tree = node.new("test-snap", "button")
  let dir = "test/tmp_snapshots"
  // First run creates the file
  snapshot.assert_tree_snapshot(tree, "snap_create_test", dir)
  // Second run should match
  snapshot.assert_tree_snapshot(tree, "snap_create_test", dir)
  // Cleanup
  cleanup_dir(dir)
}

// -- Helpers ------------------------------------------------------------------

fn find_index(haystack: String, needle: String) -> Result(Int, Nil) {
  case string.split_once(haystack, needle) {
    Ok(#(before, _)) -> Ok(string.length(before))
    Error(_) -> Error(Nil)
  }
}

@external(erlang, "plushie_test_cleanup_ffi", "cleanup_dir")
fn cleanup_dir(path: String) -> Nil
