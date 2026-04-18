//// Resolve how to invoke `cargo-plushie`.
////
//// The SDK delegates renderer workspace generation and compilation to
//// `cargo-plushie`. This module returns the correct way to invoke it:
////
//// 1. If `PLUSHIE_RUST_SOURCE_PATH` is set, invoke via
////    `cargo run --manifest-path <source>/Cargo.toml -p cargo-plushie
////    --release --quiet --`.
//// 2. Else if `cargo-plushie` is on PATH at the matching version,
////    invoke it directly.
//// 3. Else return an error explaining how to install.
////
//// The matching version is the `plushie_rust_version` declared in the
//// SDK's `gleam.toml` (see `plushie/config.plushie_rust_version/0`),
//// which pins the plushie-rust release this SDK expects.

@target(erlang)
import gleam/result
@target(erlang)
import gleam/string
@target(erlang)
import plushie/platform

@target(erlang)
/// Concrete command + argument prefix to invoke `cargo-plushie`.
pub type CargoPlushie {
  CargoPlushie(command: String, args_prefix: List(String))
}

@target(erlang)
/// Failure modes when resolving how to call `cargo-plushie`.
pub type ResolveError {
  /// `cargo-plushie` is not on PATH and `PLUSHIE_RUST_SOURCE_PATH` is
  /// not set.
  NotAvailable(expected_version: String)
  /// `cargo-plushie` is on PATH but its `--version` does not match the
  /// version the SDK pins.
  VersionMismatch(expected_version: String, found_version: String)
  /// `cargo-plushie --version` produced output the SDK could not parse.
  UnparseableVersion(raw: String)
}

@target(erlang)
/// Resolve how to invoke `cargo-plushie` for the given pinned version.
///
/// Returns a `CargoPlushie` value carrying the executable name and any
/// leading args required before the subcommand (e.g. `build`).
pub fn resolve(expected_version: String) -> Result(CargoPlushie, ResolveError) {
  resolve_with(expected_version, environment_from_os())
}

@target(erlang)
/// Environment snapshot used by `resolve_with`.
///
/// Threaded explicitly so tests can exercise each path without touching
/// the actual OS environment or PATH.
pub type Environment {
  Environment(
    /// Value of `PLUSHIE_RUST_SOURCE_PATH`, if set.
    source_path: Result(String, Nil),
    /// `True` when `cargo-plushie` resolves on PATH.
    on_path: Bool,
    /// Raw output of `cargo-plushie --version` (only consulted when
    /// `on_path` is `True`).
    path_version_output: Result(String, String),
  )
}

@target(erlang)
/// Pure resolver used by `resolve/1` and tests. Does not touch the OS.
pub fn resolve_with(
  expected_version: String,
  env: Environment,
) -> Result(CargoPlushie, ResolveError) {
  case env.source_path {
    Ok(source) -> Ok(from_source(source))
    Error(_) ->
      case env.on_path {
        True -> check_path_version(expected_version, env.path_version_output)
        False -> Error(NotAvailable(expected_version:))
      }
  }
}

@target(erlang)
fn from_source(source: String) -> CargoPlushie {
  let manifest = source <> "/Cargo.toml"
  CargoPlushie(command: "cargo", args_prefix: [
    "run",
    "--manifest-path",
    manifest,
    "-p",
    "cargo-plushie",
    "--release",
    "--quiet",
    "--",
  ])
}

@target(erlang)
fn check_path_version(
  expected: String,
  output: Result(String, String),
) -> Result(CargoPlushie, ResolveError) {
  case output {
    Error(_) -> Error(NotAvailable(expected_version: expected))
    Ok(raw) ->
      case parse_version(raw) {
        Error(_) -> Error(UnparseableVersion(raw:))
        Ok(found) ->
          case found == expected {
            True -> Ok(CargoPlushie(command: "cargo-plushie", args_prefix: []))
            False ->
              Error(VersionMismatch(
                expected_version: expected,
                found_version: found,
              ))
          }
      }
  }
}

@target(erlang)
/// Extract the semantic version from `cargo-plushie --version` output.
///
/// The tool prints `cargo-plushie X.Y.Z` (possibly with trailing
/// whitespace). We take the last whitespace-separated token.
pub fn parse_version(raw: String) -> Result(String, Nil) {
  let trimmed = string.trim(raw)
  case trimmed {
    "" -> Error(Nil)
    _ -> {
      let tokens = string.split(trimmed, " ")
      last_token(tokens)
    }
  }
}

@target(erlang)
fn last_token(tokens: List(String)) -> Result(String, Nil) {
  case tokens {
    [] -> Error(Nil)
    [single] ->
      case single {
        "" -> Error(Nil)
        _ -> Ok(single)
      }
    [_, ..rest] -> last_token(rest)
  }
}

@target(erlang)
fn environment_from_os() -> Environment {
  let source_path = platform.get_env("PLUSHIE_RUST_SOURCE_PATH")
  let on_path = executable_exists("cargo-plushie")
  let version_output = case on_path {
    True -> run_command("cargo-plushie", ["--version"])
    False -> Error("cargo-plushie not on PATH")
  }
  Environment(source_path:, on_path:, path_version_output: version_output)
}

@target(erlang)
/// Render `ResolveError` as a human-readable message.
pub fn resolve_error_message(err: ResolveError) -> String {
  case err {
    NotAvailable(expected_version:) ->
      "cargo-plushie not found. Install with:\n"
      <> "  cargo install cargo-plushie --version "
      <> expected_version
      <> " --locked\n"
      <> "Or point at a plushie-rust checkout:\n"
      <> "  export PLUSHIE_RUST_SOURCE_PATH=/path/to/plushie-rust"
    VersionMismatch(expected_version:, found_version:) ->
      "cargo-plushie version mismatch: expected "
      <> expected_version
      <> ", found "
      <> found_version
      <> ".\n"
      <> "Reinstall with:\n"
      <> "  cargo install cargo-plushie --version "
      <> expected_version
      <> " --locked --force\n"
      <> "Or point at a plushie-rust checkout:\n"
      <> "  export PLUSHIE_RUST_SOURCE_PATH=/path/to/plushie-rust"
    UnparseableVersion(raw:) ->
      "Could not parse cargo-plushie --version output: " <> string.trim(raw)
  }
}

@target(erlang)
/// Turn a `CargoPlushie` into the final argv for a subcommand.
pub fn argv(tool: CargoPlushie, subcommand_args: List(String)) -> List(String) {
  [tool.command, ..list_concat(tool.args_prefix, subcommand_args)]
}

@target(erlang)
/// Just the args (without the executable name) for callers that build
/// Erlang Port specs separately.
pub fn args(tool: CargoPlushie, subcommand_args: List(String)) -> List(String) {
  list_concat(tool.args_prefix, subcommand_args)
}

@target(erlang)
fn list_concat(a: List(String), b: List(String)) -> List(String) {
  case a {
    [] -> b
    [first, ..rest] -> [first, ..list_concat(rest, b)]
  }
}

@target(erlang)
/// Convenience wrapper for CLI entry points that want a ready-to-print
/// error message on failure.
pub fn resolve_or_message(
  expected_version: String,
) -> Result(CargoPlushie, String) {
  resolve(expected_version)
  |> result.map_error(resolve_error_message)
}

// -- FFI used by the resolver --------------------------------------------------

@target(erlang)
@external(erlang, "plushie_build_ffi", "executable_exists")
fn executable_exists(name: String) -> Bool

@target(erlang)
@external(erlang, "plushie_build_ffi", "run_command")
fn run_command(cmd: String, args: List(String)) -> Result(String, String)
