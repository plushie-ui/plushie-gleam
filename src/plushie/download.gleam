//// Download a precompiled plushie binary for the current platform.
////
//// Ships in the hex package. Users run:
////
//// ```sh
//// gleam run -m plushie/download
//// gleam run -m plushie/download -- --force
//// ```
////
//// Downloads the binary to priv/bin/ with SHA256 verification.
//// Skips if already present unless --force is passed.

import gleam/io
import gleam/string
import plushie/ffi

const binary_version = "0.4.1"

const base_url = "https://github.com/plushie-ui/plushie/releases/download"

/// Entry point for `gleam run -m plushie/download`.
pub fn main() -> Nil {
  let force = has_flag("--force")
  let platform = ffi.platform_string()
  let arch = ffi.arch_string()
  let name = "plushie-" <> platform <> "-" <> arch
  let url = base_url <> "/v" <> binary_version <> "/" <> name
  let dest_dir = "priv/bin"
  let dest_path = dest_dir <> "/" <> name

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
      io.println("Downloading " <> name <> " from " <> url <> "...")

      case download_binary(url, 5) {
        Ok(body) -> {
          write_file(dest_path, body)
          chmod(dest_path, 0o755)
          io.println("Downloaded to " <> dest_path)

          // Verify SHA256 checksum
          let checksum_url = url <> ".sha256"
          verify_checksum(dest_path, body, checksum_url)
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

fn verify_checksum(
  dest_path: String,
  body: BitArray,
  checksum_url: String,
) -> Nil {
  case download_binary(checksum_url, 5) {
    Ok(checksum_body) -> {
      let expected_raw = bytes_to_string(checksum_body)
      let expected =
        expected_raw
        |> string.trim
        |> string.split(" ")
        |> first_or("")
      let actual = ffi.sha256_hex(body)

      case actual == expected {
        True -> io.println("Checksum verified.")
        False -> {
          io.println_error(
            "Checksum mismatch! Expected " <> expected <> ", got " <> actual,
          )
          delete_file(dest_path)
          halt(1)
        }
      }
    }
    Error(reason) -> {
      delete_file(dest_path)
      io.println_error(
        "SHA256 checksum file could not be downloaded ("
        <> reason
        <> "). Refusing to use unverified binary. URL: "
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

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
