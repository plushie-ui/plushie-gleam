//// Build the plushie binary from source.
////
//// Ships in the hex package. Users run:
////
//// ```sh
//// gleam run -m plushie/build
//// gleam run -m plushie/build -- --release
//// gleam run -m plushie/build -- --verbose
//// ```
////
//// Requires PLUSHIE_SOURCE_PATH env var pointing to the plushie Rust
//// source checkout. Checks Rust toolchain version, runs cargo build,
//// and installs the binary to priv/bin/.

import gleam/io
import gleam/string
import plushie/ffi

const min_rust_version = "1.92.0"

/// Entry point for `gleam run -m plushie/build`.
pub fn main() -> Nil {
  check_rust_toolchain()

  let release = has_flag("--release")
  let verbose = has_flag("--verbose")

  let source_dir = case ffi.get_env("PLUSHIE_SOURCE_PATH") {
    Ok(path) -> path
    Error(_) -> {
      io.println_error("Error: PLUSHIE_SOURCE_PATH not set.")
      io.println_error("")
      io.println_error("Set it to the plushie Rust source checkout:")
      io.println_error("  export PLUSHIE_SOURCE_PATH=/path/to/plushie")
      halt(1)
      panic as "unreachable"
    }
  }

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
      install_binary(source_dir, release)
    }
    Error(output) -> {
      io.println_error("Build failed:")
      io.println_error(output)
      halt(1)
    }
  }
}

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

fn install_binary(source_dir: String, release: Bool) -> Nil {
  let profile = case release {
    True -> "release"
    False -> "debug"
  }
  let platform = ffi.platform_string()
  let arch = ffi.arch_string()
  let binary_name = "plushie-" <> platform <> "-" <> arch
  let src = source_dir <> "/target/" <> profile <> "/plushie"

  case ffi.file_exists(src) {
    False -> {
      io.println_error("Build succeeded but binary not found at " <> src)
      halt(1)
    }
    True -> Nil
  }

  let dest_dir = "priv/bin"
  let dest = dest_dir <> "/" <> binary_name
  ensure_dir(dest_dir)
  copy_file(src, dest)
  chmod(dest, 0o755)
  io.println("Installed to " <> dest)
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

@external(erlang, "plushie_build_ffi", "ensure_dir")
fn ensure_dir(path: String) -> Nil

@external(erlang, "plushie_build_ffi", "copy_file")
fn copy_file(src: String, dest: String) -> Nil

@external(erlang, "plushie_build_ffi", "chmod")
fn chmod(path: String, mode: Int) -> Nil

@external(erlang, "plushie_build_ffi", "dir_exists")
fn dir_exists(path: String) -> Bool

@external(erlang, "plushie_build_ffi", "parse_int")
fn parse_int(s: String) -> Result(Int, Nil)

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
