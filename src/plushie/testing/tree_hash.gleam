//// Structural tree hash for regression testing.
////
//// Computes a SHA-256 hash of the serialized UI tree and compares
//// against golden files. Works on all backends.
////
//// On first run, creates a `.sha256` file. On subsequent runs, compares
//// the current hash against the stored one. Set PLUSHIE_UPDATE_SNAPSHOTS=1
//// to force-update golden files.

import gleam/json
import gleam/string
import plushie/node.{type Node}
import plushie/platform
import plushie/testing/snapshot

/// A tree hash result.
pub type TreeHash {
  TreeHash(name: String, hash: String)
}

/// Compute a SHA-256 hash of the given tree's canonical JSON form.
pub fn hash(tree: Node) -> String {
  let json_str = snapshot.node_to_json(tree) |> json.to_string()
  let json_bits = <<json_str:utf8>>
  platform.sha256_hex(json_bits)
}

/// Assert that a tree hash matches its golden file.
///
/// If no golden file exists, creates one (first run). If
/// PLUSHIE_UPDATE_SNAPSHOTS=1 is set, updates the golden file.
/// Otherwise compares hashes and panics on mismatch.
pub fn assert_tree_hash(tree: Node, name: String, path: String) -> Nil {
  let current_hash = hash(tree)
  let golden_path = path <> "/" <> name <> ".sha256"

  let update_mode = platform.get_env("PLUSHIE_UPDATE_SNAPSHOTS") == Ok("1")

  case file_exists(golden_path), update_mode {
    True, False -> {
      let assert Ok(stored) = read_file(golden_path)
      let expected = string.trim(stored)
      case expected == current_hash {
        True -> Nil
        False ->
          panic as {
            "Tree hash mismatch for \""
            <> name
            <> "\".\n\nExpected: "
            <> expected
            <> "\nActual:   "
            <> current_hash
            <> "\n\nRun with PLUSHIE_UPDATE_SNAPSHOTS=1 to update.\nGolden file: "
            <> golden_path
          }
      }
    }
    _, _ -> {
      mkdir_p(dir_name(golden_path))
      write_file_atomic(golden_path, current_hash)
      Nil
    }
  }
}

// -- File system helpers (reuse snapshot FFI) ---------------------------------

@external(erlang, "plushie_snapshot_ffi", "file_exists")
fn file_exists(path: String) -> Bool

@external(erlang, "plushie_snapshot_ffi", "read_file")
fn read_file(path: String) -> Result(String, Nil)

@external(erlang, "plushie_snapshot_ffi", "write_file_atomic")
fn write_file_atomic(path: String, content: String) -> Nil

@external(erlang, "plushie_snapshot_ffi", "mkdir_p")
fn mkdir_p(path: String) -> Nil

@external(erlang, "plushie_snapshot_ffi", "dir_name")
fn dir_name(path: String) -> String
