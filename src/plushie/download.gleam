//// Download precompiled plushie artifacts for the current platform.
////
//// Ships in the hex package. Users run:
////
//// ```sh
//// gleam run -m plushie/download                    # native binary (default)
//// gleam run -m plushie/download -- --wasm           # WASM renderer only
//// gleam run -m plushie/download -- --bin --wasm     # both
//// gleam run -m plushie/download -- --force          # re-download
//// gleam run -m plushie/download -- --bin-file PATH  # custom binary dest
//// gleam run -m plushie/download -- --wasm-dir PATH  # custom WASM dest
//// ```
////
//// Downloads the binary to bin/plushie-renderer and/or WASM files to
//// priv/wasm/ with SHA256 verification. Skips if already present
//// unless --force.

@target(erlang)
import gleam/io
@target(erlang)
import gleam/list
@target(erlang)
import gleam/string
@target(erlang)
import plushie/binary
@target(erlang)
import plushie/config
@target(erlang)
import plushie/platform

@target(erlang)
const base_url = "https://github.com/plushie-ui/plushie-renderer/releases/download"

@target(erlang)
const wasm_archive = "plushie-renderer-wasm.tar.gz"

@target(erlang)
/// Entry point for `gleam run -m plushie/download`.
pub fn main() -> Nil {
  let force = has_flag("--force")
  let rust_version = require_plushie_rust_version()

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
    True -> download_bin(rust_version, bin_file, force)
    False -> Nil
  }

  case want_wasm {
    True -> download_wasm(rust_version, wasm_dir, force)
    False -> Nil
  }
}

// -- Native binary ------------------------------------------------------------

@target(erlang)
fn download_bin(
  rust_version: String,
  bin_file_override: Result(String, Nil),
  force: Bool,
) -> Nil {
  let platform = platform.platform_string()
  let arch = platform.arch_string()
  let ext = case platform {
    "windows" -> ".exe"
    _ -> ""
  }
  let name = "plushie-renderer-" <> platform <> "-" <> arch <> ext
  let url = release_url(rust_version, name)
  let dest_path = case bin_file_override {
    Ok(path) -> path
    Error(_) -> binary.download_dir() <> "/" <> binary.download_name()
  }

  case bin_file_override {
    Error(_) -> sync_renderer_with_tool(rust_version, force)
    Ok(_) -> download_renderer_direct(rust_version, name, url, dest_path, force)
  }
}

@target(erlang)
fn download_renderer_direct(
  _rust_version: String,
  name: String,
  url: String,
  dest_path: String,
  force: Bool,
) -> Nil {
  let dest_dir = dirname(dest_path)

  case platform.file_exists(dest_path) && !force {
    True -> {
      io.println(
        "Binary already exists at "
        <> dest_path
        <> ". Use --force to re-download.",
      )
    }
    False -> {
      ensure_dir(dest_dir)
      io.println("Downloading " <> name <> "...")

      case download_binary(url, 5) {
        Ok(body) -> {
          write_file(dest_path, body)
          chmod(dest_path, 0o755)
          verify_checksum(dest_path, url <> ".sha256")
          io.println("Installed native binary to " <> dest_path)
        }
        Error(reason) -> {
          io.println_error("Download failed: " <> reason)
          io.println_error("")
          io.println_error("To build from source instead:")
          io.println_error("  gleam run -m plushie/build")
          io.println_error("")
          io.println_error("To use an existing binary:")
          io.println_error("  export PLUSHIE_BINARY_PATH=/path/to/plushie")
          halt(1)
        }
      }
    }
  }
}

@target(erlang)
fn sync_renderer_with_tool(rust_version: String, force: Bool) -> Nil {
  let tool_path = download_tool(rust_version, force)
  let args = case force {
    True -> ["tools", "sync", "--required-version", rust_version, "--force"]
    False -> ["tools", "sync", "--required-version", rust_version]
  }

  case run_tool(tool_path, args) {
    Ok(output) -> {
      case output == "" {
        True -> Nil
        False -> io.println(string.trim_end(output))
      }
      io.println(
        "Installed native binary to "
        <> binary.download_dir()
        <> "/"
        <> binary.download_name(),
      )
    }
    Error(reason) -> {
      io.println_error("Renderer sync failed: " <> reason)
      halt(1)
    }
  }
}

@target(erlang)
fn download_tool(rust_version: String, force: Bool) -> String {
  let platform = platform.platform_string()
  let arch = platform.arch_string()
  let ext = case platform {
    "windows" -> ".exe"
    _ -> ""
  }
  let name = "plushie-" <> platform <> "-" <> arch <> ext
  let local_name = "plushie" <> ext
  let url = release_url(rust_version, name)
  let dest_path = binary.download_dir() <> "/" <> local_name

  case platform.file_exists(dest_path) && !force {
    True -> dest_path
    False -> {
      ensure_dir(binary.download_dir())
      io.println("Downloading " <> name <> "...")

      case download_binary(url, 5) {
        Ok(body) -> {
          write_file(dest_path, body)
          chmod(dest_path, 0o755)
          verify_checksum(dest_path, url <> ".sha256")
          io.println("Installed plushie tool to " <> dest_path)
          dest_path
        }
        Error(reason) -> {
          io.println_error("Plushie tool download failed: " <> reason)
          halt(1)
          dest_path
        }
      }
    }
  }
}

// -- WASM ---------------------------------------------------------------------

@target(erlang)
fn download_wasm(
  rust_version: String,
  wasm_dir_override: Result(String, Nil),
  force: Bool,
) -> Nil {
  let url = release_url(rust_version, wasm_archive)
  let extract_dir = case wasm_dir_override {
    Ok(dir) -> dir
    Error(_) -> "priv/wasm"
  }
  let tarball_path = extract_dir <> "/" <> wasm_archive

  let js_path = extract_dir <> "/plushie_renderer_wasm.js"
  let wasm_path = extract_dir <> "/plushie_renderer_wasm_bg.wasm"

  case
    platform.file_exists(js_path) && platform.file_exists(wasm_path) && !force
  {
    True -> {
      io.println(
        "WASM files already exist in "
        <> extract_dir
        <> ". Use --force to re-download.",
      )
    }
    False -> {
      ensure_dir(extract_dir)
      io.println("Downloading " <> wasm_archive <> "...")

      case download_binary(url, 5) {
        Ok(body) -> {
          write_file(tarball_path, body)
          verify_checksum(tarball_path, url <> ".sha256")

          case extract_tarball(tarball_path, extract_dir) {
            Ok(_) -> {
              delete_file(tarball_path)
              io.println("Installed WASM files to " <> extract_dir)
            }
            Error(reason) -> {
              delete_file(tarball_path)
              io.println_error(
                "Failed to extract " <> tarball_path <> ": " <> reason,
              )
              halt(1)
            }
          }
        }
        Error(reason) -> {
          io.println_error("WASM download failed: " <> reason)
          io.println_error("")
          io.println_error("To build from source instead:")
          io.println_error("  gleam run -m plushie/build -- --wasm")
          halt(1)
        }
      }
    }
  }
}

// -- Shared helpers -----------------------------------------------------------

@target(erlang)
pub fn release_url(rust_version: String, artifact: String) -> String {
  base_url <> "/v" <> rust_version <> "/" <> artifact
}

@target(erlang)
fn require_plushie_rust_version() -> String {
  case config.plushie_rust_version() {
    Ok(v) -> v
    Error(_) -> {
      io.println_error(config.missing_plushie_rust_version_message())
      halt(1)
      panic as "unreachable"
    }
  }
}

@target(erlang)
fn dirname(path: String) -> String {
  case string.split(path, "/") {
    [_] -> "."
    parts -> {
      let assert [_, ..parent_parts] = list_reverse(parts)
      list_reverse(parent_parts) |> string.join("/")
    }
  }
}

@target(erlang)
fn list_reverse(items: List(a)) -> List(a) {
  do_list_reverse(items, [])
}

@target(erlang)
fn do_list_reverse(items: List(a), acc: List(a)) -> List(a) {
  case items {
    [] -> acc
    [first, ..rest] -> do_list_reverse(rest, [first, ..acc])
  }
}

@target(erlang)
fn is_ok(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> True
    Error(_) -> False
  }
}

@target(erlang)
fn verify_checksum(file_path: String, checksum_url: String) -> Nil {
  case download_binary(checksum_url, 5) {
    Ok(checksum_body) -> {
      let expected_raw = bytes_to_string(checksum_body)
      let expected =
        expected_raw
        |> string.trim
        |> string.split(" ")
        |> first_or("")

      let file_body = read_file(file_path)
      let actual = platform.sha256_hex(file_body)

      case actual == expected {
        True -> io.println("Checksum verified.")
        False -> {
          io.println_error(
            "Checksum mismatch! Expected " <> expected <> ", got " <> actual,
          )
          delete_file(file_path)
          halt(1)
        }
      }
    }
    Error(reason) -> {
      delete_file(file_path)
      io.println_error(
        "SHA256 checksum file could not be downloaded ("
        <> reason
        <> "). Refusing to use unverified artifact. URL: "
        <> checksum_url,
      )
      halt(1)
    }
  }
}

@target(erlang)
fn first_or(items: List(String), default: String) -> String {
  case items {
    [first, ..] -> first
    [] -> default
  }
}

// -- FFI bindings -------------------------------------------------------------

@target(erlang)
@external(erlang, "plushie_download_ffi", "download_binary")
fn download_binary(url: String, max_redirects: Int) -> Result(BitArray, String)

@target(erlang)
@external(erlang, "plushie_download_ffi", "run_tool")
fn run_tool(path: String, args: List(String)) -> Result(String, String)

@target(erlang)
@external(erlang, "plushie_download_ffi", "has_flag")
fn has_flag(flag: String) -> Bool

@target(erlang)
@external(erlang, "plushie_download_ffi", "get_flag_value")
fn get_flag_value(flag: String) -> Result(String, Nil)

@target(erlang)
@external(erlang, "plushie_download_ffi", "ensure_dir")
fn ensure_dir(path: String) -> Nil

@target(erlang)
@external(erlang, "plushie_download_ffi", "write_file")
fn write_file(path: String, data: BitArray) -> Nil

@target(erlang)
@external(erlang, "plushie_download_ffi", "delete_file")
fn delete_file(path: String) -> Nil

@target(erlang)
@external(erlang, "plushie_download_ffi", "chmod")
fn chmod(path: String, mode: Int) -> Nil

@target(erlang)
@external(erlang, "plushie_download_ffi", "bytes_to_string")
fn bytes_to_string(data: BitArray) -> String

@target(erlang)
@external(erlang, "plushie_download_ffi", "extract_tarball")
fn extract_tarball(
  tarball_path: String,
  dest_dir: String,
) -> Result(Nil, String)

@target(erlang)
@external(erlang, "file", "read_file")
fn do_read_file(path: String) -> Result(BitArray, anything)

@target(erlang)
fn read_file(path: String) -> BitArray {
  let assert Ok(data) = do_read_file(path)
  data
}

@target(erlang)
@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

// -- Config helpers -----------------------------------------------------------

@target(erlang)
/// Resolve which artifacts to download.
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
      case config.get_artifacts() {
        Ok(artifacts) -> #(
          list.contains(artifacts, "bin"),
          list.contains(artifacts, "wasm"),
        )
        Error(_) -> #(True, False)
      }
  }
}

@target(erlang)
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
