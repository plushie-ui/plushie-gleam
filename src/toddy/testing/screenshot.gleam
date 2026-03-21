//// Screenshot for visual regression testing.
////
//// Captures pixel-level rendering data. The mock backend returns empty
//// stubs (no pixel data). Headless and windowed backends capture real
//// RGBA pixel data.
////
//// `save_png/2` writes raw RGBA data as a minimal valid PNG file using
//// pure Erlang (:zlib for deflate, :erlang.crc32 for chunk CRCs).

import gleam/bit_array
import gleam/string
import toddy/ffi

/// A screenshot capture.
pub type Screenshot {
  Screenshot(
    name: String,
    hash: String,
    width: Int,
    height: Int,
    pixels: BitArray,
  )
}

/// Create an empty screenshot stub (for mock backends).
pub fn empty(name: String) -> Screenshot {
  Screenshot(name:, hash: "", width: 0, height: 0, pixels: <<>>)
}

/// Save a screenshot as a minimal valid PNG file.
/// No-op when pixels are empty (mock backend stubs).
pub fn save_png(screenshot: Screenshot, path: String) -> Nil {
  case
    screenshot.width,
    screenshot.height,
    bit_array.byte_size(screenshot.pixels)
  {
    0, _, _ -> Nil
    _, 0, _ -> Nil
    _, _, 0 -> Nil
    w, h, _ -> {
      let png_data = encode_png(w, h, screenshot.pixels)
      write_file(path, png_data)
      Nil
    }
  }
}

/// Assert that a screenshot matches its golden file.
///
/// Screenshots with an empty hash (mock backend) are silently accepted.
/// Otherwise creates or compares golden files in the given directory.
/// Set TODDY_UPDATE_SCREENSHOTS=1 to force-update golden files.
pub fn assert_screenshot(
  screenshot: Screenshot,
  name: String,
  path: String,
) -> Nil {
  case screenshot.hash {
    "" -> Nil
    current_hash -> {
      let golden_path = path <> "/" <> name <> ".sha256"
      let update_mode = ffi.get_env("TODDY_UPDATE_SCREENSHOTS") == Ok("1")

      case file_exists(golden_path), update_mode {
        True, False -> {
          let assert Ok(stored) = read_file_text(golden_path)
          let expected = string.trim(stored)
          case expected == current_hash {
            True -> Nil
            False ->
              panic as {
                "Screenshot mismatch for \""
                <> name
                <> "\".\n\nExpected: "
                <> expected
                <> "\nActual:   "
                <> current_hash
                <> "\n\nRun with TODDY_UPDATE_SCREENSHOTS=1 to update.\nGolden file: "
                <> golden_path
              }
          }
        }
        _, _ -> {
          mkdir_p(dir_name(golden_path))
          write_file_text(golden_path, current_hash)
          Nil
        }
      }
    }
  }
}

// -- PNG encoding ------------------------------------------------------------

fn encode_png(width: Int, height: Int, rgba_data: BitArray) -> BitArray {
  // PNG signature
  let signature = <<137, 80, 78, 71, 13, 10, 26, 10>>

  // IHDR: width, height, bit_depth=8, color_type=6 (RGBA),
  // compression=0, filter=0, interlace=0
  let ihdr_data = <<width:32, height:32, 8, 6, 0, 0, 0>>
  let ihdr = png_chunk(<<"IHDR":utf8>>, ihdr_data)

  // IDAT: filter byte 0 (none) prepended to each row, then zlib compressed
  let filtered = add_filter_bytes(rgba_data, width, height, 0, <<>>)
  let compressed = ffi.zlib_compress(filtered)
  let idat = png_chunk(<<"IDAT":utf8>>, compressed)

  // IEND
  let iend = png_chunk(<<"IEND":utf8>>, <<>>)

  bit_array.concat([signature, ihdr, idat, iend])
}

fn add_filter_bytes(
  data: BitArray,
  width: Int,
  height: Int,
  row: Int,
  acc: BitArray,
) -> BitArray {
  case row >= height {
    True -> acc
    False -> {
      let row_size = width * 4
      let offset = row * row_size
      let assert Ok(row_data) = bit_array.slice(data, offset, row_size)
      let new_acc = bit_array.concat([acc, <<0>>, row_data])
      add_filter_bytes(data, width, height, row + 1, new_acc)
    }
  }
}

fn png_chunk(chunk_type: BitArray, data: BitArray) -> BitArray {
  let len = bit_array.byte_size(data)
  let crc_input = bit_array.concat([chunk_type, data])
  let crc = ffi.crc32(crc_input)
  <<len:32, chunk_type:bits, data:bits, crc:32>>
}

// -- File system helpers -----------------------------------------------------

@external(erlang, "toddy_snapshot_ffi", "file_exists")
fn file_exists(path: String) -> Bool

@external(erlang, "toddy_snapshot_ffi", "read_file")
fn read_file_text(path: String) -> Result(String, Nil)

@external(erlang, "toddy_snapshot_ffi", "write_file")
fn write_file_text(path: String, content: String) -> Nil

@external(erlang, "toddy_screenshot_ffi", "write_binary_file")
fn write_file(path: String, data: BitArray) -> Nil

@external(erlang, "toddy_snapshot_ffi", "mkdir_p")
fn mkdir_p(path: String) -> Nil

@external(erlang, "toddy_snapshot_ffi", "dir_name")
fn dir_name(path: String) -> String
