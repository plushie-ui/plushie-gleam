import gleam/string
import gleeunit/should
import plushie/node
import plushie/testing/tree_hash

pub fn hash_produces_hex_string_test() {
  let tree = node.new("btn", "button")
  let h = tree_hash.hash(tree)
  // SHA-256 hex is 64 chars
  should.equal(string.length(h), 64)
}

pub fn hash_is_deterministic_test() {
  let tree = node.new("btn", "button")
  let h1 = tree_hash.hash(tree)
  let h2 = tree_hash.hash(tree)
  should.equal(h1, h2)
}

pub fn different_trees_different_hashes_test() {
  let tree1 = node.new("a", "button")
  let tree2 = node.new("b", "text")
  let h1 = tree_hash.hash(tree1)
  let h2 = tree_hash.hash(tree2)
  should.not_equal(h1, h2)
}

pub fn assert_tree_hash_creates_golden_file_test() {
  let tree = node.new("hash-test", "button")
  let dir = "test/tmp_hashes"
  // First run creates the file
  tree_hash.assert_tree_hash(tree, "hash_create_test", dir)
  // Second run should match
  tree_hash.assert_tree_hash(tree, "hash_create_test", dir)
  // Cleanup
  cleanup_dir(dir)
}

@external(erlang, "plushie_test_cleanup_ffi", "cleanup_dir")
fn cleanup_dir(path: String) -> Nil
