//// Build the plushie binary and/or WASM renderer from source.
////
//// Ships in the hex package. Users run:
////
//// ```sh
//// gleam run -m plushie/build                        # native binary (default)
//// gleam run -m plushie/build -- --release            # optimized build
//// gleam run -m plushie/build -- --wasm               # WASM renderer only
//// gleam run -m plushie/build -- --bin --wasm         # both
//// gleam run -m plushie/build -- --verbose            # print cargo output
//// gleam run -m plushie/build -- --bin-file PATH      # custom binary dest
//// gleam run -m plushie/build -- --wasm-dir PATH      # custom WASM dest
//// ```
////
//// Requires PLUSHIE_SOURCE_PATH env var pointing to the plushie Rust
//// source checkout. Checks Rust toolchain version, runs cargo build,
//// and installs the binary to build/plushie/bin/. Creates a
//// bin/plushie symlink. WASM files go to priv/wasm/.
////
//// `--bin-file` overrides the default binary destination. The parent
//// directory is created automatically. `--wasm-dir` overrides the
//// default WASM output directory (priv/wasm/).

import gleam/io
import gleam/list
import gleam/string
import plushie/binary
import plushie/config
import plushie/platform

const min_rust_version = "1.92.0"

/// Entry point for `gleam run -m plushie/build`.
pub fn main() -> Nil {
  let release = has_flag("--release")
  let verbose = has_flag("--verbose")

  // Resolve paths: CLI flag > gleam.toml [plushie] > default
  let bin_file =
    get_flag_value("--bin-file")
    |> or_config("bin_file")
  let wasm_dir =
    get_flag_value("--wasm-dir")
    |> or_config("wasm_dir")

  // Only CLI flags (not config paths) imply artifact selection
  let cli_bin_file = get_flag_value("--bin-file")
  let cli_wasm_dir = get_flag_value("--wasm-dir")
  let #(want_bin, want_wasm) = resolve_artifacts(cli_bin_file, cli_wasm_dir)

  case want_bin {
    True -> build_bin(release, verbose, bin_file)
    False -> Nil
  }

  case want_wasm {
    True -> build_wasm(release, verbose, wasm_dir)
    False -> Nil
  }
}

// -- Native binary build ------------------------------------------------------

fn build_bin(
  release: Bool,
  verbose: Bool,
  bin_file_override: Result(String, Nil),
) -> Nil {
  check_rust_toolchain()

  let source_dir = resolve_source_path()

  case dir_exists(source_dir) {
    False -> {
      io.println_error(
        "Error: plushie source not found at " <> source_dir <> ".",
      )
      halt(1)
    }
    True -> Nil
  }

  let label = case release {
    True -> "Building plushie (release)..."
    False -> "Building plushie..."
  }
  io.println(label)

  case cargo_build(source_dir, release) {
    Ok(output) -> {
      io.println("Build succeeded.")
      case verbose {
        True -> io.println(output)
        False -> Nil
      }
      install_binary(source_dir, release, bin_file_override)
    }
    Error(output) -> {
      io.println_error("Build failed:")
      io.println_error(output)
      halt(1)
    }
  }
}

// -- WASM build ---------------------------------------------------------------

fn build_wasm(
  release: Bool,
  verbose: Bool,
  wasm_dir_override: Result(String, Nil),
) -> Nil {
  case check_wasm_pack() {
    Error(msg) -> {
      io.println_error(msg)
      halt(1)
    }
    Ok(_) -> Nil
  }

  let source_dir = resolve_source_path()

  let wasm_crate = source_dir <> "/plushie-renderer-wasm"

  case dir_exists(wasm_crate) {
    False -> {
      io.println_error(
        "plushie-renderer-wasm crate not found at " <> wasm_crate <> ".",
      )
      io.println_error("")
      io.println_error(
        "The WASM build requires the plushie source checkout to include",
      )
      io.println_error("the plushie-renderer-wasm crate directory.")
      halt(1)
    }
    True -> Nil
  }

  let label = case release {
    True -> "Building plushie-renderer-wasm (release)..."
    False -> "Building plushie-renderer-wasm..."
  }
  io.println(label)

  case wasm_pack_build(wasm_crate, release) {
    Ok(output) -> {
      io.println("WASM build succeeded.")
      case verbose {
        True -> io.println(output)
        False -> Nil
      }
      install_wasm(wasm_crate, wasm_dir_override)
    }
    Error(output) -> {
      io.println_error("WASM build failed:")
      io.println_error(output)
      halt(1)
    }
  }
}

fn install_wasm(
  wasm_crate: String,
  wasm_dir_override: Result(String, Nil),
) -> Nil {
  let pkg_dir = wasm_crate <> "/pkg"
  let dest_dir = case wasm_dir_override {
    Ok(dir) -> dir
    Error(_) -> "priv/wasm"
  }
  ensure_dir(dest_dir)

  copy_wasm_file(pkg_dir, dest_dir, "plushie_renderer_wasm.js")
  copy_wasm_file(pkg_dir, dest_dir, "plushie_renderer_wasm_bg.wasm")

  io.println("Installed WASM files to " <> dest_dir)
}

fn copy_wasm_file(pkg_dir: String, dest_dir: String, name: String) -> Nil {
  let src = pkg_dir <> "/" <> name
  let dest = dest_dir <> "/" <> name
  case platform.file_exists(src) {
    True -> copy_file(src, dest)
    False ->
      io.println_error(
        "Warning: expected " <> src <> " not found in wasm-pack output",
      )
  }
}

// -- Shared -------------------------------------------------------------------

fn check_rust_toolchain() -> Nil {
  case rustc_version() {
    Error(msg) -> {
      io.println_error(msg)
      halt(1)
    }
    Ok(version_str) -> {
      case compare_versions(version_str, min_rust_version) {
        Error(_) -> {
          io.println(
            "Warning: could not parse rustc version from: " <> version_str,
          )
        }
        Ok(is_ok) ->
          case is_ok {
            False -> {
              io.println(
                "Warning: rustc "
                <> version_str
                <> " detected, but plushie requires >= "
                <> min_rust_version
                <> ". Consider upgrading with `rustup update`.",
              )
            }
            True -> Nil
          }
      }
    }
  }
}

fn install_binary(
  source_dir: String,
  release: Bool,
  bin_file_override: Result(String, Nil),
) -> Nil {
  let profile = case release {
    True -> "release"
    False -> "debug"
  }
  let platform = platform.platform_string()
  let arch = platform.arch_string()
  let binary_name = "plushie-renderer-" <> platform <> "-" <> arch
  let src = source_dir <> "/target/" <> profile <> "/plushie-renderer"

  case platform.file_exists(src) {
    False -> {
      io.println_error("Build succeeded but binary not found at " <> src)
      halt(1)
    }
    True -> Nil
  }

  let dest = case bin_file_override {
    Ok(path) -> path
    Error(_) -> binary.download_dir() <> "/" <> binary_name
  }
  let dest_dir = dirname(dest)
  ensure_dir(dest_dir)
  copy_file(src, dest)
  chmod(dest, 0o755)
  create_bin_symlink(dest)
  io.println("Installed to " <> dest)
}

fn create_bin_symlink(target_path: String) -> Nil {
  let link_dir = "bin"
  let link_path = link_dir <> "/plushie-renderer"
  ensure_dir(link_dir)
  // Remove existing symlink/file before creating
  delete_file(link_path)
  case make_symlink(target_path, link_path) {
    Ok(_) ->
      io.println("Created symlink " <> link_path <> " -> " <> target_path)
    Error(_) -> io.println("Warning: could not create symlink at " <> link_path)
  }
}

fn compare_versions(actual: String, minimum: String) -> Result(Bool, Nil) {
  let actual_parts = string.split(actual, ".")
  let min_parts = string.split(minimum, ".")
  case actual_parts, min_parts {
    [a_maj, a_min, a_patch], [m_maj, m_min, m_patch] -> {
      case
        parse_int(a_maj),
        parse_int(a_min),
        parse_int(a_patch),
        parse_int(m_maj),
        parse_int(m_min),
        parse_int(m_patch)
      {
        Ok(am), Ok(ai), Ok(ap), Ok(mm), Ok(mi), Ok(mp) ->
          Ok(
            am > mm
            || { am == mm && ai > mi }
            || { am == mm && ai == mi && ap >= mp },
          )
        _, _, _, _, _, _ -> Error(Nil)
      }
    }
    _, _ -> Error(Nil)
  }
}

// -- FFI bindings -------------------------------------------------------------

@external(erlang, "plushie_build_ffi", "rustc_version")
fn rustc_version() -> Result(String, String)

@external(erlang, "plushie_build_ffi", "cargo_build")
fn cargo_build(source_dir: String, release: Bool) -> Result(String, String)

@external(erlang, "plushie_build_ffi", "has_flag")
fn has_flag(flag: String) -> Bool

@external(erlang, "plushie_build_ffi", "get_flag_value")
fn get_flag_value(flag: String) -> Result(String, Nil)

@external(erlang, "plushie_build_ffi", "ensure_dir")
fn ensure_dir(path: String) -> Nil

@external(erlang, "plushie_build_ffi", "copy_file")
fn copy_file(src: String, dest: String) -> Nil

@external(erlang, "plushie_build_ffi", "chmod")
fn chmod(path: String, mode: Int) -> Nil

@external(erlang, "plushie_build_ffi", "dir_exists")
fn dir_exists(path: String) -> Bool

@external(erlang, "plushie_build_ffi", "delete_file")
fn delete_file(path: String) -> Nil

@external(erlang, "plushie_build_ffi", "make_symlink")
fn make_symlink(target: String, link: String) -> Result(Nil, String)

@external(erlang, "plushie_build_ffi", "parse_int")
fn parse_int(s: String) -> Result(Int, Nil)

@external(erlang, "plushie_build_ffi", "check_wasm_pack")
fn check_wasm_pack() -> Result(Nil, String)

@external(erlang, "plushie_build_ffi", "wasm_pack_build")
fn wasm_pack_build(crate_dir: String, release: Bool) -> Result(String, String)

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

// -- Helpers ------------------------------------------------------------------

fn is_ok(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Resolve which artifacts to build.
///
/// CLI flags > gleam.toml [plushie] artifacts > default (bin only).
fn resolve_artifacts(
  bin_file: Result(String, Nil),
  wasm_dir: Result(String, Nil),
) -> #(Bool, Bool) {
  let cli_bin = has_flag("--bin") || is_ok(bin_file)
  let cli_wasm = has_flag("--wasm") || is_ok(wasm_dir)

  case cli_bin || cli_wasm {
    True -> #(cli_bin, cli_wasm)
    False ->
      // No CLI flags -- check gleam.toml config
      case config.get_artifacts() {
        Ok(artifacts) -> #(
          list.contains(artifacts, "bin"),
          list.contains(artifacts, "wasm"),
        )
        Error(_) -> #(True, False)
      }
  }
}

/// Resolve the plushie source path.
///
/// Resolution: PLUSHIE_SOURCE_PATH env > gleam.toml source_path > error.
fn resolve_source_path() -> String {
  case platform.get_env("PLUSHIE_SOURCE_PATH") {
    Ok(path) -> path
    Error(_) ->
      case config.get_string("source_path") {
        Ok(path) -> path
        Error(_) -> {
          io.println_error("Error: plushie source path not configured.")
          io.println_error("")
          io.println_error("Set one of:")
          io.println_error(
            "  export PLUSHIE_SOURCE_PATH=/path/to/plushie-renderer",
          )
          io.println_error("")
          io.println_error("  # or in gleam.toml:")
          io.println_error("  [plushie]")
          io.println_error("  source_path = \"/path/to/plushie-renderer\"")
          halt(1)
          panic as "unreachable"
        }
      }
  }
}

/// Use a gleam.toml config value as fallback when the CLI flag is absent.
fn or_config(
  flag_result: Result(String, Nil),
  config_key: String,
) -> Result(String, Nil) {
  case flag_result {
    Ok(_) -> flag_result
    Error(_) -> config.get_string(config_key)
  }
}

fn dirname(path: String) -> String {
  case string.split(path, "/") {
    [_] -> "."
    parts -> {
      let reversed = list_reverse(parts)
      case reversed {
        [_, ..parent] -> list_reverse(parent) |> string.join("/")
        _ -> "."
      }
    }
  }
}

fn list_reverse(items: List(a)) -> List(a) {
  do_reverse(items, [])
}

fn do_reverse(items: List(a), acc: List(a)) -> List(a) {
  case items {
    [] -> acc
    [first, ..rest] -> do_reverse(rest, [first, ..acc])
  }
}
