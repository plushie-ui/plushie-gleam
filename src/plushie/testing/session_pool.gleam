//// Shared renderer process for concurrent test sessions.
////
//// Owns a single `plushie-renderer --headless --max-sessions N` (or `--mock`)
//// Port and multiplexes messages from multiple test sessions over it.
//// Each session gets a unique session ID; responses are demuxed by the
//// `session` field and forwarded to the owning process.
////
//// ## Usage
////
//// Start the pool once (typically in test setup):
////
////     let assert Ok(pool) = session_pool.start(
////       session_pool.PoolConfig(..session_pool.default_config(),
////         renderer_path: Some("/path/to/plushie"),
////       ),
////     )
////
//// Then use the pooled backend, passing the pool:
////
////     let backend = pooled.backend(pool)

@target(erlang)
import gleam/dict.{type Dict}
@target(erlang)
import gleam/dynamic.{type Dynamic}
@target(erlang)
import gleam/dynamic/decode as dyn_decode
@target(erlang)
import gleam/erlang/port.{type Port}
@target(erlang)
import gleam/erlang/process.{type Pid, type Subject}
@target(erlang)
import gleam/int
@target(erlang)
import gleam/io
@target(erlang)
import gleam/list
@target(erlang)
import gleam/option.{type Option, None, Some}
@target(erlang)
import gleam/otp/actor
@target(erlang)
import gleam/result
@target(erlang)
import plushie/node
@target(erlang)
import plushie/protocol
@target(erlang)
import plushie/protocol/encode as proto_encode
@target(erlang)
import plushie/renderer_env
@target(erlang)
import plushie/renderer_port

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

@target(erlang)
/// Pool mode: mock or headless.
pub type PoolMode {
  Mock
  Headless
}

@target(erlang)
/// Configuration for starting a session pool.
pub type PoolConfig {
  PoolConfig(
    /// Pool mode (mock or headless). Default: Mock.
    mode: PoolMode,
    /// Wire format. Default: Msgpack.
    format: protocol.Format,
    /// Maximum concurrent sessions. Default: 8.
    max_sessions: Int,
    /// Path to the plushie binary. None = auto-resolve.
    renderer_path: Option(String),
  )
}

@target(erlang)
/// Default pool configuration.
pub fn default_config() -> PoolConfig {
  PoolConfig(
    mode: Mock,
    format: protocol.Msgpack,
    max_sessions: 8,
    renderer_path: None,
  )
}

@target(erlang)
/// Messages the pool actor handles.
pub opaque type PoolMessage {
  /// Register a new session. Replies with session ID.
  Register(reply: Subject(RegisterReply), caller_pid: Pid)
  /// Unregister a session (send reset, wait for response).
  Unregister(session_id: String, reply: Subject(UnregisterReply))
  /// Send a message and wait for a correlated response.
  SendSync(
    session_id: String,
    msg: Dict(String, node.PropValue),
    response_type: String,
    reply: Subject(SendReply),
  )
  /// Send a message without waiting for a response.
  SendAsync(session_id: String, msg: Dict(String, node.PropValue))
  /// Send an interact (non-blocking, steps/response forwarded to owner).
  SendInteract(
    session_id: String,
    msg: Dict(String, node.PropValue),
    reply: Subject(String),
  )
  /// Port data from the renderer.
  PortData(data: Dynamic)
  /// Port line data (JSON mode).
  PortLineData(line_data: renderer_port.LineData)
  /// Port exited.
  PortExit(status: Dynamic)
  /// Session owner process died.
  OwnerDown(session_id: String)
}

@target(erlang)
/// Reply for register calls.
pub type RegisterReply {
  Registered(session_id: String)
  PoolFull(max: Int)
  AlreadyRegistered(session_id: String)
}

@target(erlang)
/// Reply for unregister calls.
pub type UnregisterReply {
  Unregistered
  UnregisterError(String)
}

@target(erlang)
/// Reply for send-sync calls.
pub type SendReply {
  SendOk(Dynamic)
  SendError(String)
}

@target(erlang)
/// Pool event forwarded to session owners.
pub type PoolEvent {
  PoolEventInteractStep(session_id: String, data: Dynamic)
  PoolEventInteractResponse(session_id: String, data: Dynamic)
  PoolEventGeneric(session_id: String, data: Dynamic)
}

@target(erlang)
/// Convenience alias for the pool actor's Subject.
pub type PoolSubject =
  Subject(PoolMessage)

// ---------------------------------------------------------------------------
// Pool state
// ---------------------------------------------------------------------------

@target(erlang)
type SessionEntry {
  SessionEntry(owner: Pid, monitor_ref: Dynamic)
}

@target(erlang)
type PendingValue {
  PendingValue(
    response_type: String,
    on_reply: fn(Dynamic) -> Nil,
    on_error: fn(String) -> Nil,
  )
}

@target(erlang)
type PoolState {
  PoolState(
    port: Port,
    format: protocol.Format,
    max_sessions: Int,
    sessions: Dict(String, SessionEntry),
    /// Reverse lookup: owner pid -> session_id for duplicate detection.
    owners: Dict(String, String),
    pending: Dict(String, PendingValue),
    pending_close: Dict(String, Bool),
    next_id: Int,
    next_session: Int,
  )
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

@target(erlang)
/// Start a session pool.
pub fn start(config: PoolConfig) -> Result(PoolSubject, actor.StartError) {
  actor.new_with_initialiser(10_000, fn(subject) { init_pool(subject, config) })
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

@target(erlang)
/// Register a new session. Returns the session ID.
pub fn register(pool: PoolSubject) -> String {
  let caller_pid = get_caller_pid()
  case process.call(pool, 10_000, fn(reply) { Register(reply:, caller_pid:) }) {
    Registered(session_id:) -> session_id
    AlreadyRegistered(session_id:) -> session_id
    PoolFull(max:) ->
      panic as {
        "session pool is full ("
        <> int.to_string(max)
        <> " sessions). Increase max_sessions or check for leaked sessions."
      }
  }
}

@target(erlang)
/// Unregister a session.
pub fn unregister(pool: PoolSubject, session_id: String) -> Nil {
  case
    process.call(pool, 10_000, fn(reply) { Unregister(session_id:, reply:) })
  {
    Unregistered -> Nil
    UnregisterError(_) -> Nil
  }
}

@target(erlang)
/// Send a message to the renderer for the given session, waiting
/// for a correlated response.
pub fn send_message(
  pool: PoolSubject,
  session_id: String,
  msg: Dict(String, node.PropValue),
  response_type: String,
) -> Result(Dynamic, String) {
  case
    process.call(pool, 30_000, fn(reply) {
      SendSync(session_id:, msg:, response_type:, reply:)
    })
  {
    SendOk(data) -> Ok(data)
    SendError(reason) -> Error(reason)
  }
}

@target(erlang)
/// Send a fire-and-forget message to the renderer.
pub fn send_async(
  pool: PoolSubject,
  session_id: String,
  msg: Dict(String, node.PropValue),
) -> Nil {
  process.send(pool, SendAsync(session_id:, msg:))
}

@target(erlang)
/// Send an interact message. Returns the request ID.
/// Intermediate steps and the final response are forwarded
/// to the session owner as PoolEvent messages.
pub fn send_interact(
  pool: PoolSubject,
  session_id: String,
  msg: Dict(String, node.PropValue),
) -> String {
  process.call(pool, 10_000, fn(reply) {
    SendInteract(session_id:, msg:, reply:)
  })
}

// ---------------------------------------------------------------------------
// Internal: init
// ---------------------------------------------------------------------------

@target(erlang)
fn init_pool(subject: PoolSubject, config: PoolConfig) {
  let renderer_path = case config.renderer_path {
    Some(p) -> p
    None ->
      case plushie_binary_find() {
        Ok(p) -> p
        Error(_) -> panic as binary.not_found_message()
      }
  }

  let mode_flag = case config.mode {
    Headless -> "--headless"
    Mock -> "--mock"
  }

  let args = [mode_flag, "--max-sessions", int.to_string(config.max_sessions)]
  let args = case config.format {
    protocol.Json -> list.append(args, ["--json"])
    protocol.Msgpack -> args
  }

  let options = case config.format {
    protocol.Msgpack -> renderer_port.msgpack_port_options()
    protocol.Json -> renderer_port.json_port_options()
  }

  let env_entries = renderer_env.build(renderer_env.default_opts())
  let env = renderer_env.to_port_env(env_entries)

  let port = renderer_port.open_port_spawn(renderer_path, args, env, options)

  // Send initial settings to trigger the hello handshake
  let settings_msg =
    dict.from_list([
      #("type", node.StringVal("settings")),
      #("session", node.StringVal("")),
      #(
        "settings",
        node.DictVal(
          dict.from_list([
            #("protocol_version", node.IntVal(protocol.protocol_version)),
            #("validate_props", node.BoolVal(True)),
          ]),
        ),
      ),
    ])
  send_to_port(port, config.format, settings_msg)

  let selector =
    process.new_selector()
    |> process.select(subject)
    |> process.select_other(classify_port_message(config.format, _))

  let state =
    PoolState(
      port:,
      format: config.format,
      max_sessions: config.max_sessions,
      sessions: dict.new(),
      owners: dict.new(),
      pending: dict.new(),
      pending_close: dict.new(),
      next_id: 1,
      next_session: 1,
    )

  actor.initialised(state)
  |> actor.selecting(selector)
  |> actor.returning(subject)
  |> Ok
}

// ---------------------------------------------------------------------------
// Internal: message handler
// ---------------------------------------------------------------------------

@target(erlang)
fn handle_message(
  state: PoolState,
  msg: PoolMessage,
) -> actor.Next(PoolState, PoolMessage) {
  case msg {
    Register(reply:, caller_pid:) -> handle_register(state, reply, caller_pid)
    Unregister(session_id:, reply:) ->
      handle_unregister(state, session_id, reply)
    SendSync(session_id:, msg:, response_type:, reply:) ->
      handle_send_sync(state, session_id, msg, response_type, reply)
    SendAsync(session_id:, msg:) -> handle_send_async(state, session_id, msg)
    SendInteract(session_id:, msg:, reply:) ->
      handle_send_interact(state, session_id, msg, reply)
    PortData(data:) -> handle_port_data(state, data)
    PortLineData(line_data:) -> handle_line_data(state, line_data)
    PortExit(status:) -> handle_port_exit(state, status)
    OwnerDown(session_id:) -> handle_owner_down(state, session_id)
  }
}

@target(erlang)
fn handle_register(
  state: PoolState,
  reply: Subject(RegisterReply),
  caller_pid: Pid,
) -> actor.Next(PoolState, PoolMessage) {
  let pid_key = pid_to_string(caller_pid)

  // Duplicate registration check: same process already owns a session
  case dict.get(state.owners, pid_key) {
    Ok(existing_session_id) -> {
      process.send(reply, AlreadyRegistered(session_id: existing_session_id))
      actor.continue(state)
    }
    Error(_) ->
      case dict.size(state.sessions) >= state.max_sessions {
        True -> {
          process.send(reply, PoolFull(max: state.max_sessions))
          actor.continue(state)
        }
        False -> {
          let session_id = "pool_" <> int.to_string(state.next_session)
          let monitor_ref = monitor_process(caller_pid)
          let entry = SessionEntry(owner: caller_pid, monitor_ref:)
          let sessions = dict.insert(state.sessions, session_id, entry)
          let owners = dict.insert(state.owners, pid_key, session_id)
          process.send(reply, Registered(session_id:))
          actor.continue(
            PoolState(
              ..state,
              sessions:,
              owners:,
              next_session: state.next_session + 1,
            ),
          )
        }
      }
  }
}

@target(erlang)
fn handle_unregister(
  state: PoolState,
  session_id: String,
  reply: Subject(UnregisterReply),
) -> actor.Next(PoolState, PoolMessage) {
  // Demonitor the session owner and clean up owner tracking
  let owners = case dict.get(state.sessions, session_id) {
    Ok(entry) -> {
      demonitor(entry.monitor_ref)
      dict.delete(state.owners, pid_to_string(entry.owner))
    }
    Error(_) -> state.owners
  }

  // Send reset to free renderer resources
  let req_id = "unreg_" <> int.to_string(state.next_id)
  let msg =
    dict.from_list([
      #("type", node.StringVal("reset")),
      #("session", node.StringVal(session_id)),
      #("id", node.StringVal(req_id)),
    ])
  send_to_port(state.port, state.format, msg)

  let pending_key = session_id <> ":" <> req_id
  let pending_value =
    PendingValue(
      response_type: "reset_response",
      on_reply: fn(_raw) { process.send(reply, Unregistered) },
      on_error: fn(_reason) {
        process.send(reply, UnregisterError("reset failed"))
      },
    )
  let pending = dict.insert(state.pending, pending_key, pending_value)
  let sessions = dict.delete(state.sessions, session_id)
  let pending_close = dict.insert(state.pending_close, session_id, True)

  actor.continue(
    PoolState(
      ..state,
      sessions:,
      owners:,
      pending:,
      pending_close:,
      next_id: state.next_id + 1,
    ),
  )
}

@target(erlang)
fn handle_send_sync(
  state: PoolState,
  session_id: String,
  msg: Dict(String, node.PropValue),
  response_type: String,
  reply: Subject(SendReply),
) -> actor.Next(PoolState, PoolMessage) {
  let req_id = "req_" <> int.to_string(state.next_id)
  let msg =
    msg
    |> dict.insert("session", node.StringVal(session_id))
    |> dict.insert("id", node.StringVal(req_id))
  send_to_port(state.port, state.format, msg)

  let pending_key = session_id <> ":" <> req_id
  let pending_value =
    PendingValue(
      response_type:,
      on_reply: fn(raw) { process.send(reply, SendOk(raw)) },
      on_error: fn(reason) { process.send(reply, SendError(reason)) },
    )
  let pending = dict.insert(state.pending, pending_key, pending_value)

  actor.continue(PoolState(..state, pending:, next_id: state.next_id + 1))
}

@target(erlang)
fn handle_send_async(
  state: PoolState,
  session_id: String,
  msg: Dict(String, node.PropValue),
) -> actor.Next(PoolState, PoolMessage) {
  let msg = dict.insert(msg, "session", node.StringVal(session_id))
  send_to_port(state.port, state.format, msg)
  actor.continue(state)
}

@target(erlang)
fn handle_send_interact(
  state: PoolState,
  session_id: String,
  msg: Dict(String, node.PropValue),
  reply: Subject(String),
) -> actor.Next(PoolState, PoolMessage) {
  let req_id = "req_" <> int.to_string(state.next_id)
  let msg =
    msg
    |> dict.insert("session", node.StringVal(session_id))
    |> dict.insert("id", node.StringVal(req_id))
  send_to_port(state.port, state.format, msg)

  // Don't add to pending -- steps and response are forwarded to owner
  process.send(reply, req_id)
  actor.continue(PoolState(..state, next_id: state.next_id + 1))
}

@target(erlang)
fn handle_owner_down(
  state: PoolState,
  session_id: String,
) -> actor.Next(PoolState, PoolMessage) {
  // Clean up owner tracking
  let owners = case dict.get(state.sessions, session_id) {
    Ok(entry) -> dict.delete(state.owners, pid_to_string(entry.owner))
    Error(_) -> state.owners
  }
  let sessions = dict.delete(state.sessions, session_id)

  // Fail any pending requests for this dead session
  let pending =
    dict.fold(state.pending, state.pending, fn(acc, key, pv) {
      case starts_with_session(key, session_id) {
        True -> {
          pv.on_error("session owner died")
          dict.delete(acc, key)
        }
        False -> acc
      }
    })

  actor.continue(PoolState(..state, sessions:, owners:, pending:))
}

// ---------------------------------------------------------------------------
// Internal: port data handling
// ---------------------------------------------------------------------------

@target(erlang)
fn handle_port_data(
  state: PoolState,
  raw: Dynamic,
) -> actor.Next(PoolState, PoolMessage) {
  case dyn_decode.run(raw, dyn_decode.bit_array) {
    Ok(bytes) -> {
      let new_state = dispatch_wire(state, bytes)
      actor.continue(new_state)
    }
    Error(_) -> actor.continue(state)
  }
}

@target(erlang)
fn handle_line_data(
  state: PoolState,
  line_data: renderer_port.LineData,
) -> actor.Next(PoolState, PoolMessage) {
  case line_data {
    renderer_port.Eol(data:) -> {
      let new_state = dispatch_wire(state, data)
      actor.continue(new_state)
    }
    renderer_port.Noeol(_data) -> actor.continue(state)
  }
}

@target(erlang)
fn handle_port_exit(
  state: PoolState,
  status: Dynamic,
) -> actor.Next(PoolState, PoolMessage) {
  let exit_code = case dyn_decode.run(status, dyn_decode.int) {
    Ok(code) -> code
    Error(_) -> 1
  }
  io.println(
    "session_pool: renderer exited with status " <> int.to_string(exit_code),
  )

  // Reply to all pending callers with an error
  dict.each(state.pending, fn(_key, pv) { pv.on_error("renderer exited") })

  actor.stop()
}

// ---------------------------------------------------------------------------
// Internal: wire dispatch
// ---------------------------------------------------------------------------

@target(erlang)
fn dispatch_wire(state: PoolState, bytes: BitArray) -> PoolState {
  case deserialize_wire(bytes, state.format) {
    Ok(raw) -> dispatch_raw(state, raw)
    Error(_) -> state
  }
}

@target(erlang)
fn dispatch_raw(state: PoolState, raw: Dynamic) -> PoolState {
  let msg_type = dyn_string_field(raw, "type", "")
  let session_id = dyn_string_field(raw, "session", "")
  let req_id = dyn_string_field(raw, "id", "")

  case msg_type {
    "hello" -> state

    // Session closed: absorb if we're tracking teardown
    "event" -> {
      let family = dyn_string_field(raw, "family", "")
      case family {
        "session_closed" ->
          case dict.get(state.pending_close, session_id) {
            Ok(_) ->
              PoolState(
                ..state,
                pending_close: dict.delete(state.pending_close, session_id),
              )
            Error(_) -> forward_to_session(state, session_id, raw)
          }
        _ -> forward_to_session(state, session_id, raw)
      }
    }

    // Interact step: forward to session owner
    "interact_step" -> forward_to_session(state, session_id, raw)

    // Interact response: forward to session owner
    "interact_response" -> forward_to_session(state, session_id, raw)

    // Correlated responses: match against pending
    _ -> {
      let pending_key = session_id <> ":" <> req_id
      case dict.get(state.pending, pending_key) {
        Ok(pv) -> {
          pv.on_reply(raw)
          PoolState(..state, pending: dict.delete(state.pending, pending_key))
        }
        Error(_) -> forward_to_session(state, session_id, raw)
      }
    }
  }
}

@target(erlang)
fn forward_to_session(
  state: PoolState,
  session_id: String,
  raw: Dynamic,
) -> PoolState {
  case dict.get(state.sessions, session_id) {
    Ok(entry) -> {
      let msg_type = dyn_string_field(raw, "type", "")
      let event = case msg_type {
        "interact_step" -> PoolEventInteractStep(session_id:, data: raw)
        "interact_response" -> PoolEventInteractResponse(session_id:, data: raw)
        _ -> PoolEventGeneric(session_id:, data: raw)
      }
      send_to_pid(entry.owner, event)
      state
    }
    Error(_) -> state
  }
}

// ---------------------------------------------------------------------------
// Internal: helpers
// ---------------------------------------------------------------------------

@target(erlang)
fn send_to_port(
  port: Port,
  format: protocol.Format,
  msg: Dict(String, node.PropValue),
) -> Nil {
  case proto_encode.serialize(msg, format) {
    Ok(data) -> {
      renderer_port.port_command(port, data)
      Nil
    }
    Error(_) -> Nil
  }
}

@target(erlang)
fn classify_port_message(format: protocol.Format, msg: Dynamic) -> PoolMessage {
  case format {
    protocol.Json ->
      case renderer_port.extract_line_data(msg) {
        Ok(line_data) -> PortLineData(line_data:)
        Error(_) ->
          case renderer_port.extract_exit_status(msg) {
            Ok(status) -> PortExit(status:)
            Error(_) -> PortData(data: msg)
          }
      }
    protocol.Msgpack ->
      case renderer_port.extract_port_data(msg) {
        Ok(data) -> PortData(data:)
        Error(_) ->
          case renderer_port.extract_exit_status(msg) {
            Ok(status) -> PortExit(status:)
            Error(_) -> PortData(data: msg)
          }
      }
  }
}

@target(erlang)
fn dyn_string_field(data: Dynamic, key: String, default: String) -> String {
  case dyn_decode.run(data, dyn_decode.at([key], dyn_decode.string)) {
    Ok(s) -> s
    Error(_) -> default
  }
}

@target(erlang)
/// Check whether a pending key belongs to a given session.
/// Keys are formatted as "session_id:req_id".
fn starts_with_session(key: String, session_id: String) -> Bool {
  let prefix = session_id <> ":"
  case key {
    _ if key == prefix -> True
    _ -> string_starts_with(key, prefix)
  }
}

// -- FFI ----------------------------------------------------------------------

@target(erlang)
@external(erlang, "plushie_test_renderer_ffi", "deserialize_wire")
fn deserialize_wire(
  bytes: BitArray,
  format: protocol.Format,
) -> Result(Dynamic, Nil)

@target(erlang)
/// Get the caller's pid (for registration).
@external(erlang, "erlang", "self")
fn get_caller_pid() -> Pid

@target(erlang)
/// Monitor a process.
@external(erlang, "plushie_test_pool_ffi", "monitor_process")
fn monitor_process(pid: Pid) -> Dynamic

@target(erlang)
/// Demonitor a reference.
@external(erlang, "plushie_test_pool_ffi", "demonitor_process")
fn demonitor(ref: Dynamic) -> Nil

@target(erlang)
/// Send a message to a pid.
@external(erlang, "plushie_test_pool_ffi", "send_to_pid")
fn send_to_pid(pid: Pid, msg: PoolEvent) -> Nil

@target(erlang)
/// Convert a pid to a string for use as dict key.
@external(erlang, "plushie_test_pool_ffi", "pid_to_string")
fn pid_to_string(pid: Pid) -> String

@target(erlang)
/// Check if a string starts with a prefix.
@external(erlang, "plushie_test_pool_ffi", "string_starts_with")
fn string_starts_with(str: String, prefix: String) -> Bool

@target(erlang)
/// Find plushie binary (re-export from binary module).
fn plushie_binary_find() -> Result(String, Nil) {
  case plushie_binary_find_impl() {
    Ok(p) -> Ok(p)
    Error(_) -> Error(Nil)
  }
}

@target(erlang)
import plushie/binary

@target(erlang)
fn plushie_binary_find_impl() {
  binary.find()
  |> result.map_error(fn(_) { Nil })
}
