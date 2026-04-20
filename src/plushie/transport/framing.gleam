//// Frame encoding and decoding for the plushie wire protocol.
////
//// Transports that deliver raw byte streams need framing logic.
//// This module provides it for both MessagePack (4-byte length
//// prefix) and JSONL (newline delimiter) modes.
////
//// Transports with built-in framing (e.g. Erlang Ports with
//// `{packet, 4}`) don't need this module.
////
//// The decode paths reject frames or lines past
//// `max_message_size` by returning `Error(BufferOverflow(size,
//// limit))`. Oversized frames are always a protocol violation;
//// silently dropping them would risk desync, and the payload cannot
//// legitimately exceed the cap.

import gleam/bit_array
import gleam/list

/// Per-message size cap in bytes (64 MiB). Matches the renderer's
/// cap so both ends reject the same threshold.
pub const max_message_size: Int = 67_108_864

/// Error returned when a wire frame exceeds the per-message size cap.
///
/// Carries both the offending size and the configured limit for
/// structured handling on the caller side.
pub type FramingError {
  BufferOverflow(size: Int, limit: Int)
}

/// Encode a message with a 4-byte big-endian length prefix.
///
/// Returns `Error(BufferOverflow)` when `data` exceeds
/// `max_message_size`.
pub fn encode_packet(data: BitArray) -> Result(BitArray, FramingError) {
  let size = bit_array.byte_size(data)
  case size > max_message_size {
    True -> Error(BufferOverflow(size:, limit: max_message_size))
    False -> Ok(<<size:size(32)-big, data:bits>>)
  }
}

/// Extract complete length-prefixed frames from a buffer.
///
/// Returns the decoded messages and any remaining partial data, or
/// `Error(BufferOverflow)` when a length prefix declares an
/// oversized frame.
pub fn decode_packets(
  buffer: BitArray,
) -> Result(#(List(BitArray), BitArray), FramingError) {
  decode_packets_loop(buffer, [])
}

fn decode_packets_loop(
  buffer: BitArray,
  acc: List(BitArray),
) -> Result(#(List(BitArray), BitArray), FramingError) {
  case buffer {
    <<size:size(32)-big, _rest:bits>> if size > max_message_size ->
      Error(BufferOverflow(size:, limit: max_message_size))
    <<size:size(32)-big, rest:bits>> -> {
      case bit_array.byte_size(rest) >= size {
        True -> {
          let assert <<frame:bytes-size(size), remaining:bits>> = rest
          decode_packets_loop(remaining, [frame, ..acc])
        }
        False -> Ok(#(list.reverse(acc), buffer))
      }
    }
    _ -> Ok(#(list.reverse(acc), buffer))
  }
}

/// Encode a message with a newline terminator.
///
/// Returns `Error(BufferOverflow)` when `data` exceeds
/// `max_message_size`.
pub fn encode_line(data: BitArray) -> Result(BitArray, FramingError) {
  let size = bit_array.byte_size(data)
  case size > max_message_size {
    True -> Error(BufferOverflow(size:, limit: max_message_size))
    False -> Ok(bit_array.append(data, <<"\n":utf8>>))
  }
}

/// Split a buffer on newline boundaries.
///
/// Returns complete lines and any remaining partial line, or
/// `Error(BufferOverflow)` when a completed line or the tail
/// exceeds `max_message_size`.
pub fn decode_lines(
  buffer: BitArray,
) -> Result(#(List(BitArray), BitArray), FramingError) {
  case decode_lines_loop(buffer, 0, []) {
    #(lines, remaining) -> {
      case find_overflow(lines) {
        Ok(Nil) ->
          case bit_array.byte_size(remaining) > max_message_size {
            True ->
              Error(BufferOverflow(
                size: bit_array.byte_size(remaining),
                limit: max_message_size,
              ))
            False -> Ok(#(lines, remaining))
          }
        Error(err) -> Error(err)
      }
    }
  }
}

fn find_overflow(lines: List(BitArray)) -> Result(Nil, FramingError) {
  case lines {
    [] -> Ok(Nil)
    [head, ..rest] -> {
      let size = bit_array.byte_size(head)
      case size > max_message_size {
        True -> Error(BufferOverflow(size:, limit: max_message_size))
        False -> find_overflow(rest)
      }
    }
  }
}

fn decode_lines_loop(
  buffer: BitArray,
  pos: Int,
  acc: List(BitArray),
) -> #(List(BitArray), BitArray) {
  case pos >= bit_array.byte_size(buffer) {
    True -> #(list.reverse(acc), buffer)
    False -> {
      case bit_array.slice(buffer, pos, 1) {
        Ok(<<"\n":utf8>>) -> {
          let assert Ok(line) = bit_array.slice(buffer, 0, pos)
          let remaining_start = pos + 1
          let remaining_len = bit_array.byte_size(buffer) - remaining_start
          let assert Ok(remaining) =
            bit_array.slice(buffer, remaining_start, remaining_len)
          decode_lines_loop(remaining, 0, [line, ..acc])
        }
        _ -> decode_lines_loop(buffer, pos + 1, acc)
      }
    }
  }
}
