//// Shared renderer process for concurrent test sessions.
////
//// Owns a single `toddy --headless --max-sessions N` (or `--mock`)
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
////         renderer_path: Some("/path/to/toddy"),
////       ),
////     )
////
//// Then use the pooled backend, passing the pool:
////
////     let backend = pooled.backend(pool)

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dyn_decode
import gleam/erlang/port.{type Port}
import gleam/erlang/process.{type Pid, type Subject}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import toddy/ffi
import toddy/node
import toddy/protocol
import toddy/protocol/encode as proto_encode
import toddy/renderer_env

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Pool mode: mock or headless.
pub type PoolMode {
  Mock
  Headless
}

/// Configuration for starting a session pool.
pub type PoolConfig {
  PoolConfig(
    /// Pool mode (mock or headless). Default: Mock.
    mode: PoolMode,
    /// Wire format. Default: Msgpack.
    format: protocol.Format,
    /// Maximum concurrent sessions. Default: 8.
    max_sessions: Int,
    /// Path to the toddy binary. None = auto-resolve.
    renderer_path: Option(String),
  )
}

/// Default pool configuration.
pub fn default_config() -> PoolConfig {
  PoolConfig(
    mode: Mock,
    format: protocol.Msgpack,
    max_sessions: 8,
    renderer_path: None,
  )
}

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
  PortLineData(line_data: ffi.LineData)
  /// Port exited.
  PortExit(status: Dynamic)
  /// Session owner process died.
  OwnerDown(session_id: String)
}

/// Reply for register calls.
pub type RegisterReply {
  Registered(session_id: String)
  PoolFull(max: Int)
  AlreadyRegistered(session_id: String)
}

/// Reply for unregister calls.
pub type UnregisterReply {
  Unregistered
  UnregisterError(String)
}

/// Reply for send-sync calls.
pub type SendReply {
  SendOk(Dynamic)
  SendError(String)
}

/// Pool event forwarded to session owners.
pub type PoolEvent {
  PoolEventInteractStep(session_id: String, data: Dynamic)
  PoolEventInteractResponse(session_id: String, data: Dynamic)
  PoolEventGeneric(session_id: String, data: Dynamic)
}

/// Convenience alias for the pool actor's Subject.
pub type PoolSubject =
  Subject(PoolMessage)

// ---------------------------------------------------------------------------
// Pool state
// ---------------------------------------------------------------------------

type SessionEntry {
  SessionEntry(owner: Pid, monitor_ref: Dynamic)
}

type PendingValue {
  PendingValue(response_type: String, reply: Subject(SendReply))
}

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

/// Start a session pool.
pub fn start(config: PoolConfig) -> Result(PoolSubject, actor.StartError) {
  actor.new_with_initialiser(10_000, fn(subject) { init_pool(subject, config) })
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

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

/// Unregister a session.
pub fn unregister(pool: PoolSubject, session_id: String) -> Nil {
  case
    process.call(pool, 10_000, fn(reply) { Unregister(session_id:, reply:) })
  {
    Unregistered -> Nil
    UnregisterError(_) -> Nil
  }
}

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

/// Send a fire-and-forget message to the renderer.
pub fn send_async(
  pool: PoolSubject,
  session_id: String,
  msg: Dict(String, node.PropValue),
) -> Nil {
  process.send(pool, SendAsync(session_id:, msg:))
}

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

fn init_pool(subject: PoolSubject, config: PoolConfig) {
  let renderer_path = case config.renderer_path {
    Some(p) -> p
    None -> {
      let assert Ok(p) = toddy_binary_find()
      p
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
    protocol.Msgpack -> ffi.msgpack_port_options()
    protocol.Json -> ffi.json_port_options()
  }

  let env_entries = renderer_env.build(renderer_env.default_opts())
  let env = renderer_env.to_port_env(env_entries)

  let port = ffi.open_port_spawn(renderer_path, args, env, options)

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
    PendingValue(response_type: "reset_response", reply: coerce_subject(reply))
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
  let pending_value = PendingValue(response_type:, reply:)
  let pending = dict.insert(state.pending, pending_key, pending_value)

  actor.continue(PoolState(..state, pending:, next_id: state.next_id + 1))
}

fn handle_send_async(
  state: PoolState,
  session_id: String,
  msg: Dict(String, node.PropValue),
) -> actor.Next(PoolState, PoolMessage) {
  let msg = dict.insert(msg, "session", node.StringVal(session_id))
  send_to_port(state.port, state.format, msg)
  actor.continue(state)
}

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
          process.send(pv.reply, SendError("session owner died"))
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

fn handle_line_data(
  state: PoolState,
  line_data: ffi.LineData,
) -> actor.Next(PoolState, PoolMessage) {
  case line_data {
    ffi.Eol(data:) -> {
      let new_state = dispatch_wire(state, data)
      actor.continue(new_state)
    }
    ffi.Noeol(_data) -> actor.continue(state)
  }
}

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
  dict.each(state.pending, fn(_key, pv) {
    process.send(pv.reply, SendError("renderer exited"))
  })

  actor.stop()
}

// ---------------------------------------------------------------------------
// Internal: wire dispatch
// ---------------------------------------------------------------------------

fn dispatch_wire(state: PoolState, bytes: BitArray) -> PoolState {
  case deserialize_wire(bytes, state.format) {
    Ok(raw) -> dispatch_raw(state, raw)
    Error(_) -> state
  }
}

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
          process.send(pv.reply, SendOk(raw))
          PoolState(..state, pending: dict.delete(state.pending, pending_key))
        }
        Error(_) -> forward_to_session(state, session_id, raw)
      }
    }
  }
}

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

fn send_to_port(
  port: Port,
  format: protocol.Format,
  msg: Dict(String, node.PropValue),
) -> Nil {
  case proto_encode.serialize(msg, format) {
    Ok(data) -> {
      ffi.port_command(port, data)
      Nil
    }
    Error(_) -> Nil
  }
}

fn classify_port_message(format: protocol.Format, msg: Dynamic) -> PoolMessage {
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

fn dyn_string_field(data: Dynamic, key: String, default: String) -> String {
  case dyn_decode.run(data, dyn_decode.at([key], dyn_decode.string)) {
    Ok(s) -> s
    Error(_) -> default
  }
}

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

@external(erlang, "toddy_test_renderer_ffi", "deserialize_wire")
fn deserialize_wire(
  bytes: BitArray,
  format: protocol.Format,
) -> Result(Dynamic, Nil)

/// Get the caller's pid (for registration).
@external(erlang, "erlang", "self")
fn get_caller_pid() -> Pid

/// Monitor a process.
@external(erlang, "toddy_test_pool_ffi", "monitor_process")
fn monitor_process(pid: Pid) -> Dynamic

/// Demonitor a reference.
@external(erlang, "toddy_test_pool_ffi", "demonitor_process")
fn demonitor(ref: Dynamic) -> Nil

/// Send a message to a pid.
@external(erlang, "toddy_test_pool_ffi", "send_to_pid")
fn send_to_pid(pid: Pid, msg: PoolEvent) -> Nil

/// Convert a pid to a string for use as dict key.
@external(erlang, "toddy_test_pool_ffi", "pid_to_string")
fn pid_to_string(pid: Pid) -> String

/// Check if a string starts with a prefix.
@external(erlang, "toddy_test_pool_ffi", "string_starts_with")
fn string_starts_with(str: String, prefix: String) -> Bool

/// Find toddy binary (re-export from binary module).
fn toddy_binary_find() -> Result(String, Nil) {
  case toddy_binary_find_impl() {
    Ok(p) -> Ok(p)
    Error(_) -> Error(Nil)
  }
}

@external(erlang, "toddy_test_ffi", "identity")
fn coerce_subject(value: a) -> b

import toddy/binary

fn toddy_binary_find_impl() {
  binary.find()
  |> result.map_error(fn(_) { Nil })
}
