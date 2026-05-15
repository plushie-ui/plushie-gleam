//// Run a plushie app from a standalone entry point.
////
//// Uses an already-running renderer when a socket is provided. Otherwise
//// starts the renderer through normal SDK binary resolution, including
//// `PLUSHIE_BINARY_PATH`.
////
//// ## Usage
////
//// ```gleam
//// import plushie/connect
////
//// pub fn main() {
////   connect.run(my_app.app(), connect.default_opts())
//// }
//// ```
////
//// ## Socket resolution for connect mode (in order)
////
//// 1. `--socket` CLI flag
//// 2. PLUSHIE_SOCKET environment variable
//// 3. No socket, start a renderer child process
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

@target(erlang)
import gleam/io
@target(erlang)
import gleam/option.{type Option, None, Some}
@target(erlang)
import plushie
@target(erlang)
import plushie/app.{type App}
@target(erlang)
import plushie/platform
@target(erlang)
import plushie/protocol
@target(erlang)
import plushie/socket_adapter

@target(erlang)
/// Options for connect mode.
pub type ConnectOpts {
  ConnectOpts(
    /// Wire format. Default: MessagePack.
    format: protocol.Format,
    /// Keep running after all windows close. Default: False.
    daemon: Bool,
  )
}

@target(erlang)
/// Default connect options.
pub fn default_opts() -> ConnectOpts {
  ConnectOpts(format: protocol.Msgpack, daemon: False)
}

@target(erlang)
/// Run a plushie application from a standalone entry point.
///
/// When a socket is provided by CLI or `PLUSHIE_SOCKET`, connects to
/// that renderer. Otherwise starts the renderer as a child process
/// using normal binary resolution, including `PLUSHIE_BINARY_PATH`.
pub fn run(app: App(model, msg), opts: ConnectOpts) -> Nil {
  case resolve_socket() {
    Some(socket_addr) -> run_socket(app, opts, socket_addr)
    None -> run_spawn(app, opts)
  }
}

@target(erlang)
fn run_socket(
  app: App(model, msg),
  opts: ConnectOpts,
  socket_addr: String,
) -> Nil {
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

@target(erlang)
fn run_spawn(app: App(model, msg), opts: ConnectOpts) -> Nil {
  let start_opts =
    plushie.StartOpts(
      ..plushie.default_start_opts(),
      format: opts.format,
      daemon: opts.daemon,
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

@target(erlang)
fn resolve_socket() -> Option(String) {
  case get_flag_value("--socket") {
    Ok(addr) -> Some(addr)
    Error(_) ->
      case platform.get_env("PLUSHIE_SOCKET") {
        Ok(addr) -> Some(addr)
        Error(_) -> None
      }
  }
}

@target(erlang)
fn resolve_token() -> Option(String) {
  case get_flag_value("--token") {
    Ok(token) -> Some(token)
    Error(_) ->
      case platform.get_env("PLUSHIE_TOKEN") {
        Ok(token) -> Some(token)
        Error(_) -> read_token_from_stdin()
      }
  }
}

@target(erlang)
fn read_token_from_stdin() -> Option(String) {
  case read_stdin_line_timeout(1000) {
    Ok(line) -> parse_negotiation_token(line)
    Error(_) -> None
  }
}

@target(erlang)
fn parse_negotiation_token(line: String) -> Option(String) {
  case parse_json_token(line) {
    Ok(token) -> Some(token)
    Error(_) -> None
  }
}

@target(erlang)
@external(erlang, "plushie_connect_ffi", "get_flag_value")
fn get_flag_value(flag: String) -> Result(String, Nil)

@target(erlang)
@external(erlang, "plushie_connect_ffi", "read_stdin_line_timeout")
fn read_stdin_line_timeout(timeout_ms: Int) -> Result(String, Nil)

@target(erlang)
@external(erlang, "plushie_connect_ffi", "parse_json_token")
fn parse_json_token(line: String) -> Result(String, Nil)

@target(erlang)
@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
