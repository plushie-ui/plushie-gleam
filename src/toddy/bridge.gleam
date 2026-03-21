//// Bridge actor: manages the Erlang Port to the Rust binary.
////
//// The bridge is a thin pipe -- it receives pre-encoded wire bytes
//// from the runtime and writes them to the port. Inbound port data
//// is decoded and forwarded to the runtime as events.
////
//// Wire framing:
//// - MessagePack: 4-byte big-endian length prefix (Erlang {packet, 4})
//// - JSONL: newline-delimited (Erlang {line, 65536})

import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dyn_decode
import gleam/erlang/port.{type Port}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/otp/actor
import gleam/result
import toddy/ffi
import toddy/protocol
import toddy/protocol/decode.{type InboundMessage}
import toddy/renderer_env

/// Messages the bridge actor handles.
pub type BridgeMessage {
  /// Send pre-encoded wire bytes to the Rust binary.
  Send(data: BitArray)
  /// Port data received from the Rust binary (via selector).
  PortData(data: Dynamic)
  /// Line data received from the Rust binary in JSON mode (via selector).
  PortLineData(line_data: ffi.LineData)
  /// Port closed/exited (via selector).
  PortExit(status: Dynamic)
  /// Graceful shutdown request.
  Shutdown
}

/// Internal bridge state.
pub opaque type BridgeState {
  BridgeState(
    port: Port,
    format: protocol.Format,
    runtime: Subject(RuntimeNotification),
    session: String,
    /// Buffer for accumulating partial JSON lines (noeol chunks).
    json_buffer: BitArray,
  )
}

/// Notifications sent from bridge to runtime.
pub type RuntimeNotification {
  /// A decoded inbound message from the Rust binary.
  InboundEvent(InboundMessage)
  /// The Rust binary process exited.
  RendererExited(status: Int)
}

// Maximum buffer size for partial JSON lines (64 MiB).
const max_json_buffer_size = 67_108_864

/// Start the bridge actor.
///
/// Opens a port to the toddy binary and begins forwarding messages.
/// Inbound wire data is decoded and sent as RuntimeNotification
/// values to the provided runtime subject.
pub fn start(
  binary_path: String,
  format: protocol.Format,
  runtime: Subject(RuntimeNotification),
  session: String,
) -> Result(Subject(BridgeMessage), actor.StartError) {
  actor.new_with_initialiser(5000, fn(subject) {
    let options = case format {
      protocol.Msgpack -> ffi.msgpack_port_options()
      protocol.Json -> ffi.json_port_options()
    }

    let args = case format {
      protocol.Json -> ["--json"]
      protocol.Msgpack -> []
    }

    let env_entries = renderer_env.build(renderer_env.default_opts())
    let env = renderer_env.to_port_env(env_entries)

    let port = ffi.open_port_spawn(binary_path, args, env, options)

    let selector =
      process.new_selector()
      |> process.select(subject)
      |> process.select_other(classify_port_message(format, _))

    let state =
      BridgeState(port:, format:, runtime:, session:, json_buffer: <<>>)

    actor.initialised(state)
    |> actor.selecting(selector)
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

fn handle_message(
  state: BridgeState,
  msg: BridgeMessage,
) -> actor.Next(BridgeState, BridgeMessage) {
  case msg {
    Send(data:) -> {
      // Wrap port_command in try_call to catch errors when the
      // port is already closed (e.g. renderer crashed).
      case ffi.try_call(fn() { ffi.port_command(state.port, data) }) {
        Ok(_) -> Nil
        Error(_) -> {
          io.println("toddy bridge: port closed during send")
          Nil
        }
      }
      actor.continue(state)
    }

    PortData(data:) -> {
      let new_state = handle_port_data(state, data)
      actor.continue(new_state)
    }

    PortLineData(line_data:) -> {
      let new_state = handle_line_data(state, line_data)
      actor.continue(new_state)
    }

    PortExit(status:) -> {
      let exit_code = case dyn_decode.run(status, dyn_decode.int) {
        Ok(code) -> code
        Error(_) -> 1
      }
      process.send(state.runtime, RendererExited(status: exit_code))
      actor.stop()
    }

    Shutdown -> {
      ffi.port_close(state.port)
      actor.stop()
    }
  }
}

fn handle_port_data(state: BridgeState, raw: Dynamic) -> BridgeState {
  case dyn_decode.run(raw, dyn_decode.bit_array) {
    Ok(bytes) -> {
      dispatch_decoded(state, bytes)
    }
    Error(_) -> {
      io.println("toddy bridge: received non-binary port data")
      state
    }
  }
}

/// Handle line-buffered data from JSON mode ({line, N} port driver).
/// Accumulates noeol chunks in the buffer, flushes on eol.
fn handle_line_data(state: BridgeState, line_data: ffi.LineData) -> BridgeState {
  case line_data {
    ffi.Eol(data:) -> {
      let line = bit_array.append(state.json_buffer, data)
      let new_state = BridgeState(..state, json_buffer: <<>>)
      dispatch_decoded(new_state, line)
    }
    ffi.Noeol(data:) -> {
      let new_buffer = bit_array.append(state.json_buffer, data)
      case bit_array.byte_size(new_buffer) > max_json_buffer_size {
        True -> {
          io.println(
            "toddy bridge: JSON buffer exceeded 64 MiB, dropping message",
          )
          BridgeState(..state, json_buffer: <<>>)
        }
        False -> BridgeState(..state, json_buffer: new_buffer)
      }
    }
  }
}

/// Decode a complete wire message and forward to the runtime.
fn dispatch_decoded(state: BridgeState, bytes: BitArray) -> BridgeState {
  case decode.decode_message(bytes, state.format) {
    Ok(msg) -> {
      process.send(state.runtime, InboundEvent(msg))
      state
    }
    Error(err) -> {
      io.println(
        "toddy bridge: decode error: " <> protocol.decode_error_to_string(err),
      )
      state
    }
  }
}

/// Classify raw Erlang port messages into BridgeMessage variants.
/// In JSON mode, the {line, N} driver delivers {eol, Data} and
/// {noeol, Data} tuples instead of plain binaries.
fn classify_port_message(format: protocol.Format, msg: Dynamic) -> BridgeMessage {
  case format {
    protocol.Json ->
      case ffi.extract_line_data(msg) {
        Ok(line_data) -> PortLineData(line_data:)
        Error(_) ->
          case ffi.extract_exit_status(msg) {
            Ok(status) -> PortExit(status:)
            Error(_) -> PortData(data: msg)
          }
      }
    protocol.Msgpack ->
      case ffi.extract_port_data(msg) {
        Ok(data) -> PortData(data:)
        Error(_) ->
          case ffi.extract_exit_status(msg) {
            Ok(status) -> PortExit(status:)
            Error(_) -> PortData(data: msg)
          }
      }
  }
}
