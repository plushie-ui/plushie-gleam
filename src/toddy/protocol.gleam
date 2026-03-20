//// Wire protocol types and constants.
////
//// The toddy wire protocol supports two serialization formats:
//// MessagePack (default, length-prefixed) and JSONL (newline-delimited,
//// for debugging). Protocol version is embedded in the settings message
//// sent to the Rust binary on startup.

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
