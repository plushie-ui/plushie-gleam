//// Erlang FFI wrappers for port operations, error handling, and
//// unique ID generation.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/port.{type Port}

/// Open a port to spawn an external process.
@external(erlang, "toddy_ffi", "open_port_spawn")
pub fn open_port_spawn(path: String, options: Dynamic) -> Port

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
@external(erlang, "toddy_ffi", "extract_port_data")
pub fn extract_port_data(msg: Dynamic) -> Result(Dynamic, Dynamic)

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
