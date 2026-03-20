//// Resolve the path to the toddy Rust binary.
////
//// Resolution order:
//// 1. TODDY_BINARY_PATH env var (error if set but file missing)
//// 2. Precompiled at priv/bin/{platform}-{arch}/toddy
//// 3. Custom build at _build/{env}/toddy/target/release/toddy
//// 4. Common local paths (./toddy, ../toddy/target/release/toddy)
////
//// Returns Result(String, BinaryError) with the path on success.

import gleam/list
import toddy/ffi

/// Error when the toddy binary cannot be found.
pub type BinaryError {
  /// Binary not found at any searched path.
  NotFound(searched: List(String))
  /// TODDY_BINARY_PATH is set but the file doesn't exist.
  EnvVarPointsToMissing(path: String)
}

/// Find the toddy binary, searching in priority order.
pub fn find() -> Result(String, BinaryError) {
  case ffi.get_env("TODDY_BINARY_PATH") {
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
  let name = "toddy"
  [
    "priv/bin/" <> platform <> "-" <> arch <> "/" <> name,
    "_build/dev/toddy/target/release/" <> name,
    "_build/prod/toddy/target/release/" <> name,
    "./" <> name,
    "../toddy/target/release/" <> name,
  ]
}
