import gleam/dict
import gleam/dynamic
import gleam/option.{None, Some}
import gleam/set
import plushie/node.{type Node, BoolVal, FloatVal, StringVal}
import plushie/protocol
import plushie/runtime
import plushie/runtime_core

pub fn default_opts_format_test() {
  let opts = runtime.default_opts()
  assert opts.format == protocol.Msgpack
}

pub fn default_opts_session_test() {
  let opts = runtime.default_opts()
  assert opts.session == ""
}

pub fn default_opts_daemon_test() {
  let opts = runtime.default_opts()
  assert opts.daemon == False
}

pub fn custom_opts_test() {
  let opts =
    runtime.RuntimeOpts(
      format: protocol.Json,
      session: "test-session",
      daemon: True,
      app_opts: dynamic.nil(),
      required_extensions: [],
      renderer_args: ["--headless"],
      token: option.None,
    )
  assert opts.format == protocol.Json
  assert opts.session == "test-session"
  assert opts.daemon == True
}

// -- Window detection --------------------------------------------------------

fn window_node(id: String) -> Node {
  node.new(id, "window")
}

fn window_node_with_props(id: String, title: String) -> Node {
  node.new(id, "window")
  |> node.with_prop("title", StringVal(title))
}

pub fn detect_windows_root_is_window_test() {
  let tree = window_node("main")
  let windows = runtime_core.detect_windows(tree)
  assert set.contains(windows, "main")
  assert set.size(windows) == 1
}

pub fn detect_windows_children_are_windows_test() {
  let tree =
    node.new("root", "container")
    |> node.with_children([
      window_node("win-a"),
      window_node("win-b"),
      node.new("not-a-window", "column"),
    ])
  let windows = runtime_core.detect_windows(tree)
  assert set.size(windows) == 2
  assert set.contains(windows, "win-a")
  assert set.contains(windows, "win-b")
}

pub fn detect_windows_no_windows_test() {
  let tree =
    node.new("root", "column")
    |> node.with_children([
      node.new("txt", "text"),
      node.new("btn", "button"),
    ])
  let windows = runtime_core.detect_windows(tree)
  assert set.is_empty(windows)
}

pub fn detect_windows_ignores_deeply_nested_test() {
  // Windows nested inside non-root containers should not be detected
  let tree =
    node.new("root", "container")
    |> node.with_children([
      node.new("wrapper", "column")
      |> node.with_children([window_node("deep-win")]),
    ])
  let windows = runtime_core.detect_windows(tree)
  assert set.is_empty(windows)
}

// -- Window prop extraction --------------------------------------------------

pub fn extract_window_props_returns_tracked_keys_test() {
  let tree =
    node.new("main", "window")
    |> node.with_props([
      #("title", StringVal("My App")),
      #("width", FloatVal(800.0)),
      #("height", FloatVal(600.0)),
      #("resizable", BoolVal(True)),
      #("untracked_prop", StringVal("ignored")),
    ])
  let props = runtime_core.extract_window_props(tree, "main")
  assert dict.size(props) == 4
  assert dict.get(props, "title") == Ok(StringVal("My App"))
  assert dict.get(props, "width") == Ok(FloatVal(800.0))
  assert dict.get(props, "resizable") == Ok(BoolVal(True))
  // untracked_prop should not appear
  assert dict.get(props, "untracked_prop") == Error(Nil)
}

pub fn extract_window_props_includes_size_and_position_test() {
  // D-047: size, position, min_size, max_size should be tracked
  let size_val =
    node.DictVal(
      dict.from_list([
        #("width", FloatVal(800.0)),
        #("height", FloatVal(600.0)),
      ]),
    )
  let pos_val =
    node.DictVal(
      dict.from_list([#("x", FloatVal(100.0)), #("y", FloatVal(200.0))]),
    )
  let tree =
    node.new("main", "window")
    |> node.with_props([
      #("size", size_val),
      #("position", pos_val),
      #("min_size", size_val),
      #("max_size", size_val),
    ])
  let props = runtime_core.extract_window_props(tree, "main")
  assert dict.size(props) == 4
  assert dict.has_key(props, "size")
  assert dict.has_key(props, "position")
  assert dict.has_key(props, "min_size")
  assert dict.has_key(props, "max_size")
}

pub fn extract_window_props_child_window_test() {
  let tree =
    node.new("root", "container")
    |> node.with_children([
      node.new("settings", "window")
      |> node.with_prop("title", StringVal("Settings")),
    ])
  let props = runtime_core.extract_window_props(tree, "settings")
  assert dict.get(props, "title") == Ok(StringVal("Settings"))
}

pub fn extract_window_props_missing_window_test() {
  let tree = node.new("root", "container")
  let props = runtime_core.extract_window_props(tree, "nonexistent")
  assert dict.is_empty(props)
}

// -- Window node finding -----------------------------------------------------

pub fn find_window_node_root_test() {
  let tree = window_node_with_props("main", "Root Window")
  assert runtime_core.find_window_node(tree, "main") == Some(tree)
}

pub fn find_window_node_child_test() {
  let win = window_node_with_props("child", "Child Window")
  let tree =
    node.new("root", "container")
    |> node.with_children([win])
  assert runtime_core.find_window_node(tree, "child") == Some(win)
}

pub fn find_window_node_not_found_test() {
  let tree =
    node.new("root", "container")
    |> node.with_children([node.new("btn", "button")])
  assert runtime_core.find_window_node(tree, "missing") == None
}

pub fn find_window_node_wrong_id_test() {
  let tree = window_node("win-a")
  assert runtime_core.find_window_node(tree, "win-b") == None
}
