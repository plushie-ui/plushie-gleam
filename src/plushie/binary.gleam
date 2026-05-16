//// Resolve the path to the plushie Rust binary.
////
//// Resolution order:
//// 1. PLUSHIE_BINARY_PATH env var (error if set but file missing)
//// 2. bin/plushie-renderer (downloaded or built binary)
//// 3. Custom build at _build/{env}/plushie-renderer/target/release/plushie-renderer
//// 4. Common local paths (./plushie-renderer, ../plushie-renderer/target/release/plushie-renderer)
////
//// Returns Result(String, BinaryError) with the path on success.

import gleam/list
import gleam/string
import plushie/platform

/// Error when the plushie binary cannot be found.
pub type BinaryError {
  /// Binary not found at any searched path.
  NotFound(searched: List(String))
  /// PLUSHIE_BINARY_PATH is set but the file doesn't exist.
  EnvVarPointsToMissing(path: String)
}

/// Find the plushie binary, searching in priority order.
pub fn find() -> Result(String, BinaryError) {
  case platform.get_env("PLUSHIE_BINARY_PATH") {
    Ok(path) -> {
      case platform.file_exists(path) {
        True -> Ok(path)
        False -> Error(EnvVarPointsToMissing(path:))
      }
    }
    Error(_) -> find_in_standard_paths()
  }
}

fn find_in_standard_paths() -> Result(String, BinaryError) {
  let paths = candidate_paths()
  case list.find(paths, platform.file_exists) {
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

/// Standard instructions for resolving a missing plushie-renderer binary.
///
/// Used by the test infrastructure and error messages to provide
/// consistent guidance.
pub fn not_found_message() -> String {
  "plushie-renderer binary not found.

To download a precompiled binary:
  gleam run -m plushie/download

To build from source:
  gleam run -m plushie/build

To use an existing binary:
  export PLUSHIE_BINARY_PATH=/path/to/plushie-renderer"
}

/// Returns the directory where downloaded binaries are stored.
/// Shared across environments (the binary is platform-specific,
/// not env-specific).
pub fn download_dir() -> String {
  "bin"
}

/// Returns the stable project-local renderer filename.
pub fn download_name() -> String {
  case platform.platform_string() {
    "windows" -> "plushie-renderer.exe"
    _ -> "plushie-renderer"
  }
}

/// Returns the stable project-local reusable launcher filename.
pub fn launcher_name() -> String {
  case platform.platform_string() {
    "windows" -> "plushie-launcher.exe"
    _ -> "plushie-launcher"
  }
}

/// Returns the stable project-local standalone plushie tool filename.
pub fn tool_name() -> String {
  case platform.platform_string() {
    "windows" -> "plushie.exe"
    _ -> "plushie"
  }
}

/// Returns the binary name for a custom build with native widgets.
///
/// When native widgets are configured, the binary is named
/// "{project}-renderer" (derived from gleam.toml project name).
/// Otherwise returns "plushie-renderer".
pub fn build_name(project_name: Result(String, a)) -> String {
  case project_name {
    Ok(name) -> {
      // Replace underscores with hyphens for the binary name
      let hyphenated = string.replace(name, "_", "-")
      hyphenated <> "-renderer"
    }
    Error(_) -> "plushie-renderer"
  }
}

fn candidate_paths() -> List(String) {
  let name = download_name()
  [
    // Primary: downloaded or built binary in project-root bin/
    download_dir() <> "/" <> name,
    "./" <> name,
    "../plushie-renderer/target/release/" <> name,
    "../plushie-renderer/target/debug/" <> name,
  ]
}
