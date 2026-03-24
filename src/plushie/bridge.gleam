//// Bridge actor: manages the Erlang Port to the Rust binary.
////
//// The bridge is a thin pipe -- it receives pre-encoded wire bytes
//// from the runtime and writes them to the port. Inbound port data
//// is decoded and forwarded to the runtime as events.
////
//// ## Transport modes
////
//// - `Spawn` (default): spawns the renderer binary as a child process
////   using an Erlang Port.
//// - `Stdio`: reads/writes the BEAM's own stdin/stdout. Used when the
////   renderer spawns the Gleam process (e.g. `plushie-renderer --exec`).
//// - `Iostream`: sends and receives protocol messages via an external
////   process (the iostream adapter). Used for custom transports like
////   SSH channels, TCP sockets, or WebSockets.
////
//// ## Wire framing
////
//// - MessagePack: 4-byte big-endian length prefix (Erlang {packet, 4})
//// - JSONL: newline-delimited (Erlang {line, 65536})

import gleam/bit_array
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dyn_decode
import gleam/erlang/port.{type Port}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result
import plushie/ffi
import plushie/protocol
import plushie/protocol/decode.{type InboundMessage}
import plushie/renderer_env
import plushie/telemetry

/// Messages sent to an iostream adapter process.
/// The adapter must handle these messages to integrate with
/// a custom transport (TCP, WebSocket, SSH, etc.).
pub type IoStreamMessage {
  /// The bridge is registering itself. The adapter should send
  /// IoStreamData messages to the bridge subject.
  IoStreamBridge(bridge: Subject(BridgeMessage))
  /// The bridge wants to send data over the transport.
  IoStreamSend(data: BitArray)
}

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
  /// Data received from an iostream adapter.
  IoStreamData(data: BitArray)
  /// The iostream adapter closed the transport.
  IoStreamClosed
  /// Register the runtime's notification subject. Sent by the runtime
  /// after it starts under the supervisor. Any events received before
  /// this message are buffered and flushed on receipt.
  RegisterRuntime(Subject(RuntimeNotification))
  /// Graceful shutdown request.
  Shutdown
}

/// Transport mode for the bridge.
pub type Transport {
  /// Spawn the renderer binary as a child process.
  TransportSpawn
  /// Use the BEAM's own stdin/stdout.
  TransportStdio
  /// Use a custom iostream adapter process.
  TransportIoStream(adapter: Subject(IoStreamMessage))
}

/// Internal bridge state.
pub opaque type BridgeState {
  BridgeState(
    port: Port,
    format: protocol.Format,
    runtime: option.Option(Subject(RuntimeNotification)),
    session: String,
    transport: Transport,
    /// Buffer for accumulating partial JSON lines (noeol chunks).
    json_buffer: BitArray,
    /// Events received before the runtime registered. Stored in
    /// reverse order and flushed on RegisterRuntime receipt.
    event_buffer: List(RuntimeNotification),
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

/// Start the bridge actor with spawn transport (default).
///
/// Opens a port to the plushie binary and begins forwarding messages.
/// Inbound wire data is decoded and sent as RuntimeNotification
/// values to the provided runtime subject.
pub fn start(
  binary_path: String,
  format: protocol.Format,
  runtime: Subject(RuntimeNotification),
  session: String,
  renderer_args: List(String),
) -> Result(Subject(BridgeMessage), actor.StartError) {
  start_with_transport(
    binary_path,
    format,
    runtime,
    session,
    renderer_args,
    TransportSpawn,
  )
}

/// Start the bridge actor with an explicit transport mode.
pub fn start_with_transport(
  binary_path: String,
  format: protocol.Format,
  runtime: Subject(RuntimeNotification),
  session: String,
  renderer_args: List(String),
  transport: Transport,
) -> Result(Subject(BridgeMessage), actor.StartError) {
  actor.new_with_initialiser(5000, fn(subject) {
    case transport {
      TransportSpawn ->
        init_spawn(
          subject,
          binary_path,
          format,
          runtime,
          session,
          renderer_args,
        )
      TransportStdio -> init_stdio(subject, format, runtime, session)
      TransportIoStream(adapter:) ->
        init_iostream(subject, adapter, format, runtime, session)
    }
  })
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

/// Start the bridge under a supervisor with a registered name.
///
/// The runtime subject is not available yet -- the runtime will send
/// a `RegisterRuntime` message after it starts. Events received before
/// registration are buffered and flushed automatically.
pub fn start_supervised(
  name: process.Name(BridgeMessage),
  binary_path: String,
  format: protocol.Format,
  session: String,
  renderer_args: List(String),
  transport: Transport,
) -> Result(actor.Started(Subject(BridgeMessage)), actor.StartError) {
  actor.new_with_initialiser(5000, fn(subject) {
    case transport {
      TransportSpawn ->
        init_spawn_deferred(
          subject,
          binary_path,
          format,
          session,
          renderer_args,
        )
      TransportStdio -> init_stdio_deferred(subject, format, session)
      TransportIoStream(adapter:) ->
        init_iostream_deferred(subject, adapter, format, session)
    }
  })
  |> actor.on_message(handle_message)
  |> actor.named(name)
  |> actor.start
}

fn init_spawn(
  subject: Subject(BridgeMessage),
  binary_path: String,
  format: protocol.Format,
  runtime: Subject(RuntimeNotification),
  session: String,
  renderer_args: List(String),
) {
  let options = case format {
    protocol.Msgpack -> ffi.msgpack_port_options()
    protocol.Json -> ffi.json_port_options()
  }

  let format_args = case format {
    protocol.Json -> ["--json"]
    protocol.Msgpack -> []
  }
  let args = list.append(renderer_args, format_args)

  let env_entries = renderer_env.build(renderer_env.default_opts())
  let env = renderer_env.to_port_env(env_entries)

  let port = ffi.open_port_spawn(binary_path, args, env, options)

  let selector =
    process.new_selector()
    |> process.select(subject)
    |> process.select_other(classify_port_message(format, _))

  let state =
    BridgeState(
      port:,
      format:,
      runtime: Some(runtime),
      session:,
      transport: TransportSpawn,
      json_buffer: <<>>,
      event_buffer: [],
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

fn init_stdio(
  subject: Subject(BridgeMessage),
  format: protocol.Format,
  runtime: Subject(RuntimeNotification),
  session: String,
) {
  let options = case format {
    protocol.Msgpack -> ffi.stdio_port_options_msgpack()
    protocol.Json -> ffi.stdio_port_options_json()
  }

  let port = ffi.open_fd_port(0, 1, options)

  let selector =
    process.new_selector()
    |> process.select(subject)
    |> process.select_other(classify_port_message(format, _))

  let state =
    BridgeState(
      port:,
      format:,
      runtime: Some(runtime),
      session:,
      transport: TransportStdio,
      json_buffer: <<>>,
      event_buffer: [],
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

fn init_iostream(
  subject: Subject(BridgeMessage),
  adapter: Subject(IoStreamMessage),
  format: protocol.Format,
  runtime: Subject(RuntimeNotification),
  session: String,
) {
  // Register ourselves with the iostream adapter
  process.send(adapter, IoStreamBridge(bridge: subject))

  let selector =
    process.new_selector()
    |> process.select(subject)

  // iostream transport doesn't use a real port; we use a dummy
  // value that will never be referenced for I/O.
  let port = ffi.null_port()

  let state =
    BridgeState(
      port:,
      format:,
      runtime: Some(runtime),
      session:,
      transport: TransportIoStream(adapter:),
      json_buffer: <<>>,
      event_buffer: [],
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

// -- Deferred-runtime init variants (for supervised startup) -----------------
// These are identical to the regular init functions except they set
// runtime=None and event_buffer=[] since the runtime registers later.

fn init_spawn_deferred(
  subject: Subject(BridgeMessage),
  binary_path: String,
  format: protocol.Format,
  session: String,
  renderer_args: List(String),
) {
  let options = case format {
    protocol.Msgpack -> ffi.msgpack_port_options()
    protocol.Json -> ffi.json_port_options()
  }

  let format_args = case format {
    protocol.Json -> ["--json"]
    protocol.Msgpack -> []
  }
  let args = list.append(renderer_args, format_args)

  let env_entries = renderer_env.build(renderer_env.default_opts())
  let env = renderer_env.to_port_env(env_entries)

  let port = ffi.open_port_spawn(binary_path, args, env, options)

  let selector =
    process.new_selector()
    |> process.select(subject)
    |> process.select_other(classify_port_message(format, _))

  let state =
    BridgeState(
      port:,
      format:,
      runtime: None,
      session:,
      transport: TransportSpawn,
      json_buffer: <<>>,
      event_buffer: [],
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

fn init_stdio_deferred(
  subject: Subject(BridgeMessage),
  format: protocol.Format,
  session: String,
) {
  let options = case format {
    protocol.Msgpack -> ffi.stdio_port_options_msgpack()
    protocol.Json -> ffi.stdio_port_options_json()
  }

  let port = ffi.open_fd_port(0, 1, options)

  let selector =
    process.new_selector()
    |> process.select(subject)
    |> process.select_other(classify_port_message(format, _))

  let state =
    BridgeState(
      port:,
      format:,
      runtime: None,
      session:,
      transport: TransportStdio,
      json_buffer: <<>>,
      event_buffer: [],
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

fn init_iostream_deferred(
  subject: Subject(BridgeMessage),
  adapter: Subject(IoStreamMessage),
  format: protocol.Format,
  session: String,
) {
  process.send(adapter, IoStreamBridge(bridge: subject))

  let selector =
    process.new_selector()
    |> process.select(subject)

  let port = ffi.null_port()

  let state =
    BridgeState(
      port:,
      format:,
      runtime: None,
      session:,
      transport: TransportIoStream(adapter:),
      json_buffer: <<>>,
      event_buffer: [],
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

fn handle_message(
  state: BridgeState,
  msg: BridgeMessage,
) -> actor.Next(BridgeState, BridgeMessage) {
  case msg {
    Send(data:) -> {
      send_data(state, data)
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
      notify_runtime(state, RendererExited(status: exit_code))
      actor.stop()
    }

    IoStreamData(data:) -> {
      let byte_size = bit_array.byte_size(data)
      telemetry.execute(
        ["plushie", "bridge", "receive"],
        dict.from_list([#("byte_size", dynamic.int(byte_size))]),
        dict.new(),
      )
      let new_state = dispatch_decoded(state, data)
      actor.continue(new_state)
    }

    IoStreamClosed -> {
      // Treat transport close as clean exit (status 0)
      notify_runtime(state, RendererExited(status: 0))
      actor.stop()
    }

    RegisterRuntime(runtime_subject) -> {
      // Flush any buffered events to the newly registered runtime
      let buffered = list.reverse(state.event_buffer)
      list.each(buffered, fn(notification) {
        process.send(runtime_subject, notification)
      })
      actor.continue(
        BridgeState(..state, runtime: Some(runtime_subject), event_buffer: []),
      )
    }

    Shutdown -> {
      case state.transport {
        TransportIoStream(_) -> Nil
        _ -> {
          ffi.port_close(state.port)
          Nil
        }
      }
      actor.stop()
    }
  }
}

fn send_data(state: BridgeState, data: BitArray) -> Nil {
  let byte_size = bit_array.byte_size(data)

  case state.transport {
    TransportIoStream(adapter:) -> {
      process.send(adapter, IoStreamSend(data:))
      telemetry.execute(
        ["plushie", "bridge", "send"],
        dict.from_list([#("byte_size", dynamic.int(byte_size))]),
        dict.new(),
      )
      Nil
    }
    _ -> {
      case ffi.try_call(fn() { ffi.port_command(state.port, data) }) {
        Ok(_) -> {
          telemetry.execute(
            ["plushie", "bridge", "send"],
            dict.from_list([#("byte_size", dynamic.int(byte_size))]),
            dict.new(),
          )
          Nil
        }
        Error(_) -> {
          ffi.log_warning("plushie bridge: port closed during send")
          Nil
        }
      }
    }
  }
}

fn handle_port_data(state: BridgeState, raw: Dynamic) -> BridgeState {
  case dyn_decode.run(raw, dyn_decode.bit_array) {
    Ok(bytes) -> {
      let byte_size = bit_array.byte_size(bytes)
      telemetry.execute(
        ["plushie", "bridge", "receive"],
        dict.from_list([#("byte_size", dynamic.int(byte_size))]),
        dict.new(),
      )
      dispatch_decoded(state, bytes)
    }
    Error(_) -> {
      ffi.log_warning("plushie bridge: received non-binary port data")
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
      let byte_size = bit_array.byte_size(line)
      telemetry.execute(
        ["plushie", "bridge", "receive"],
        dict.from_list([#("byte_size", dynamic.int(byte_size))]),
        dict.new(),
      )
      let new_state = BridgeState(..state, json_buffer: <<>>)
      dispatch_decoded(new_state, line)
    }
    ffi.Noeol(data:) -> {
      let new_buffer = bit_array.append(state.json_buffer, data)
      case bit_array.byte_size(new_buffer) > max_json_buffer_size {
        True -> {
          ffi.log_warning(
            "plushie bridge: JSON buffer exceeded 64 MiB, dropping message",
          )
          BridgeState(..state, json_buffer: <<>>)
        }
        False -> BridgeState(..state, json_buffer: new_buffer)
      }
    }
  }
}

/// Send a notification to the runtime if registered, otherwise buffer it.
fn notify_runtime(state: BridgeState, notification: RuntimeNotification) -> Nil {
  case state.runtime {
    Some(runtime) -> process.send(runtime, notification)
    None -> Nil
  }
}

/// Buffer a notification when the runtime is not yet registered.
fn buffer_or_send(
  state: BridgeState,
  notification: RuntimeNotification,
) -> BridgeState {
  case state.runtime {
    Some(runtime) -> {
      process.send(runtime, notification)
      state
    }
    None ->
      BridgeState(..state, event_buffer: [notification, ..state.event_buffer])
  }
}

/// Decode a complete wire message and forward to the runtime.
fn dispatch_decoded(state: BridgeState, bytes: BitArray) -> BridgeState {
  case decode.decode_message(bytes, state.format) {
    Ok(msg) -> buffer_or_send(state, InboundEvent(msg))
    Error(err) -> {
      ffi.log_warning(
        "plushie bridge: decode error: " <> protocol.decode_error_to_string(err),
      )
      telemetry.execute(
        ["plushie", "bridge", "decode_error"],
        dict.new(),
        dict.from_list([
          #("reason", dynamic.string(protocol.decode_error_to_string(err))),
        ]),
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
            Error(_) ->
              case ffi.extract_eof(msg) {
                Ok(_) -> IoStreamClosed
                Error(_) -> PortData(data: msg)
              }
          }
      }
    protocol.Msgpack ->
      case ffi.extract_port_data(msg) {
        Ok(data) -> PortData(data:)
        Error(_) ->
          case ffi.extract_exit_status(msg) {
            Ok(status) -> PortExit(status:)
            Error(_) ->
              case ffi.extract_eof(msg) {
                Ok(_) -> IoStreamClosed
                Error(_) -> PortData(data: msg)
              }
          }
      }
  }
}
