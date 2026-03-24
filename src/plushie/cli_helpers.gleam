//// Shared helpers for CLI entry points.
////
//// Provides binary resolution and source path lookup used by
//// gui, stdio, inspect, and other CLI modules.

import gleam/result
import plushie/binary
import plushie/platform

/// Look up the plushie source checkout path from the PLUSHIE_SOURCE_PATH
/// environment variable.
pub fn source_path() -> Result(String, Nil) {
  platform.get_env("PLUSHIE_SOURCE_PATH")
}

/// Error when the plushie binary cannot be resolved.
pub type ResolveError {
  /// Binary not found at any searched location.
  BinaryNotFound(binary.BinaryError)
  /// An explicit path was given but the file does not exist.
  ExplicitPathMissing(path: String)
}

/// Options controlling binary resolution.
pub type ResolveOpts {
  ResolveOpts(
    /// Explicit path to the binary. Overrides auto-resolution.
    binary_path: Result(String, Nil),
  )
}

/// Default resolution options (auto-resolve).
pub fn default_resolve_opts() -> ResolveOpts {
  ResolveOpts(binary_path: Error(Nil))
}

/// Resolve the plushie binary path.
///
/// If `opts.binary_path` is set, validates that the file exists.
/// Otherwise delegates to `binary.find()`.
pub fn resolve_binary(opts: ResolveOpts) -> Result(String, ResolveError) {
  case opts.binary_path {
    Ok(path) ->
      case platform.file_exists(path) {
        True -> Ok(path)
        False -> Error(ExplicitPathMissing(path:))
      }
    Error(_) ->
      binary.find()
      |> result.map_error(BinaryNotFound)
  }
}

/// Format a ResolveError as a human-readable message.
pub fn resolve_error_message(err: ResolveError) -> String {
  case err {
    BinaryNotFound(_) ->
      "plushie binary not found. Run `gleam run -m plushie/download` or "
      <> "`gleam run -m plushie/build`, or set PLUSHIE_BINARY_PATH."
    ExplicitPathMissing(path:) ->
      "plushie binary not found at explicit path: " <> path
  }
}
