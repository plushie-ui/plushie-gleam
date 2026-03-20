//// Bridge actor: manages the Erlang Port to the Rust binary.
////
//// The bridge is a thin pipe -- it receives pre-encoded wire bytes
//// from the runtime and writes them to the port. Inbound port data
//// is decoded and forwarded to the runtime as events.
////
//// Wire framing:
//// - MessagePack: 4-byte big-endian length prefix (Erlang {packet, 4})
//// - JSONL: newline-delimited (Erlang {line, 65536})

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

/// Messages the bridge actor handles.
pub type BridgeMessage {
  /// Send pre-encoded wire bytes to the Rust binary.
  Send(data: BitArray)
  /// Port data received from the Rust binary (via selector).
  PortData(data: Dynamic)
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
  )
}

/// Notifications sent from bridge to runtime.
pub type RuntimeNotification {
  /// A decoded inbound message from the Rust binary.
  InboundEvent(InboundMessage)
  /// The Rust binary process exited.
  RendererExited(status: Int)
}

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
    let port = ffi.open_port_spawn(binary_path, options)

    let selector =
      process.new_selector()
      |> process.select(subject)
      |> process.select_other(classify_port_message)

    let state = BridgeState(port:, format:, runtime:, session:)

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
      ffi.port_command(state.port, data)
      actor.continue(state)
    }

    PortData(data:) -> {
      handle_port_data(state, data)
      actor.continue(state)
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

fn handle_port_data(state: BridgeState, raw: Dynamic) -> Nil {
  case dyn_decode.run(raw, dyn_decode.bit_array) {
    Ok(bytes) -> {
      case decode.decode_message(bytes, state.format) {
        Ok(msg) -> process.send(state.runtime, InboundEvent(msg))
        Error(err) -> {
          io.println(
            "toddy bridge: decode error: "
            <> protocol.decode_error_to_string(err),
          )
          Nil
        }
      }
    }
    Error(_) -> {
      io.println("toddy bridge: received non-binary port data")
      Nil
    }
  }
}

fn classify_port_message(msg: Dynamic) -> BridgeMessage {
  case ffi.extract_port_data(msg) {
    Ok(data) -> PortData(data:)
    Error(_) ->
      case ffi.extract_exit_status(msg) {
        Ok(status) -> PortExit(status:)
        Error(_) -> PortData(data: msg)
      }
  }
}
