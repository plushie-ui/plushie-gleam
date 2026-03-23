//// Resolve the path to the plushie Rust binary.
////
//// Resolution order:
//// 1. PLUSHIE_BINARY_PATH env var (error if set but file missing)
//// 2. build/plushie/bin/plushie-renderer-{platform}-{arch} (downloaded binary)
//// 3. build/plushie/bin/plushie-renderer (platform-generic fallback)
//// 4. priv/bin/plushie-renderer-{platform}-{arch} (legacy location, backward compat)
//// 5. priv/bin/plushie-renderer (legacy location, backward compat)
//// 6. Custom build at _build/{env}/plushie-renderer/target/release/plushie-renderer
//// 7. Common local paths (./plushie-renderer, ../plushie-renderer/target/release/plushie-renderer)
////
//// Returns Result(String, BinaryError) with the path on success.

import gleam/list
import gleam/string
import plushie/ffi

/// Error when the plushie binary cannot be found.
pub type BinaryError {
  /// Binary not found at any searched path.
  NotFound(searched: List(String))
  /// PLUSHIE_BINARY_PATH is set but the file doesn't exist.
  EnvVarPointsToMissing(path: String)
}

/// Find the plushie binary, searching in priority order.
pub fn find() -> Result(String, BinaryError) {
  case ffi.get_env("PLUSHIE_BINARY_PATH") {
    Ok(path) -> {
      case ffi.file_exists(path) {
        True -> Ok(path)
        False -> Error(EnvVarPointsToMissing(path:))
      }
    }
    Error(_) -> find_in_standard_paths()
  }
}

fn find_in_standard_paths() -> Result(String, BinaryError) {
  let paths = candidate_paths()
  case list.find(paths, ffi.file_exists) {
    Ok(path) -> Ok(path)
    Error(_) -> Error(NotFound(searched: paths))
  }
}

/// Format a binary error as a human-readable string.
pub fn error_to_string(err: BinaryError) -> String {
  case err {
    NotFound(searched:) ->
      "not found (searched: " <> string.join(searched, ", ") <> ")"
    EnvVarPointsToMissing(path:) ->
      "PLUSHIE_BINARY_PATH points to missing file: " <> path
  }
}

/// Returns the directory where downloaded binaries are stored.
/// Shared across environments (the binary is platform-specific,
/// not env-specific).
pub fn download_dir() -> String {
  "build/plushie/bin"
}

fn candidate_paths() -> List(String) {
  let platform = ffi.platform_string()
  let arch = ffi.arch_string()
  let name = "plushie-renderer"
  let platform_name = name <> "-" <> platform <> "-" <> arch
  [
    // Primary: downloaded binary in build/plushie/bin/
    download_dir() <> "/" <> platform_name,
    download_dir() <> "/" <> name,
    // Legacy: priv/bin/ (backward compat)
    "priv/bin/" <> platform_name,
    "priv/bin/" <> name,
    // Custom builds (plushie-renderer binary from cargo)
    "_build/dev/plushie-renderer/target/release/plushie-renderer",
    "_build/prod/plushie-renderer/target/release/plushie-renderer",
    "./" <> name,
    "../plushie-renderer/target/release/" <> name,
    "../plushie-renderer/target/debug/" <> name,
  ]
}
