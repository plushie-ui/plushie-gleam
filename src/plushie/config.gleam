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
//// ```
////
//// ## Resolution order (highest priority first)
////
//// 1. CLI flag (`--bin-file`, `--wasm-dir`)
//// 2. `[plushie]` section in gleam.toml
//// 3. Environment variable (`PLUSHIE_SOURCE_PATH`)
//// 4. Hardcoded default

import gleam/list

/// Read a string value from the [plushie] section of gleam.toml.
pub fn get_string(key: String) -> Result(String, Nil) {
  read_config_string(key)
}

/// Read the artifacts list from gleam.toml.
/// Returns the list of artifact names (e.g. ["bin", "wasm"]).
pub fn get_artifacts() -> Result(List(String), Nil) {
  read_config_list("artifacts")
}

/// Check if a specific artifact is configured.
pub fn wants_artifact(name: String) -> Result(Bool, Nil) {
  case get_artifacts() {
    Ok(artifacts) -> Ok(list.contains(artifacts, name))
    Error(_) -> Error(Nil)
  }
}

// -- FFI ---------------------------------------------------------------------

@external(erlang, "plushie_config_ffi", "read_config")
fn read_config_string(key: String) -> Result(String, Nil)

@external(erlang, "plushie_config_ffi", "read_config")
fn read_config_list(key: String) -> Result(List(String), Nil)
