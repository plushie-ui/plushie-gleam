//// Connect to an already-running plushie renderer via Unix socket or TCP.
////
//// Replaces stdio mode when the renderer uses `--listen` to create a
//// socket and either spawns this process (via `--exec`) or prints
//// connection info for manual use.
////
//// ## Usage
////
//// ```gleam
//// import plushie/connect
////
//// pub fn main() {
////   connect.main(my_app.app())
//// }
//// ```
////
//// ## Socket resolution (in order)
////
//// 1. `--socket` CLI flag
//// 2. PLUSHIE_SOCKET environment variable
//// 3. Error
////
//// ## Token resolution (in order)
////
//// 1. `--token` CLI flag
//// 2. PLUSHIE_TOKEN environment variable
//// 3. JSON line from stdin (1 second timeout): `{"token":"..."}`
//// 4. No token (renderer decides if that's OK)
////
//// ## Address auto-detection
////
//// - Paths starting with `/` = Unix domain socket
//// - `:port` = TCP localhost on that port
//// - `host:port` = TCP on specified host and port

import gleam/io
import gleam/option.{type Option, None, Some}
import plushie
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/ffi
import plushie/protocol
import plushie/socket_adapter

/// Options for connect mode.
pub type ConnectOpts {
  ConnectOpts(
    /// Wire format. Default: MessagePack.
    format: protocol.Format,
    /// Keep running after all windows close. Default: False.
    daemon: Bool,
  )
}

/// Default connect options.
pub fn default_opts() -> ConnectOpts {
  ConnectOpts(format: protocol.Msgpack, daemon: False)
}

/// Run a plushie application connected to an external renderer.
///
/// Parses CLI args for socket address and token, connects via the
/// socket adapter, and blocks until the runtime exits.
pub fn run(app: App(model, Event), opts: ConnectOpts) -> Nil {
  let socket_addr = resolve_socket()
  let token = resolve_token()

  case socket_adapter.start(socket_addr, opts.format) {
    Ok(adapter_subject) -> {
      let start_opts =
        plushie.StartOpts(
          ..plushie.default_start_opts(),
          binary_path: None,
          format: opts.format,
          daemon: opts.daemon,
          transport: plushie.Iostream(adapter: adapter_subject),
          token: token,
        )

      case plushie.start(app, start_opts) {
        Ok(instance) -> {
          plushie.wait(instance)
        }
        Error(err) -> {
          io.println_error(
            "Failed to start plushie: " <> plushie.start_error_to_string(err),
          )
          halt(1)
        }
      }
    }
    Error(reason) -> {
      io.println_error("Failed to connect to renderer: " <> reason)
      halt(1)
    }
  }
}

fn resolve_socket() -> String {
  case get_flag_value("--socket") {
    Ok(addr) -> addr
    Error(_) ->
      case ffi.get_env("PLUSHIE_SOCKET") {
        Ok(addr) -> addr
        Error(_) -> {
          io.println_error(
            "No socket address provided. Pass --socket or set PLUSHIE_SOCKET.",
          )
          halt(1)
          panic as "unreachable"
        }
      }
  }
}

fn resolve_token() -> Option(String) {
  case get_flag_value("--token") {
    Ok(token) -> Some(token)
    Error(_) ->
      case ffi.get_env("PLUSHIE_TOKEN") {
        Ok(token) -> Some(token)
        Error(_) -> read_token_from_stdin()
      }
  }
}

fn read_token_from_stdin() -> Option(String) {
  case read_stdin_line_timeout(1000) {
    Ok(line) -> parse_negotiation_token(line)
    Error(_) -> None
  }
}

fn parse_negotiation_token(line: String) -> Option(String) {
  case parse_json_token(line) {
    Ok(token) -> Some(token)
    Error(_) -> None
  }
}

@external(erlang, "plushie_connect_ffi", "get_flag_value")
fn get_flag_value(flag: String) -> Result(String, Nil)

@external(erlang, "plushie_connect_ffi", "read_stdin_line_timeout")
fn read_stdin_line_timeout(timeout_ms: Int) -> Result(String, Nil)

@external(erlang, "plushie_connect_ffi", "parse_json_token")
fn parse_json_token(line: String) -> Result(String, Nil)

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
