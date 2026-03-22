//// Resolve the path to the plushie Rust binary.
////
//// Resolution order:
//// 1. PLUSHIE_BINARY_PATH env var (error if set but file missing)
//// 2. priv/bin/plushie (installed by bin/plushie.download or bin/plushie.build)
//// 3. Precompiled at priv/bin/{platform}-{arch}/plushie
//// 4. Custom build at _build/{env}/plushie/target/release/plushie
//// 5. Common local paths (./plushie, ../plushie/target/release/plushie)
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

fn candidate_paths() -> List(String) {
  let platform = ffi.platform_string()
  let arch = ffi.arch_string()
  let name = "plushie"
  [
    "priv/bin/" <> name,
    "priv/bin/" <> platform <> "-" <> arch <> "/" <> name,
    "_build/dev/plushie/target/release/" <> name,
    "_build/prod/plushie/target/release/" <> name,
    "./" <> name,
    "../plushie/target/release/" <> name,
    "../plushie/target/debug/" <> name,
  ]
}
