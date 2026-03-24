//// Test renderer: OTP actor wrapping a Port to the Rust binary.
////
//// Provides bidirectional wire communication for renderer-backed test
//// backends (headless and windowed). Handles the Elm loop: dispatches
//// decoded events through update, processes commands, re-renders the
//// view, and sends snapshots back to the renderer.
////
//// ## Request/response lifecycle
////
//// External callers send `Call*` messages (find, interact, tree_hash,
//// screenshot, reset) which include a reply Subject. The actor
//// assigns a unique request ID, sends a wire message to the Rust
//// binary, and stores a `PendingEntry` keyed by that ID. When the
//// Rust binary responds, the actor matches the response ID to the
//// pending map, replies to the caller, and removes the entry.
////
//// **Pending map invariant**: every entry in the pending map
//// corresponds to exactly one outstanding wire request. If the port
//// exits, all pending callers receive a `ReplyError` and the actor
//// stops. No request ID is ever reused.
////
//// ## Backends
////
//// Use headless mode (`--headless` args) for CI and screenshot tests
//// with software rendering. Use windowed mode for manual visual
//// verification. The mock backend does not use this actor at all --
//// it runs the Elm loop in pure Gleam without a port.

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
import gleam/list
@target(erlang)
import gleam/option.{type Option, None, Some}
@target(erlang)
import gleam/otp/actor
@target(erlang)
import gleam/result
@target(erlang)
import gleam/string
@target(erlang)
import plushie/app.{type App}
@target(erlang)
import plushie/binary
@target(erlang)
import plushie/event.{type Event}
@target(erlang)
import plushie/ffi
@target(erlang)
import plushie/node.{type Node, StringVal}
@target(erlang)
import plushie/protocol
@target(erlang)
import plushie/protocol/encode as proto_encode
@target(erlang)
import plushie/renderer_env
@target(erlang)
import plushie/testing/command_processor
@target(erlang)
import plushie/testing/element.{type Element}
@target(erlang)
import plushie/testing/event_decoder
@target(erlang)
import plushie/testing/screenshot.{type Screenshot, Screenshot}
@target(erlang)
import plushie/testing/tree_hash.{type TreeHash, TreeHash}
@target(erlang)
import plushie/tree

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

@target(erlang)
/// Configuration for starting a renderer actor.
pub type RendererConfig {
  RendererConfig(
    /// Port arguments (e.g. ["--headless"] or ["--headless", "--json"]).
    args: List(String),
    /// Wire format.
    format: protocol.Format,
    /// Path to the plushie binary. None = auto-resolve.
    renderer_path: Option(String),
    /// Whether to send settings before the initial snapshot.
    send_settings: Bool,
    /// Screenshot dimensions for headless mode (None for windowed).
    screenshot_size: Option(#(Int, Int)),
  )
}

@target(erlang)
/// Pending request types for response correlation.
type PendingType {
  PendingFind
  PendingTree
  PendingInteract(action: String)
  PendingTreeHash(name: String)
  PendingScreenshot(name: String)
  PendingReset
}

@target(erlang)
/// Pending request entry: type + reply subject.
type PendingEntry {
  PendingEntry(kind: PendingType, reply: Subject(RendererReply))
}

@target(erlang)
/// Internal actor state.
type RendererState(model) {
  RendererState(
    port: Port,
    format: protocol.Format,
    app: App(model, Event),
    model: model,
    tree: Node,
    pending: Dict(String, PendingEntry),
    next_id: Int,
    screenshot_size: Option(#(Int, Int)),
  )
}

@target(erlang)
/// Messages the renderer actor handles.
pub opaque type RendererMessage {
  /// External call: find element by selector.
  CallFind(selector: String, reply: Subject(RendererReply))
  /// External call: get raw tree from renderer.
  CallTree(reply: Subject(RendererReply))
  /// External call: interact (click, type_text, etc.).
  CallInteract(
    action: String,
    selector: Option(String),
    payload: Dict(String, String),
    reply: Subject(RendererReply),
  )
  /// External call: get tree hash from renderer.
  CallTreeHash(name: String, reply: Subject(RendererReply))
  /// External call: capture screenshot.
  CallScreenshot(name: String, reply: Subject(RendererReply))
  /// External call: get current model.
  CallModel(reply: Subject(RendererReply))
  /// External call: reset session.
  CallReset(reply: Subject(RendererReply))
  /// Port data received from the renderer (msgpack binary).
  PortData(data: Dynamic)
  /// Port line data received (JSON mode).
  PortLineData(line_data: ffi.LineData)
  /// Port exited.
  PortExit(status: Dynamic)
}

@target(erlang)
/// Convenience alias for the renderer actor's Subject.
pub type RendererSubject =
  Subject(RendererMessage)

@target(erlang)
/// Reply values from the renderer actor.
pub type RendererReply {
  ReplyElement(Option(Element))
  ReplyTree(Option(Dynamic))
  ReplyOk
  ReplyModel(Dynamic)
  ReplyTreeHash(TreeHash)
  ReplyScreenshot(Screenshot)
  ReplyError(String)
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

@target(erlang)
/// Start a renderer actor with the given app and config.
pub fn start(
  app: App(model, Event),
  config: RendererConfig,
) -> Result(Subject(RendererMessage), actor.StartError) {
  actor.new_with_initialiser(10_000, fn(subject) {
    init_renderer(subject, app, config)
  })
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

@target(erlang)
/// Stop a renderer actor by sending a normal exit to its process.
pub fn stop(subject: Subject(RendererMessage)) -> Nil {
  case process.subject_owner(subject) {
    Ok(pid) -> send_exit(pid)
    Error(_) -> Nil
  }
}

@target(erlang)
/// Find an element by selector string.
pub fn find(
  subject: Subject(RendererMessage),
  selector: String,
) -> Option(Element) {
  case
    process.call(subject, 10_000, fn(reply) { CallFind(selector:, reply:) })
  {
    ReplyElement(el) -> el
    _ -> None
  }
}

@target(erlang)
/// Click on an element identified by selector.
pub fn click(subject: Subject(RendererMessage), selector: String) -> Nil {
  interact(subject, "click", Some(selector), dict.new())
}

@target(erlang)
/// Type text into an element identified by selector.
pub fn type_text(
  subject: Subject(RendererMessage),
  selector: String,
  text: String,
) -> Nil {
  interact(
    subject,
    "type_text",
    Some(selector),
    dict.from_list([#("text", text)]),
  )
}

@target(erlang)
/// Submit a form element identified by selector.
pub fn submit(subject: Subject(RendererMessage), selector: String) -> Nil {
  interact(subject, "submit", Some(selector), dict.new())
}

@target(erlang)
/// Toggle a checkbox/toggler identified by selector.
pub fn toggle(subject: Subject(RendererMessage), selector: String) -> Nil {
  interact(subject, "toggle", Some(selector), dict.new())
}

@target(erlang)
/// Select a value on a picker/dropdown identified by selector.
pub fn select(
  subject: Subject(RendererMessage),
  selector: String,
  value: String,
) -> Nil {
  interact(
    subject,
    "select",
    Some(selector),
    dict.from_list([#("value", value)]),
  )
}

@target(erlang)
/// Slide a slider to a value, identified by selector.
pub fn slide(
  subject: Subject(RendererMessage),
  selector: String,
  value: Float,
) -> Nil {
  interact(
    subject,
    "slide",
    Some(selector),
    dict.from_list([#("value", float_to_string(value))]),
  )
}

@target(erlang)
/// Get the current model (returned as Dynamic -- caller casts).
pub fn model(subject: Subject(RendererMessage)) -> Dynamic {
  case process.call(subject, 10_000, fn(reply) { CallModel(reply:) }) {
    ReplyModel(m) -> m
    _ -> dynamic.nil()
  }
}

@target(erlang)
/// Get the raw tree from the renderer.
pub fn get_tree(subject: Subject(RendererMessage)) -> Option(Dynamic) {
  case process.call(subject, 10_000, fn(reply) { CallTree(reply:) }) {
    ReplyTree(t) -> t
    _ -> None
  }
}

@target(erlang)
/// Get a tree hash from the renderer.
pub fn get_tree_hash(
  subject: Subject(RendererMessage),
  name: String,
) -> TreeHash {
  case
    process.call(subject, 30_000, fn(reply) { CallTreeHash(name:, reply:) })
  {
    ReplyTreeHash(th) -> th
    _ -> TreeHash(name:, hash: "")
  }
}

@target(erlang)
/// Capture a screenshot from the renderer.
pub fn get_screenshot(
  subject: Subject(RendererMessage),
  name: String,
) -> Screenshot {
  case
    process.call(subject, 30_000, fn(reply) { CallScreenshot(name:, reply:) })
  {
    ReplyScreenshot(s) -> s
    _ -> screenshot.empty(name)
  }
}

@target(erlang)
/// Reset the session to initial state.
pub fn reset(subject: Subject(RendererMessage)) -> Nil {
  case process.call(subject, 10_000, fn(reply) { CallReset(reply:) }) {
    _ -> Nil
  }
}

@target(erlang)
/// Press a key (no selector).
pub fn press(subject: Subject(RendererMessage), key: String) -> Nil {
  let payload = parse_key(key)
  interact(subject, "press", None, payload)
}

@target(erlang)
/// Release a key (no selector).
pub fn release(subject: Subject(RendererMessage), key: String) -> Nil {
  let payload = parse_key(key)
  interact(subject, "release", None, payload)
}

@target(erlang)
/// Move the mouse pointer to absolute coordinates.
pub fn move_to(subject: Subject(RendererMessage), x: Float, y: Float) -> Nil {
  interact(
    subject,
    "move_to",
    None,
    dict.from_list([
      #("x", float_to_string(x)),
      #("y", float_to_string(y)),
    ]),
  )
}

@target(erlang)
/// Press and release a key (no selector).
pub fn type_key(subject: Subject(RendererMessage), key: String) -> Nil {
  let payload = parse_key(key)
  interact(subject, "type_key", None, payload)
}

// ---------------------------------------------------------------------------
// Internal: interact helper
// ---------------------------------------------------------------------------

@target(erlang)
fn interact(
  subject: Subject(RendererMessage),
  action: String,
  selector: Option(String),
  payload: Dict(String, String),
) -> Nil {
  case
    process.call(subject, 10_000, fn(reply) {
      CallInteract(action:, selector:, payload:, reply:)
    })
  {
    ReplyError(reason) -> panic as { "renderer error: " <> reason }
    _ -> Nil
  }
}

// ---------------------------------------------------------------------------
// Internal: actor init
// ---------------------------------------------------------------------------

@target(erlang)
fn init_renderer(
  subject: Subject(RendererMessage),
  app: App(model, Event),
  config: RendererConfig,
) {
  let renderer_path = case config.renderer_path {
    Some(p) -> p
    None ->
      case binary.find() {
        Ok(p) -> p
        Error(_) -> panic as "plushie binary not found"
      }
  }

  let options = case config.format {
    protocol.Msgpack -> ffi.msgpack_port_options()
    protocol.Json -> ffi.json_port_options()
  }

  let env_entries = renderer_env.build(renderer_env.default_opts())
  let env = renderer_env.to_port_env(env_entries)

  let port = ffi.open_port_spawn(renderer_path, config.args, env, options)

  // If windowed, send settings before the initial snapshot
  case config.send_settings {
    True -> {
      let settings = { app.get_settings(app) }()
      let assert Ok(data) =
        proto_encode.encode_settings(settings, "", config.format, option.None)
      ffi.port_command(port, data)
      Nil
    }
    False -> Nil
  }

  // Init the app
  let init_fn = app.get_init(app)
  let #(init_model, init_commands) = init_fn(dynamic.nil())
  let #(model, _events) =
    command_processor.process_commands(app, init_model, init_commands, None)
  let view_fn = app.get_view(app)
  let initial_tree = view_fn(model) |> tree.normalize()

  // Send initial snapshot
  let assert Ok(snapshot_data) =
    proto_encode.encode_snapshot(initial_tree, "", config.format)
  ffi.port_command(port, snapshot_data)

  let selector =
    process.new_selector()
    |> process.select(subject)
    |> process.select_other(classify_port_message(config.format, _))

  let state =
    RendererState(
      port:,
      format: config.format,
      app:,
      model:,
      tree: initial_tree,
      pending: dict.new(),
      next_id: 1,
      screenshot_size: config.screenshot_size,
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
  state: RendererState(model),
  msg: RendererMessage,
) -> actor.Next(RendererState(model), RendererMessage) {
  case msg {
    CallFind(selector:, reply:) -> handle_find(state, selector, reply)
    CallTree(reply:) -> handle_tree_call(state, reply)
    CallInteract(action:, selector:, payload:, reply:) ->
      handle_interact(state, action, selector, payload, reply)
    CallTreeHash(name:, reply:) -> handle_tree_hash(state, name, reply)
    CallScreenshot(name:, reply:) -> handle_screenshot(state, name, reply)
    CallModel(reply:) -> {
      process.send(reply, ReplyModel(model_to_dynamic(state.model)))
      actor.continue(state)
    }
    CallReset(reply:) -> handle_reset(state, reply)
    PortData(data:) -> handle_port_data(state, data)
    PortLineData(line_data:) -> handle_line_data(state, line_data)
    PortExit(status:) -> handle_port_exit(state, status)
  }
}

// ---------------------------------------------------------------------------
// Internal: call handlers (send request, store pending)
// ---------------------------------------------------------------------------

@target(erlang)
fn handle_find(
  state: RendererState(model),
  selector: String,
  reply: Subject(RendererReply),
) -> actor.Next(RendererState(model), RendererMessage) {
  let #(req_id, state) = next_id(state)
  let sel = encode_selector(selector, state.tree)

  let msg =
    dict.from_list([
      #("type", node.StringVal("query")),
      #("session", node.StringVal("")),
      #("id", node.StringVal(req_id)),
      #("target", node.StringVal("find")),
      #("selector", node.DictVal(sel)),
    ])
  send_wire(state.port, state.format, msg)

  let entry = PendingEntry(kind: PendingFind, reply:)
  let state =
    RendererState(..state, pending: dict.insert(state.pending, req_id, entry))
  actor.continue(state)
}

@target(erlang)
fn handle_tree_call(
  state: RendererState(model),
  reply: Subject(RendererReply),
) -> actor.Next(RendererState(model), RendererMessage) {
  let #(req_id, state) = next_id(state)

  let msg =
    dict.from_list([
      #("type", node.StringVal("query")),
      #("session", node.StringVal("")),
      #("id", node.StringVal(req_id)),
      #("target", node.StringVal("tree")),
      #("selector", node.DictVal(dict.new())),
    ])
  send_wire(state.port, state.format, msg)

  let entry = PendingEntry(kind: PendingTree, reply:)
  let state =
    RendererState(..state, pending: dict.insert(state.pending, req_id, entry))
  actor.continue(state)
}

@target(erlang)
fn handle_interact(
  state: RendererState(model),
  action: String,
  selector: Option(String),
  payload: Dict(String, String),
  reply: Subject(RendererReply),
) -> actor.Next(RendererState(model), RendererMessage) {
  let #(req_id, state) = next_id(state)
  let sel = case selector {
    Some(s) -> encode_selector(s, state.tree)
    None -> dict.new()
  }

  let payload_pv =
    dict.to_list(payload)
    |> list.map(fn(pair) { #(pair.0, node.StringVal(pair.1)) })
    |> dict.from_list

  let msg =
    dict.from_list([
      #("type", node.StringVal("interact")),
      #("session", node.StringVal("")),
      #("id", node.StringVal(req_id)),
      #("action", node.StringVal(action)),
      #("selector", node.DictVal(sel)),
      #("payload", node.DictVal(payload_pv)),
    ])
  send_wire(state.port, state.format, msg)

  let entry = PendingEntry(kind: PendingInteract(action:), reply:)
  let state =
    RendererState(..state, pending: dict.insert(state.pending, req_id, entry))
  actor.continue(state)
}

@target(erlang)
fn handle_tree_hash(
  state: RendererState(model),
  name: String,
  reply: Subject(RendererReply),
) -> actor.Next(RendererState(model), RendererMessage) {
  let #(req_id, state) = next_id(state)

  let msg =
    dict.from_list([
      #("type", node.StringVal("tree_hash")),
      #("session", node.StringVal("")),
      #("id", node.StringVal(req_id)),
      #("name", node.StringVal(name)),
    ])
  send_wire(state.port, state.format, msg)

  let entry = PendingEntry(kind: PendingTreeHash(name:), reply:)
  let state =
    RendererState(..state, pending: dict.insert(state.pending, req_id, entry))
  actor.continue(state)
}

@target(erlang)
fn handle_screenshot(
  state: RendererState(model),
  name: String,
  reply: Subject(RendererReply),
) -> actor.Next(RendererState(model), RendererMessage) {
  let #(req_id, state) = next_id(state)

  let fields = [
    #("type", node.StringVal("screenshot")),
    #("session", node.StringVal("")),
    #("id", node.StringVal(req_id)),
    #("name", node.StringVal(name)),
  ]
  let fields = case state.screenshot_size {
    Some(#(w, h)) -> [
      #("width", node.IntVal(w)),
      #("height", node.IntVal(h)),
      ..fields
    ]
    None -> fields
  }
  let msg = dict.from_list(fields)
  send_wire(state.port, state.format, msg)

  let entry = PendingEntry(kind: PendingScreenshot(name:), reply:)
  let state =
    RendererState(..state, pending: dict.insert(state.pending, req_id, entry))
  actor.continue(state)
}

@target(erlang)
fn handle_reset(
  state: RendererState(model),
  reply: Subject(RendererReply),
) -> actor.Next(RendererState(model), RendererMessage) {
  let #(req_id, state) = next_id(state)

  let msg =
    dict.from_list([
      #("type", node.StringVal("reset")),
      #("session", node.StringVal("")),
      #("id", node.StringVal(req_id)),
    ])
  send_wire(state.port, state.format, msg)

  // Re-init app
  let init_fn = app.get_init(state.app)
  let #(init_model, init_commands) = init_fn(dynamic.nil())
  let #(model, _events) =
    command_processor.process_commands(
      state.app,
      init_model,
      init_commands,
      None,
    )
  let view_fn = app.get_view(state.app)
  let new_tree = view_fn(model) |> tree.normalize()

  // Send fresh snapshot
  let assert Ok(snapshot_data) =
    proto_encode.encode_snapshot(new_tree, "", state.format)
  ffi.port_command(state.port, snapshot_data)

  let entry = PendingEntry(kind: PendingReset, reply:)
  let state =
    RendererState(
      ..state,
      model:,
      tree: new_tree,
      pending: dict.insert(state.pending, req_id, entry),
    )
  actor.continue(state)
}

// ---------------------------------------------------------------------------
// Internal: port data handling
// ---------------------------------------------------------------------------

@target(erlang)
fn handle_port_data(
  state: RendererState(model),
  raw: Dynamic,
) -> actor.Next(RendererState(model), RendererMessage) {
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
  state: RendererState(model),
  line_data: ffi.LineData,
) -> actor.Next(RendererState(model), RendererMessage) {
  case line_data {
    ffi.Eol(data:) -> {
      let new_state = dispatch_wire(state, data)
      actor.continue(new_state)
    }
    ffi.Noeol(_data) ->
      // Partial lines -- the {line, N} port driver buffers them
      actor.continue(state)
  }
}

@target(erlang)
fn handle_port_exit(
  state: RendererState(model),
  status: Dynamic,
) -> actor.Next(RendererState(model), RendererMessage) {
  let exit_code = case dyn_decode.run(status, dyn_decode.int) {
    Ok(code) -> code
    Error(_) -> 1
  }

  // Reply to all pending callers with an error
  dict.each(state.pending, fn(_id, entry) {
    process.send(
      entry.reply,
      ReplyError("renderer exited with status " <> int.to_string(exit_code)),
    )
  })

  actor.stop()
}

// ---------------------------------------------------------------------------
// Internal: wire deserialization and dispatch
// ---------------------------------------------------------------------------

@target(erlang)
/// Deserialize wire bytes and dispatch based on message type.
fn dispatch_wire(
  state: RendererState(model),
  bytes: BitArray,
) -> RendererState(model) {
  case deserialize_wire(bytes, state.format) {
    Ok(raw_map) -> dispatch_raw(state, raw_map)
    Error(_) -> state
  }
}

@target(erlang)
/// Route a deserialized wire message by its "type" field.
fn dispatch_raw(
  state: RendererState(model),
  raw: Dynamic,
) -> RendererState(model) {
  let msg_type = dyn_string_field(raw, "type", "")
  let req_id = dyn_string_field(raw, "id", "")

  case msg_type {
    // Handshake -- nothing to do in test mode
    "hello" -> state

    // Wire events (from production flow, not from interact)
    "event" -> {
      let family = dyn_string_field(raw, "family", "")
      let id = dyn_string_field(raw, "id", "")
      dispatch_wire_event(state, family, id, raw)
    }

    // Responses correlated to pending requests
    "query_response" -> handle_response(state, req_id, raw, msg_type)
    "interact_response" -> handle_response(state, req_id, raw, msg_type)
    "tree_hash_response" -> handle_response(state, req_id, raw, msg_type)
    "screenshot_response" -> handle_response(state, req_id, raw, msg_type)
    "reset_response" -> handle_response(state, req_id, raw, msg_type)

    _ -> state
  }
}

@target(erlang)
fn handle_response(
  state: RendererState(model),
  req_id: String,
  raw: Dynamic,
  msg_type: String,
) -> RendererState(model) {
  case dict.get(state.pending, req_id) {
    Error(_) -> state
    Ok(entry) -> {
      let pending = dict.delete(state.pending, req_id)
      let state = RendererState(..state, pending:)

      case msg_type, entry.kind {
        "query_response", PendingFind -> {
          let el = decode_find_data(raw)
          process.send(entry.reply, ReplyElement(el))
          state
        }
        "query_response", PendingTree -> {
          let data = dyn_field(raw, "data")
          process.send(entry.reply, ReplyTree(option.from_result(data)))
          state
        }
        "interact_response", PendingInteract(_action) -> {
          let state = dispatch_interact_events(state, raw)
          process.send(entry.reply, ReplyOk)
          state
        }
        "tree_hash_response", PendingTreeHash(name) -> {
          let hash = dyn_string_field(raw, "hash", "")
          process.send(entry.reply, ReplyTreeHash(TreeHash(name:, hash:)))
          state
        }
        "screenshot_response", PendingScreenshot(name) -> {
          let hash = dyn_string_field(raw, "hash", "")
          let width = dyn_int_field(raw, "width", 0)
          let height = dyn_int_field(raw, "height", 0)
          let pixels = dyn_binary_field(raw, "rgba")
          process.send(
            entry.reply,
            ReplyScreenshot(Screenshot(name:, hash:, width:, height:, pixels:)),
          )
          state
        }
        "reset_response", PendingReset -> {
          process.send(entry.reply, ReplyOk)
          state
        }
        _, _ -> state
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Internal: event dispatching (Elm loop)
// ---------------------------------------------------------------------------

@target(erlang)
fn dispatch_wire_event(
  state: RendererState(model),
  family: String,
  id: String,
  raw: Dynamic,
) -> RendererState(model) {
  case family {
    "" -> state
    _ -> {
      let event_dict = dyn_to_string_dict(raw)
      case event_decoder.decode_test_event(family, id, event_dict) {
        Ok(event) -> run_update(state, event)
        Error(_) -> state
      }
    }
  }
}

@target(erlang)
fn dispatch_interact_events(
  state: RendererState(model),
  raw: Dynamic,
) -> RendererState(model) {
  let events = dyn_list_field(raw, "events")
  list.fold(events, state, fn(acc, event_data) {
    let family = dyn_string_field(event_data, "family", "")
    let id = dyn_string_field(event_data, "id", "")
    dispatch_wire_event(acc, family, id, event_data)
  })
}

@target(erlang)
/// Run the Elm loop: update -> process commands -> view -> snapshot.
fn run_update(state: RendererState(model), event: Event) -> RendererState(model) {
  let update_fn = app.get_update(state.app)
  let #(new_model, commands) = update_fn(state.model, event)
  let #(model, _events) =
    command_processor.process_commands(state.app, new_model, commands, None)
  let view_fn = app.get_view(state.app)
  let new_tree = view_fn(model) |> tree.normalize()

  let assert Ok(snapshot_data) =
    proto_encode.encode_snapshot(new_tree, "", state.format)
  ffi.port_command(state.port, snapshot_data)

  RendererState(..state, model:, tree: new_tree)
}

// ---------------------------------------------------------------------------
// Internal: selector encoding
// ---------------------------------------------------------------------------

@target(erlang)
fn encode_selector(
  selector: String,
  current_tree: Node,
) -> Dict(String, node.PropValue) {
  case selector {
    "#" <> id -> {
      let resolved = case string.contains(id, "/") {
        True -> id
        False ->
          case resolve_local_id(current_tree, id) {
            Some(scoped_id) -> scoped_id
            None -> id
          }
      }
      dict.from_list([
        #("by", StringVal("id")),
        #("value", StringVal(resolved)),
      ])
    }
    _ ->
      dict.from_list([
        #("by", StringVal("text")),
        #("value", StringVal(selector)),
      ])
  }
}

@target(erlang)
fn resolve_local_id(nd: Node, target_id: String) -> Option(String) {
  let local = case string.split(nd.id, "/") {
    [single] -> single
    parts ->
      case list.last(parts) {
        Ok(last) -> last
        Error(_) -> nd.id
      }
  }

  case local == target_id {
    True -> Some(nd.id)
    False ->
      list.find_map(nd.children, fn(child) {
        case resolve_local_id(child, target_id) {
          Some(found) -> Ok(found)
          None -> Error(Nil)
        }
      })
      |> option.from_result
  }
}

// ---------------------------------------------------------------------------
// Internal: helpers
// ---------------------------------------------------------------------------

@target(erlang)
fn next_id(state: RendererState(model)) -> #(String, RendererState(model)) {
  let id = "req_" <> int.to_string(state.next_id)
  #(id, RendererState(..state, next_id: state.next_id + 1))
}

@target(erlang)
fn send_wire(
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

@target(erlang)
fn classify_port_message(
  format: protocol.Format,
  msg: Dynamic,
) -> RendererMessage {
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

@target(erlang)
fn parse_key(key: String) -> Dict(String, String) {
  let parts = string.split(key, "+")
  let #(mods, key_parts) = list.split(parts, list.length(parts) - 1)
  let key_name = case key_parts {
    [k] -> k
    _ -> key
  }

  let base = dict.from_list([#("key", key_name)])
  list.fold(mods, base, fn(acc, m) {
    case m {
      "ctrl" -> dict.insert(acc, "ctrl", "true")
      "shift" -> dict.insert(acc, "shift", "true")
      "alt" -> dict.insert(acc, "alt", "true")
      "logo" -> dict.insert(acc, "logo", "true")
      "command" -> dict.insert(acc, "command", "true")
      _ -> acc
    }
  })
}

@target(erlang)
fn decode_find_data(raw: Dynamic) -> Option(Element) {
  case dyn_field(raw, "data") {
    Error(_) -> None
    Ok(data) ->
      case is_nil_or_empty_map(data) {
        True -> None
        False -> {
          let id = dyn_string_field(data, "id", "")
          let kind = dyn_string_field(data, "type", "")
          Some(element.from_node(node.new(id, kind)))
        }
      }
  }
}

// ---------------------------------------------------------------------------
// Internal: Dynamic field accessors
// ---------------------------------------------------------------------------

@target(erlang)
fn dyn_string_field(data: Dynamic, key: String, default: String) -> String {
  case dyn_field(data, key) {
    Ok(val) ->
      case dyn_decode.run(val, dyn_decode.string) {
        Ok(s) -> s
        Error(_) -> default
      }
    Error(_) -> default
  }
}

@target(erlang)
fn dyn_int_field(data: Dynamic, key: String, default: Int) -> Int {
  case dyn_field(data, key) {
    Ok(val) ->
      case dyn_decode.run(val, dyn_decode.int) {
        Ok(i) -> i
        Error(_) -> default
      }
    Error(_) -> default
  }
}

@target(erlang)
fn dyn_binary_field(data: Dynamic, key: String) -> BitArray {
  case dyn_field(data, key) {
    Ok(val) ->
      case dyn_decode.run(val, dyn_decode.bit_array) {
        Ok(b) -> b
        Error(_) -> <<>>
      }
    Error(_) -> <<>>
  }
}

@target(erlang)
fn dyn_list_field(data: Dynamic, key: String) -> List(Dynamic) {
  case dyn_field(data, key) {
    Ok(val) ->
      case dyn_decode.run(val, dyn_decode.list(dyn_decode.dynamic)) {
        Ok(items) -> items
        Error(_) -> []
      }
    Error(_) -> []
  }
}

@target(erlang)
fn dyn_field(data: Dynamic, key: String) -> Result(Dynamic, Nil) {
  case dyn_decode.run(data, dyn_decode.at([key], dyn_decode.dynamic)) {
    Ok(val) -> Ok(val)
    Error(_) -> Error(Nil)
  }
}

@target(erlang)
fn dyn_to_string_dict(data: Dynamic) -> Dict(String, Dynamic) {
  case
    dyn_decode.run(data, dyn_decode.dict(dyn_decode.string, dyn_decode.dynamic))
  {
    Ok(d) -> d
    Error(_) -> dict.new()
  }
}

@target(erlang)
fn is_nil_or_empty_map(data: Dynamic) -> Bool {
  case
    dyn_decode.run(data, dyn_decode.dict(dyn_decode.string, dyn_decode.dynamic))
  {
    Ok(d) -> dict.is_empty(d)
    Error(_) ->
      case dyn_decode.run(data, dyn_decode.optional(dyn_decode.dynamic)) {
        Ok(None) -> True
        _ -> False
      }
  }
}

// ---------------------------------------------------------------------------
// FFI
// ---------------------------------------------------------------------------

@target(erlang)
/// Deserialize wire bytes to a Dynamic Erlang map.
@external(erlang, "plushie_test_renderer_ffi", "deserialize_wire")
fn deserialize_wire(
  bytes: BitArray,
  format: protocol.Format,
) -> Result(Dynamic, Nil)

@target(erlang)
@external(erlang, "plushie_test_renderer_ffi", "float_to_string")
fn float_to_string(f: Float) -> String

@target(erlang)
@external(erlang, "plushie_test_renderer_ffi", "send_exit")
fn send_exit(pid: Pid) -> Nil

@target(erlang)
/// Widen the typed model to Dynamic for the RendererReply boundary.
/// RendererMessage is not parameterized over model, so the reply
/// carries Dynamic. See also from_dynamic in headless/windowed backends.
@external(erlang, "plushie_test_ffi", "identity")
fn model_to_dynamic(value: a) -> Dynamic
