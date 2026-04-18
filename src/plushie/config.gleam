//// Project-level plushie configuration from gleam.toml.
////
//// Reads the `[plushie]` section of the project's `gleam.toml` to
//// provide per-project defaults for build and download commands.
//// CLI flags always override config values.
////
//// ## Supported keys
////
//// ```toml
//// [plushie]
//// artifacts = ["bin", "wasm"]       # which artifacts to install
//// bin_file = "build/my-binary"      # binary destination
//// wasm_dir = "static/wasm"          # WASM output directory
//// source_path = "/path/to/renderer" # Rust source checkout
//// native_widgets = ["native/gauge|gauge::GaugeExtension::new()"]
//// ```
////
//// Each native_widgets entry is `"crate_path|constructor_expression"`.
//// The `|` separator is unambiguous (not valid in paths or Rust
//// identifiers in this context). The array must be on a single line
//// (the TOML parser does not support multi-line arrays).
////
//// ## Resolution order (highest priority first)
////
//// 1. CLI flag (`--bin-file`, `--wasm-dir`)
//// 2. `[plushie]` section in gleam.toml
//// 3. Environment variable (`PLUSHIE_RUST_SOURCE_PATH`)
//// 4. Hardcoded default

@target(erlang)
import gleam/list
@target(erlang)
import gleam/string

/// Configuration for a native widget crate.
pub type NativeWidgetConfig {
  NativeWidgetConfig(crate_path: String, constructor: String)
}

@target(erlang)
/// Read a string value from the [plushie] section of gleam.toml.
pub fn get_string(key: String) -> Result(String, Nil) {
  read_config_string(key)
}

@target(erlang)
/// Read the artifacts list from gleam.toml.
/// Returns the list of artifact names (e.g. ["bin", "wasm"]).
pub fn get_artifacts() -> Result(List(String), Nil) {
  read_config_list("artifacts")
}

@target(erlang)
/// Check if a specific artifact is configured.
pub fn wants_artifact(name: String) -> Result(Bool, Nil) {
  case get_artifacts() {
    Ok(artifacts) -> Ok(list.contains(artifacts, name))
    Error(_) -> Error(Nil)
  }
}

@target(erlang)
/// Read native widget entries from gleam.toml.
///
/// Each entry is a string in the format "crate_path|constructor".
/// Returns an empty list if no native_widgets key is present.
pub fn get_native_widgets() -> List(NativeWidgetConfig) {
  case read_config_list("native_widgets") {
    Ok(entries) -> list.filter_map(entries, parse_native_widget_entry)
    Error(_) -> []
  }
}

@target(erlang)
fn parse_native_widget_entry(entry: String) -> Result(NativeWidgetConfig, Nil) {
  case string.split_once(entry, "|") {
    Ok(#(crate_path, constructor)) -> {
      let trimmed_path = string.trim(crate_path)
      let trimmed_ctor = string.trim(constructor)
      case trimmed_path, trimmed_ctor {
        "", _ -> Error(Nil)
        _, "" -> Error(Nil)
        _, _ ->
          Ok(NativeWidgetConfig(
            crate_path: trimmed_path,
            constructor: trimmed_ctor,
          ))
      }
    }
    Error(_) -> Error(Nil)
  }
}

// -- FFI ---------------------------------------------------------------------

@target(erlang)
@external(erlang, "plushie_config_ffi", "read_config")
fn read_config_string(key: String) -> Result(String, Nil)

@target(erlang)
@external(erlang, "plushie_config_ffi", "read_config")
fn read_config_list(key: String) -> Result(List(String), Nil)
