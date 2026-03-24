//// Erlang Port FFI -- BEAM-only operations for managing the
//// renderer subprocess. All functions are @target(erlang).
////
//// Cross-target utilities (logging, env, hashing, time) live in
//// plushie/platform.gleam.

@target(erlang)
import gleam/dynamic.{type Dynamic}
@target(erlang)
import gleam/erlang/port.{type Port}

@target(erlang)
/// Open a port to spawn an external process.
@external(erlang, "plushie_ffi", "open_port_spawn")
pub fn open_port_spawn(
  path: String,
  args: List(String),
  env: Dynamic,
  options: Dynamic,
) -> Port

@target(erlang)
/// Send data to a port.
@external(erlang, "plushie_ffi", "port_command")
pub fn port_command(port: Port, data: BitArray) -> Bool

@target(erlang)
/// Close a port.
@external(erlang, "plushie_ffi", "port_close")
pub fn port_close(port: Port) -> Bool

@target(erlang)
/// Port options for MessagePack wire format (4-byte length prefix).
@external(erlang, "plushie_ffi", "msgpack_port_options")
pub fn msgpack_port_options() -> Dynamic

@target(erlang)
/// Port options for JSONL wire format (newline-delimited).
@external(erlang, "plushie_ffi", "json_port_options")
pub fn json_port_options() -> Dynamic

@target(erlang)
/// Extract data payload from an Erlang port message tuple.
@external(erlang, "plushie_ffi", "extract_port_data")
pub fn extract_port_data(msg: Dynamic) -> Result(Dynamic, Dynamic)

/// Line data from {line, N} port mode: complete line or partial chunk.
pub type LineData {
  Eol(data: BitArray)
  Noeol(data: BitArray)
}

@target(erlang)
/// Extract line data from a port message in {line, N} mode.
@external(erlang, "plushie_ffi", "extract_line_data")
pub fn extract_line_data(msg: Dynamic) -> Result(LineData, Dynamic)

@target(erlang)
/// Extract exit status from an Erlang port message tuple.
@external(erlang, "plushie_ffi", "extract_exit_status")
pub fn extract_exit_status(msg: Dynamic) -> Result(Dynamic, Dynamic)

@target(erlang)
/// Port options for stdio transport with MessagePack.
@external(erlang, "plushie_ffi", "stdio_port_options_msgpack")
pub fn stdio_port_options_msgpack() -> Dynamic

@target(erlang)
/// Port options for stdio transport with JSON.
@external(erlang, "plushie_ffi", "stdio_port_options_json")
pub fn stdio_port_options_json() -> Dynamic

@target(erlang)
/// Open an fd port (for stdin/stdout stdio transport).
@external(erlang, "plushie_ffi", "open_fd_port")
pub fn open_fd_port(input_fd: Int, output_fd: Int, options: Dynamic) -> Port

@target(erlang)
/// Extract eof signal from a port message.
@external(erlang, "plushie_ffi", "extract_eof")
pub fn extract_eof(msg: Dynamic) -> Result(Nil, Dynamic)

@target(erlang)
/// Return a null port value for iostream transport.
@external(erlang, "plushie_ffi", "null_port")
pub fn null_port() -> Port
