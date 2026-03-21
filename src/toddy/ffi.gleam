//// Erlang FFI wrappers for port operations, error handling, and
//// unique ID generation.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/port.{type Port}

/// Open a port to spawn an external process.
/// Uses {spawn_executable, Path} with explicit args and environment.
@external(erlang, "toddy_ffi", "open_port_spawn")
pub fn open_port_spawn(
  path: String,
  args: List(String),
  env: Dynamic,
  options: Dynamic,
) -> Port

/// Send data to a port. Returns True on success.
@external(erlang, "toddy_ffi", "port_command")
pub fn port_command(port: Port, data: BitArray) -> Bool

/// Close a port.
@external(erlang, "toddy_ffi", "port_close")
pub fn port_close(port: Port) -> Bool

/// Call a function with try/catch error handling.
/// Catches panics and exceptions, returning Result.
@external(erlang, "toddy_ffi", "try_call")
pub fn try_call(f: fn() -> a) -> Result(a, Dynamic)

/// Generate a unique monotonic ID string.
@external(erlang, "toddy_ffi", "unique_id")
pub fn unique_id() -> String

/// Port options for MessagePack wire format (4-byte length prefix).
@external(erlang, "toddy_ffi", "msgpack_port_options")
pub fn msgpack_port_options() -> Dynamic

/// Port options for JSONL wire format (newline-delimited).
@external(erlang, "toddy_ffi", "json_port_options")
pub fn json_port_options() -> Dynamic

/// Check whether a file exists at the given path.
@external(erlang, "toddy_ffi", "file_exists")
pub fn file_exists(path: String) -> Bool

/// Return the platform as a string (linux, darwin, windows, unknown).
@external(erlang, "toddy_ffi", "platform_string")
pub fn platform_string() -> String

/// Return the CPU architecture as a string (x86_64, aarch64, or raw).
@external(erlang, "toddy_ffi", "arch_string")
pub fn arch_string() -> String

/// Extract data payload from an Erlang port message tuple.
/// Works for {packet, N} mode where data is a plain binary.
@external(erlang, "toddy_ffi", "extract_port_data")
pub fn extract_port_data(msg: Dynamic) -> Result(Dynamic, Dynamic)

/// Line data from {line, N} port mode: complete line or partial chunk.
pub type LineData {
  Eol(data: BitArray)
  Noeol(data: BitArray)
}

/// Extract line data from a port message in {line, N} mode.
/// Returns Eol for complete lines, Noeol for partial chunks.
@external(erlang, "toddy_ffi", "extract_line_data")
pub fn extract_line_data(msg: Dynamic) -> Result(LineData, Dynamic)

/// Extract exit status from an Erlang port message tuple.
@external(erlang, "toddy_ffi", "extract_exit_status")
pub fn extract_exit_status(msg: Dynamic) -> Result(Dynamic, Dynamic)

/// Get an environment variable.
@external(erlang, "toddy_ffi", "get_env")
pub fn get_env(name: String) -> Result(String, Nil)

/// Set an environment variable.
@external(erlang, "toddy_ffi", "set_env")
pub fn set_env(name: String, value: String) -> Nil

/// Unset an environment variable.
@external(erlang, "toddy_ffi", "unset_env")
pub fn unset_env(name: String) -> Nil

/// Return the current monotonic time in milliseconds.
@external(erlang, "toddy_ffi", "monotonic_time_ms")
pub fn monotonic_time_ms() -> Int

/// Port options for stdio transport with MessagePack (eof, no exit_status).
@external(erlang, "toddy_ffi", "stdio_port_options_msgpack")
pub fn stdio_port_options_msgpack() -> Dynamic

/// Port options for stdio transport with JSON (eof, no exit_status).
@external(erlang, "toddy_ffi", "stdio_port_options_json")
pub fn stdio_port_options_json() -> Dynamic

/// Open an fd port (for stdin/stdout stdio transport).
@external(erlang, "toddy_ffi", "open_fd_port")
pub fn open_fd_port(input_fd: Int, output_fd: Int, options: Dynamic) -> Port

/// Extract eof signal from a port message {Port, eof}.
@external(erlang, "toddy_ffi", "extract_eof")
pub fn extract_eof(msg: Dynamic) -> Result(Nil, Dynamic)

/// Return a null port value for iostream transport (never used for I/O).
@external(erlang, "toddy_ffi", "null_port")
pub fn null_port() -> Port

/// Return a stable hash key for any value as a string.
/// Uses erlang:phash2 for consistent results regardless of how the
/// value is wrapped (raw term vs Dynamic).
@external(erlang, "toddy_ffi", "stable_hash_key")
pub fn stable_hash_key(value: Dynamic) -> String
