//// Wire protocol types and constants.
////
//// The plushie wire protocol supports two serialization formats:
//// MessagePack (default, length-prefixed) and JSONL (newline-delimited,
//// for debugging). Protocol version is embedded in the settings message
//// sent to the Rust binary on startup.

import gleam/int

pub const protocol_version = 1

/// Wire serialization format.
pub type Format {
  Json
  Msgpack
}

/// Encoding failed.
pub type EncodeError {
  SerializationFailed(String)
}

/// Decoding failed.
pub type DecodeError {
  DeserializationFailed(String)
  UnknownMessageType(String)
  UnknownEventFamily(String)
  MalformedEvent(String)
  ProtocolMismatch(expected: Int, got: Int)
}

/// Format an EncodeError as a human-readable string.
pub fn encode_error_to_string(err: EncodeError) -> String {
  case err {
    SerializationFailed(msg) -> "serialization failed: " <> msg
  }
}

/// Format a DecodeError as a human-readable string.
pub fn decode_error_to_string(err: DecodeError) -> String {
  case err {
    DeserializationFailed(msg) -> "deserialization failed: " <> msg
    UnknownMessageType(t) -> "unknown message type: " <> t
    UnknownEventFamily(f) -> "unknown event family: " <> f
    MalformedEvent(msg) -> "malformed event: " <> msg
    ProtocolMismatch(expected:, got:) ->
      "protocol mismatch: expected "
      <> int.to_string(expected)
      <> " got "
      <> int.to_string(got)
  }
}
