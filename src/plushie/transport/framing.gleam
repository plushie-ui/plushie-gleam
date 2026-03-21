//// Frame encoding and decoding for the plushie wire protocol.
////
//// Transports that deliver raw byte streams need framing logic.
//// This module provides it for both MessagePack (4-byte length
//// prefix) and JSONL (newline delimiter) modes.
////
//// Transports with built-in framing (e.g. Erlang Ports with
//// `{packet, 4}`) don't need this module.

import gleam/bit_array
import gleam/list

/// Encode a message with a 4-byte big-endian length prefix.
pub fn encode_packet(data: BitArray) -> BitArray {
  let size = bit_array.byte_size(data)
  <<size:size(32)-big, data:bits>>
}

/// Extract complete length-prefixed frames from a buffer.
/// Returns the decoded messages and any remaining partial data.
pub fn decode_packets(buffer: BitArray) -> #(List(BitArray), BitArray) {
  decode_packets_loop(buffer, [])
}

fn decode_packets_loop(
  buffer: BitArray,
  acc: List(BitArray),
) -> #(List(BitArray), BitArray) {
  case buffer {
    <<size:size(32)-big, rest:bits>> -> {
      case bit_array.byte_size(rest) >= size {
        True -> {
          let assert <<frame:bytes-size(size), remaining:bits>> = rest
          decode_packets_loop(remaining, [frame, ..acc])
        }
        False -> #(list.reverse(acc), buffer)
      }
    }
    _ -> #(list.reverse(acc), buffer)
  }
}

/// Encode a message with a newline terminator.
pub fn encode_line(data: BitArray) -> BitArray {
  bit_array.append(data, <<"\n":utf8>>)
}

/// Split a buffer on newline boundaries.
/// Returns complete lines and any remaining partial line.
pub fn decode_lines(buffer: BitArray) -> #(List(BitArray), BitArray) {
  decode_lines_loop(buffer, 0, [])
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
