//// Bridge actor: manages the Erlang Port to the Rust binary.
////
//// The bridge is a stable entity that outlives individual renderer
//// processes. When the renderer crashes, the bridge stays alive,
//// queues transient messages during the restart window, and reopens
//// the port after an exponential backoff delay.
////
//// ## Message classification during restart
////
//// Messages are classified as rebuildable or transient:
////
//// - **Rebuildable** (`Send`): settings, snapshots, patches,
////   subscriptions, window ops. Dropped when the port is down
////   because the runtime rebuilds them during resync.
//// - **Transient** (`SendTransient`): effects, widget ops, image ops,
////   widget commands, interact, advance_frame, stub registration.
////   Queued when the port is down or awaiting resync, then flushed
////   after the runtime signals resync is complete.
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

@target(erlang)
import gleam/bit_array
@target(erlang)
import gleam/dict
@target(erlang)
import gleam/dynamic.{type Dynamic}
@target(erlang)
import gleam/dynamic/decode as dyn_decode
@target(erlang)
import gleam/erlang/port.{type Port}
@target(erlang)
import gleam/erlang/process.{type Subject}
@target(erlang)
import gleam/float
@target(erlang)
import gleam/int
@target(erlang)
import gleam/list
@target(erlang)
import gleam/option.{type Option, None, Some}
@target(erlang)
import gleam/otp/actor
@target(erlang)
import gleam/result
@target(erlang)
import plushie/platform
@target(erlang)
import plushie/protocol
@target(erlang)
import plushie/protocol/decode.{type InboundMessage}
@target(erlang)
import plushie/renderer_env
@target(erlang)
import plushie/renderer_port
@target(erlang)
import plushie/telemetry

@target(erlang)
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

@target(erlang)
/// Messages the bridge actor handles.
pub type BridgeMessage {
  /// Send pre-encoded rebuildable wire bytes (settings, snapshot,
  /// patch, subscribe, window_op). Dropped when the port is down
  /// since the runtime rebuilds these during resync.
  Send(data: BitArray)
  /// Send pre-encoded transient wire bytes (effect, widget_op,
  /// image_op, widget command, interact, advance_frame, stub
  /// registration). Queued when the port is down or awaiting
  /// resync, flushed after ResyncComplete.
  SendTransient(data: BitArray)
  /// Port data received from the Rust binary (via selector).
  PortData(data: Dynamic)
  /// Line data received from the Rust binary in JSON mode (via selector).
  PortLineData(line_data: renderer_port.LineData)
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
  /// Runtime has finished resync (settings, snapshot, subscriptions,
  /// windows). The bridge flushes any queued transient messages.
  ResyncComplete
  /// Internal: bridge's own restart timer fired.
  RestartPort
  /// Graceful shutdown request.
  Shutdown
}

@target(erlang)
/// Transport mode for the bridge.
pub type Transport {
  /// Spawn the renderer binary as a child process.
  TransportSpawn
  /// Use the BEAM's own stdin/stdout.
  TransportStdio
  /// Use a custom iostream adapter process.
  TransportIoStream(adapter: Subject(IoStreamMessage))
}

@target(erlang)
/// Internal bridge state.
pub opaque type BridgeState {
  BridgeState(
    port: Option(Port),
    format: protocol.Format,
    runtime: Option(Subject(RuntimeNotification)),
    session: String,
    transport: Transport,
    /// Buffer for accumulating partial JSON lines (noeol chunks).
    json_buffer: BitArray,
    /// Events received before the runtime registered. Stored in
    /// reverse order and flushed on RegisterRuntime receipt.
    event_buffer: List(RuntimeNotification),
    /// True after port restart until the runtime sends ResyncComplete.
    awaiting_resync: Bool,
    /// Transient messages queued during restart/resync.
    queued_messages: List(BitArray),
    /// Port restart tracking.
    restart_count: Int,
    max_restarts: Int,
    restart_delay: Int,
    /// Needed to reopen the port on restart (Spawn transport only).
    binary_path: String,
    renderer_args: List(String),
    /// The bridge's own subject, needed for scheduling RestartPort.
    self: Option(Subject(BridgeMessage)),
  )
}

@target(erlang)
/// Notifications sent from bridge to runtime.
pub type RuntimeNotification {
  /// A decoded inbound message from the Rust binary.
  InboundEvent(InboundMessage)
  /// The Rust binary process exited with this status code.
  RendererExited(status: Int)
  /// The bridge successfully reopened the port after a crash.
  /// The runtime should resync state and then send ResyncComplete.
  RendererRestarted
}

// Maximum buffer size for partial JSON lines (64 MiB).
@target(erlang)
const max_json_buffer_size = 67_108_864

// Maximum backoff delay (5 seconds).
@target(erlang)
const max_backoff_ms = 5000

@target(erlang)
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

@target(erlang)
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

@target(erlang)
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

// -- Init helpers (port-opening) -----------------------------------------------

@target(erlang)
fn make_state(
  subject: Subject(BridgeMessage),
  port: Port,
  format: protocol.Format,
  runtime: Option(Subject(RuntimeNotification)),
  session: String,
  transport: Transport,
  binary_path: String,
  renderer_args: List(String),
) -> BridgeState {
  BridgeState(
    port: Some(port),
    format:,
    runtime:,
    session:,
    transport:,
    json_buffer: <<>>,
    event_buffer: [],
    awaiting_resync: False,
    queued_messages: [],
    restart_count: 0,
    max_restarts: 5,
    restart_delay: 100,
    binary_path:,
    renderer_args:,
    self: Some(subject),
  )
}

@target(erlang)
fn open_spawn_port(
  binary_path: String,
  format: protocol.Format,
  renderer_args: List(String),
) -> Port {
  let options = case format {
    protocol.Msgpack -> renderer_port.msgpack_port_options()
    protocol.Json -> renderer_port.json_port_options()
  }
  let format_args = case format {
    protocol.Json -> ["--json"]
    protocol.Msgpack -> []
  }
  let args = list.append(renderer_args, format_args)
  let env_entries = renderer_env.build(renderer_env.default_opts())
  let env = renderer_env.to_port_env(env_entries)
  renderer_port.open_port_spawn(binary_path, args, env, options)
}

@target(erlang)
fn spawn_selector(
  subject: Subject(BridgeMessage),
  format: protocol.Format,
) -> process.Selector(BridgeMessage) {
  process.new_selector()
  |> process.select(subject)
  |> process.select_other(classify_port_message(format, _))
}

@target(erlang)
fn init_spawn(
  subject: Subject(BridgeMessage),
  binary_path: String,
  format: protocol.Format,
  runtime: Subject(RuntimeNotification),
  session: String,
  renderer_args: List(String),
) {
  let port = open_spawn_port(binary_path, format, renderer_args)
  let selector = spawn_selector(subject, format)
  let state =
    make_state(
      subject,
      port,
      format,
      Some(runtime),
      session,
      TransportSpawn,
      binary_path,
      renderer_args,
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

@target(erlang)
fn init_stdio(
  subject: Subject(BridgeMessage),
  format: protocol.Format,
  runtime: Subject(RuntimeNotification),
  session: String,
) {
  let options = case format {
    protocol.Msgpack -> renderer_port.stdio_port_options_msgpack()
    protocol.Json -> renderer_port.stdio_port_options_json()
  }

  let port = renderer_port.open_fd_port(0, 1, options)
  let selector = spawn_selector(subject, format)
  let state =
    make_state(
      subject,
      port,
      format,
      Some(runtime),
      session,
      TransportStdio,
      "",
      [],
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

@target(erlang)
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
  let port = renderer_port.null_port()
  let state =
    make_state(
      subject,
      port,
      format,
      Some(runtime),
      session,
      TransportIoStream(adapter:),
      "",
      [],
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

// -- Deferred-runtime init variants (for supervised startup) -----------------
// These are identical to the regular init functions except they set
// runtime=None and event_buffer=[] since the runtime registers later.

@target(erlang)
fn init_spawn_deferred(
  subject: Subject(BridgeMessage),
  binary_path: String,
  format: protocol.Format,
  session: String,
  renderer_args: List(String),
) {
  let port = open_spawn_port(binary_path, format, renderer_args)
  let selector = spawn_selector(subject, format)
  let state =
    make_state(
      subject,
      port,
      format,
      None,
      session,
      TransportSpawn,
      binary_path,
      renderer_args,
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

@target(erlang)
fn init_stdio_deferred(
  subject: Subject(BridgeMessage),
  format: protocol.Format,
  session: String,
) {
  let options = case format {
    protocol.Msgpack -> renderer_port.stdio_port_options_msgpack()
    protocol.Json -> renderer_port.stdio_port_options_json()
  }

  let port = renderer_port.open_fd_port(0, 1, options)
  let selector = spawn_selector(subject, format)
  let state =
    make_state(subject, port, format, None, session, TransportStdio, "", [])

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

@target(erlang)
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

  let port = renderer_port.null_port()
  let state =
    make_state(
      subject,
      port,
      format,
      None,
      session,
      TransportIoStream(adapter:),
      "",
      [],
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

// -- Message handler ----------------------------------------------------------

@target(erlang)
fn handle_message(
  state: BridgeState,
  msg: BridgeMessage,
) -> actor.Next(BridgeState, BridgeMessage) {
  case msg {
    Send(data:) -> {
      // Rebuildable: send when port is ready, drop otherwise.
      case state.port {
        Some(_) -> {
          send_data(state, data)
          actor.continue(state)
        }
        None -> actor.continue(state)
      }
    }

    SendTransient(data:) -> {
      // Transient: send when port is ready AND not awaiting resync.
      // Queue when port is down or resync is in progress.
      case state.port, state.awaiting_resync {
        Some(_), False -> {
          send_data(state, data)
          actor.continue(state)
        }
        _, _ -> {
          let queued = list.append(state.queued_messages, [data])
          actor.continue(BridgeState(..state, queued_messages: queued))
        }
      }
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

      case exit_code {
        // Clean exit (status 0): stop the bridge.
        0 -> actor.stop()

        // Crash: attempt restart with exponential backoff.
        _ -> {
          case state.transport {
            TransportSpawn ->
              case state.restart_count < state.max_restarts {
                True -> {
                  let delay = calculate_backoff(state.restart_delay, state.restart_count)
                  platform.log_warning(
                    "plushie bridge: renderer crashed (status "
                    <> int.to_string(exit_code)
                    <> "), restarting in "
                    <> int.to_string(delay)
                    <> "ms (attempt "
                    <> int.to_string(state.restart_count + 1)
                    <> "/"
                    <> int.to_string(state.max_restarts)
                    <> ")",
                  )
                  case state.self {
                    Some(self) -> {
                      process.send_after(self, delay, RestartPort)
                      Nil
                    }
                    None -> Nil
                  }
                  actor.continue(
                    BridgeState(
                      ..state,
                      port: None,
                      awaiting_resync: True,
                      json_buffer: <<>>,
                    ),
                  )
                }
                False -> {
                  platform.log_error(
                    "plushie bridge: renderer crashed "
                    <> int.to_string(state.max_restarts)
                    <> " times, giving up",
                  )
                  actor.stop()
                }
              }

            // Non-spawn transports don't support restart.
            _ -> actor.stop()
          }
        }
      }
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

    ResyncComplete -> {
      let state = BridgeState(..state, awaiting_resync: False)
      let state = flush_queued_messages(state)
      actor.continue(state)
    }

    RestartPort -> {
      case state.transport {
        TransportSpawn -> {
          case
            platform.try_call(fn() {
              open_spawn_port(state.binary_path, state.format, state.renderer_args)
            })
          {
            Ok(new_port) -> {
              let new_count = state.restart_count + 1
              telemetry.execute(
                ["plushie", "bridge", "restart"],
                dict.from_list([#("count", dynamic.int(new_count))]),
                dict.new(),
              )
              platform.log_info(
                "plushie bridge: renderer restarted (attempt "
                <> int.to_string(new_count)
                <> ")",
              )
              notify_runtime(state, RendererRestarted)
              actor.continue(
                BridgeState(
                  ..state,
                  port: Some(new_port),
                  restart_count: new_count,
                  // awaiting_resync stays True until ResyncComplete
                ),
              )
            }
            Error(_) -> {
              platform.log_error(
                "plushie bridge: failed to reopen port, giving up",
              )
              actor.stop()
            }
          }
        }
        _ -> {
          // Non-spawn transports can't restart
          actor.stop()
        }
      }
    }

    Shutdown -> {
      case state.port {
        Some(port) ->
          case state.transport {
            TransportIoStream(_) -> Nil
            _ -> {
              renderer_port.port_close(port)
              Nil
            }
          }
        None -> Nil
      }
      actor.stop()
    }
  }
}

// -- Send helpers -------------------------------------------------------------

@target(erlang)
fn send_data(state: BridgeState, data: BitArray) -> Nil {
  let byte_size = bit_array.byte_size(data)

  case state.transport, state.port {
    TransportIoStream(adapter:), _ -> {
      process.send(adapter, IoStreamSend(data:))
      telemetry.execute(
        ["plushie", "bridge", "send"],
        dict.from_list([#("byte_size", dynamic.int(byte_size))]),
        dict.new(),
      )
      Nil
    }
    _, Some(port) -> {
      case
        platform.try_call(fn() { renderer_port.port_command(port, data) })
      {
        Ok(_) -> {
          telemetry.execute(
            ["plushie", "bridge", "send"],
            dict.from_list([#("byte_size", dynamic.int(byte_size))]),
            dict.new(),
          )
          Nil
        }
        Error(_) -> {
          platform.log_warning("plushie bridge: port closed during send")
          Nil
        }
      }
    }
    _, None -> Nil
  }
}

@target(erlang)
fn flush_queued_messages(state: BridgeState) -> BridgeState {
  case state.queued_messages {
    [] -> state
    _ -> do_flush_queued(state, state.queued_messages)
  }
}

@target(erlang)
fn do_flush_queued(state: BridgeState, queue: List(BitArray)) -> BridgeState {
  case queue {
    [] -> BridgeState(..state, queued_messages: [])
    [data, ..rest] -> {
      send_data(state, data)
      do_flush_queued(state, rest)
    }
  }
}

@target(erlang)
fn calculate_backoff(base: Int, attempt: Int) -> Int {
  let delay = float.truncate(int.to_float(base) *. pow2_float(attempt))
  case delay > max_backoff_ms {
    True -> max_backoff_ms
    False -> delay
  }
}

@target(erlang)
fn pow2_float(n: Int) -> Float {
  case n <= 0 {
    True -> 1.0
    False -> 2.0 *. pow2_float(n - 1)
  }
}

// -- Inbound message handling -------------------------------------------------

@target(erlang)
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
      platform.log_warning("plushie bridge: received non-binary port data")
      state
    }
  }
}

@target(erlang)
/// Handle line-buffered data from JSON mode ({line, N} port driver).
/// Accumulates noeol chunks in the buffer, flushes on eol.
fn handle_line_data(
  state: BridgeState,
  line_data: renderer_port.LineData,
) -> BridgeState {
  case line_data {
    renderer_port.Eol(data:) -> {
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
    renderer_port.Noeol(data:) -> {
      let new_buffer = bit_array.append(state.json_buffer, data)
      case bit_array.byte_size(new_buffer) > max_json_buffer_size {
        True -> {
          platform.log_warning(
            "plushie bridge: JSON buffer exceeded 64 MiB, dropping message",
          )
          BridgeState(..state, json_buffer: <<>>)
        }
        False -> BridgeState(..state, json_buffer: new_buffer)
      }
    }
  }
}

@target(erlang)
/// Send a notification to the runtime if registered, otherwise buffer it.
fn notify_runtime(state: BridgeState, notification: RuntimeNotification) -> Nil {
  case state.runtime {
    Some(runtime) -> process.send(runtime, notification)
    None -> Nil
  }
}

@target(erlang)
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

@target(erlang)
/// Decode a complete wire message and forward to the runtime.
fn dispatch_decoded(state: BridgeState, bytes: BitArray) -> BridgeState {
  case decode.decode_message(bytes, state.format) {
    Ok(msg) -> buffer_or_send(state, InboundEvent(msg))
    Error(err) -> {
      platform.log_warning(
        "plushie bridge: decode error: "
        <> protocol.decode_error_to_string(err),
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

@target(erlang)
/// Classify raw Erlang port messages into BridgeMessage variants.
/// In JSON mode, the {line, N} driver delivers {eol, Data} and
/// {noeol, Data} tuples instead of plain binaries.
fn classify_port_message(
  format: protocol.Format,
  msg: Dynamic,
) -> BridgeMessage {
  case format {
    protocol.Json ->
      case renderer_port.extract_line_data(msg) {
        Ok(line_data) -> PortLineData(line_data:)
        Error(_) ->
          case renderer_port.extract_exit_status(msg) {
            Ok(status) -> PortExit(status:)
            Error(_) ->
              case renderer_port.extract_eof(msg) {
                Ok(_) -> IoStreamClosed
                Error(_) -> PortData(data: msg)
              }
          }
      }
    protocol.Msgpack ->
      case renderer_port.extract_port_data(msg) {
        Ok(data) -> PortData(data:)
        Error(_) ->
          case renderer_port.extract_exit_status(msg) {
            Ok(status) -> PortExit(status:)
            Error(_) ->
              case renderer_port.extract_eof(msg) {
                Ok(_) -> IoStreamClosed
                Error(_) -> PortData(data: msg)
              }
          }
      }
  }
}
