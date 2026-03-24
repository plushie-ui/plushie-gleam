//// Tree snapshot testing.
////
//// Captures a JSON representation of the UI tree structure and compares
//// against golden files. On first run, creates the golden file. On
//// subsequent runs, compares and fails on mismatch.
////
//// Set PLUSHIE_UPDATE_SNAPSHOTS=1 to force-update golden files.

import gleam/dict
import gleam/json
import gleam/list
import gleam/string
import plushie/node.{type Node, type PropValue}
import plushie/platform

/// Assert that a tree matches its golden snapshot file.
///
/// If no golden file exists, creates one (first run). If
/// PLUSHIE_UPDATE_SNAPSHOTS=1 is set, updates the golden file.
/// Otherwise compares JSON and panics on mismatch.
pub fn assert_tree_snapshot(tree: Node, name: String, path: String) -> Nil {
  let json_str = node_to_json(tree) |> json.to_string()
  let golden_path = path <> "/" <> name <> ".json"

  let update_mode = platform.get_env("PLUSHIE_UPDATE_SNAPSHOTS") == Ok("1")

  case file_exists(golden_path), update_mode {
    True, False -> {
      let assert Ok(stored) = read_file(golden_path)
      let stored_trimmed = string.trim(stored)
      let current_trimmed = string.trim(json_str)
      case stored_trimmed == current_trimmed {
        True -> Nil
        False ->
          panic as {
            "Snapshot mismatch for \""
            <> name
            <> "\".\n\nStored:\n"
            <> string.slice(stored_trimmed, 0, 500)
            <> "\n\nCurrent:\n"
            <> string.slice(current_trimmed, 0, 500)
            <> "\n\nRun with PLUSHIE_UPDATE_SNAPSHOTS=1 to update.\nGolden file: "
            <> golden_path
          }
      }
    }
    _, _ -> {
      mkdir_p(dir_name(golden_path))
      write_file_atomic(golden_path, json_str)
      Nil
    }
  }
}

/// Serialize a Node to deterministic JSON (sorted keys).
pub fn node_to_json(tree: Node) -> json.Json {
  let props_entries =
    tree.props
    |> dict.to_list()
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
    |> list.map(fn(entry) { #(entry.0, prop_value_to_json(entry.1)) })

  let children_json = list.map(tree.children, node_to_json)

  json.object([
    #("children", json.array(children_json, fn(j) { j })),
    #("id", json.string(tree.id)),
    #("kind", json.string(tree.kind)),
    #("props", json.object(props_entries)),
  ])
}

fn prop_value_to_json(pv: PropValue) -> json.Json {
  case pv {
    node.StringVal(s) -> json.string(s)
    node.IntVal(i) -> json.int(i)
    node.FloatVal(f) -> json.float(f)
    node.BoolVal(b) -> json.bool(b)
    node.NullVal -> json.null()
    node.BinaryVal(_) -> json.string("<binary>")
    node.ListVal(items) -> json.array(items, prop_value_to_json)
    node.DictVal(d) -> {
      let entries =
        d
        |> dict.to_list()
        |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
        |> list.map(fn(entry) { #(entry.0, prop_value_to_json(entry.1)) })
      json.object(entries)
    }
  }
}

// -- File system helpers (Erlang FFI) ----------------------------------------

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
