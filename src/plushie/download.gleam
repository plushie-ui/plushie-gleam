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
//// Downloads the binary to build/plushie/bin/ and/or WASM files to
//// priv/wasm/ with SHA256 verification. Creates a bin/plushie symlink
//// pointing to the downloaded artifact. Skips if already present
//// unless --force.

import gleam/io
import gleam/string
import plushie/binary
import plushie/ffi

const binary_version = "0.4.1"

const base_url = "https://github.com/plushie-ui/plushie/releases/download"

const wasm_archive = "plushie-renderer-wasm.tar.gz"

/// Entry point for `gleam run -m plushie/download`.
pub fn main() -> Nil {
  let force = has_flag("--force")

  // Path flags imply their target
  let bin_file = get_flag_value("--bin-file")
  let wasm_dir = get_flag_value("--wasm-dir")

  let explicit_bin = has_flag("--bin") || is_ok(bin_file)
  let explicit_wasm = has_flag("--wasm") || is_ok(wasm_dir)

  // No explicit target = bin only (backward compatible)
  let want_bin = case explicit_bin, explicit_wasm {
    False, False -> True
    _, _ -> explicit_bin
  }
  let want_wasm = explicit_wasm

  case want_bin {
    True -> download_bin(bin_file, force)
    False -> Nil
  }

  case want_wasm {
    True -> download_wasm(wasm_dir, force)
    False -> Nil
  }
}

// -- Native binary ------------------------------------------------------------

fn download_bin(bin_file_override: Result(String, Nil), force: Bool) -> Nil {
  let platform = ffi.platform_string()
  let arch = ffi.arch_string()
  let name = "plushie-renderer-" <> platform <> "-" <> arch
  let url = release_url(name)
  let dest_path = case bin_file_override {
    Ok(path) -> path
    Error(_) -> binary.download_dir() <> "/" <> name
  }
  let dest_dir = dirname(dest_path)

  case ffi.file_exists(dest_path) && !force {
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
          create_bin_symlink(dest_path)
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

// -- WASM ---------------------------------------------------------------------

fn download_wasm(wasm_dir_override: Result(String, Nil), force: Bool) -> Nil {
  let url = release_url(wasm_archive)
  let extract_dir = case wasm_dir_override {
    Ok(dir) -> dir
    Error(_) -> "priv/wasm"
  }
  let tarball_path = extract_dir <> "/" <> wasm_archive

  let js_path = extract_dir <> "/plushie_wasm.js"
  let wasm_path = extract_dir <> "/plushie_wasm_bg.wasm"

  case ffi.file_exists(js_path) && ffi.file_exists(wasm_path) && !force {
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

fn create_bin_symlink(target_path: String) -> Nil {
  let link_dir = "bin"
  let link_path = link_dir <> "/plushie"
  ensure_dir(link_dir)
  // Remove existing symlink/file before creating
  delete_file(link_path)
  case make_symlink(target_path, link_path) {
    Ok(_) ->
      io.println("Created symlink " <> link_path <> " -> " <> target_path)
    Error(_) -> io.println("Warning: could not create symlink at " <> link_path)
  }
}

// -- Shared helpers -----------------------------------------------------------

fn release_url(artifact: String) -> String {
  base_url <> "/v" <> binary_version <> "/" <> artifact
}

fn dirname(path: String) -> String {
  case string.split(path, "/") {
    [_] -> "."
    parts -> {
      let assert [_, ..parent_parts] = list_reverse(parts)
      list_reverse(parent_parts) |> string.join("/")
    }
  }
}

fn list_reverse(items: List(a)) -> List(a) {
  do_list_reverse(items, [])
}

fn do_list_reverse(items: List(a), acc: List(a)) -> List(a) {
  case items {
    [] -> acc
    [first, ..rest] -> do_list_reverse(rest, [first, ..acc])
  }
}

fn is_ok(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> True
    Error(_) -> False
  }
}

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
      let actual = ffi.sha256_hex(file_body)

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

fn first_or(items: List(String), default: String) -> String {
  case items {
    [first, ..] -> first
    [] -> default
  }
}

// -- FFI bindings -------------------------------------------------------------

@external(erlang, "plushie_download_ffi", "download_binary")
fn download_binary(url: String, max_redirects: Int) -> Result(BitArray, String)

@external(erlang, "plushie_download_ffi", "has_flag")
fn has_flag(flag: String) -> Bool

@external(erlang, "plushie_download_ffi", "get_flag_value")
fn get_flag_value(flag: String) -> Result(String, Nil)

@external(erlang, "plushie_download_ffi", "ensure_dir")
fn ensure_dir(path: String) -> Nil

@external(erlang, "plushie_download_ffi", "write_file")
fn write_file(path: String, data: BitArray) -> Nil

@external(erlang, "plushie_download_ffi", "delete_file")
fn delete_file(path: String) -> Nil

@external(erlang, "plushie_download_ffi", "chmod")
fn chmod(path: String, mode: Int) -> Nil

@external(erlang, "plushie_download_ffi", "bytes_to_string")
fn bytes_to_string(data: BitArray) -> String

@external(erlang, "plushie_download_ffi", "extract_tarball")
fn extract_tarball(
  tarball_path: String,
  dest_dir: String,
) -> Result(Nil, String)

@external(erlang, "file", "read_file")
fn do_read_file(path: String) -> Result(BitArray, anything)

fn read_file(path: String) -> BitArray {
  let assert Ok(data) = do_read_file(path)
  data
}

@external(erlang, "plushie_download_ffi", "make_symlink")
fn make_symlink(target: String, link: String) -> Result(Nil, String)

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
