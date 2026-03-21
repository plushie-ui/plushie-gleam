//// Resolve the path to the plushie Rust binary.
////
//// Resolution order:
//// 1. PLUSHIE_BINARY_PATH env var (error if set but file missing)
//// 2. Precompiled at priv/bin/{platform}-{arch}/plushie
//// 3. Custom build at _build/{env}/plushie/target/release/plushie
//// 4. Common local paths (./plushie, ../plushie/target/release/plushie)
////
//// Returns Result(String, BinaryError) with the path on success.

import gleam/list
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

fn candidate_paths() -> List(String) {
  let platform = ffi.platform_string()
  let arch = ffi.arch_string()
  let name = "plushie"
  [
    "priv/bin/" <> platform <> "-" <> arch <> "/" <> name,
    "_build/dev/plushie/target/release/" <> name,
    "_build/prod/plushie/target/release/" <> name,
    "./" <> name,
    "../plushie/target/release/" <> name,
  ]
}
