//// Test renderer: OTP actor wrapping a Port to the Rust binary.
////
//// Provides bidirectional wire communication for renderer-backed test
//// backends (headless and windowed). Handles the Elm loop: dispatches
//// decoded events through update, processes commands, re-renders the
//// view, and sends snapshots back to the renderer.
////
//// Request/response correlation is managed via a pending map keyed
//// by request ID, with each entry tracking the request type and the
//// reply Subject.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dyn_decode
import gleam/erlang/port.{type Port}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import toddy/app.{type App}
import toddy/binary
import toddy/command.{type Command}
import toddy/event.{type Event}
import toddy/ffi
import toddy/node.{type Node, BoolVal, StringVal}
import toddy/protocol
import toddy/protocol/decode as proto_decode
import toddy/protocol/encode as proto_encode
import toddy/renderer_env
import toddy/testing/command_processor
import toddy/testing/element.{type Element}
import toddy/testing/event_decoder
import toddy/testing/screenshot.{type Screenshot, Screenshot}
import toddy/testing/tree_hash.{type TreeHash, TreeHash}
import toddy/tree

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for starting a renderer actor.
pub type RendererConfig {
  RendererConfig(
    /// Port arguments (e.g. ["--headless"] or ["--headless", "--json"]).
    args: List(String),
    /// Wire format.
    format: protocol.Format,
    /// Path to the toddy binary. None = auto-resolve.
    renderer_path: Option(String),
    /// Whether to send settings before the initial snapshot.
    send_settings: Bool,
    /// Screenshot dimensions for headless mode (None for windowed).
    screenshot_size: Option(#(Int, Int)),
  )
}

/// Pending request types for response correlation.
type PendingType {
  PendingFind
  PendingTree
  PendingInteract(action: String)
  PendingTreeHash(name: String)
  PendingScreenshot(name: String)
  PendingReset
}

/// Pending request entry: type + reply subject.
type PendingEntry {
  PendingEntry(kind: PendingType, reply: Subject(RendererReply))
}

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
  /// Port data received from the renderer.
  PortData(data: Dynamic)
  /// Port line data received (JSON mode).
  PortLineData(line_data: ffi.LineData)
  /// Port exited.
  PortExit(status: Dynamic)
}

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

/// Start a renderer actor with the given app and config.
/// Returns the actor's Subject for sending messages.
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

/// Stop a renderer actor.
pub fn stop(subject: Subject(RendererMessage)) -> Nil {
  process.send_exit(process.subject_owner(subject))
  Nil
}

/// Find an element by selector string.
pub fn find(
  subject: Subject(RendererMessage),
  selector: String,
) -> Option(Element) {
  case
    process.call(subject, fn(reply) { CallFind(selector:, reply:) }, 10_000)
  {
    ReplyElement(el) -> el
    _ -> None
  }
}

/// Click on an element identified by selector.
pub fn click(subject: Subject(RendererMessage), selector: String) -> Nil {
  interact(subject, "click", Some(selector), dict.new())
}

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

/// Submit a form element identified by selector.
pub fn submit(subject: Subject(RendererMessage), selector: String) -> Nil {
  interact(subject, "submit", Some(selector), dict.new())
}

/// Toggle a checkbox/toggler identified by selector.
pub fn toggle(subject: Subject(RendererMessage), selector: String) -> Nil {
  interact(subject, "toggle", Some(selector), dict.new())
}

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

/// Get the current model.
pub fn model(subject: Subject(RendererMessage)) -> Dynamic {
  case process.call(subject, fn(reply) { CallModel(reply:) }, 10_000) {
    ReplyModel(m) -> m
    _ -> dynamic.nil()
  }
}

/// Get the raw tree from the renderer.
pub fn get_tree(subject: Subject(RendererMessage)) -> Option(Dynamic) {
  case process.call(subject, fn(reply) { CallTree(reply:) }, 10_000) {
    ReplyTree(t) -> t
    _ -> None
  }
}

/// Get a tree hash.
pub fn get_tree_hash(
  subject: Subject(RendererMessage),
  name: String,
) -> TreeHash {
  case
    process.call(subject, fn(reply) { CallTreeHash(name:, reply:) }, 30_000)
  {
    ReplyTreeHash(th) -> th
    _ -> TreeHash(name:, hash: "")
  }
}

/// Capture a screenshot.
pub fn get_screenshot(
  subject: Subject(RendererMessage),
  name: String,
) -> Screenshot {
  case
    process.call(subject, fn(reply) { CallScreenshot(name:, reply:) }, 30_000)
  {
    ReplyScreenshot(s) -> s
    _ -> screenshot.empty(name)
  }
}

/// Reset the session to initial state.
pub fn reset(subject: Subject(RendererMessage)) -> Nil {
  case process.call(subject, fn(reply) { CallReset(reply:) }, 10_000) {
    _ -> Nil
  }
}

/// Press a key (no selector).
pub fn press(subject: Subject(RendererMessage), key: String) -> Nil {
  let payload = parse_key(key)
  interact(subject, "press", None, payload)
}

/// Release a key (no selector).
pub fn release(subject: Subject(RendererMessage), key: String) -> Nil {
  let payload = parse_key(key)
  interact(subject, "release", None, payload)
}

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

/// Press and release a key (no selector).
pub fn type_key(subject: Subject(RendererMessage), key: String) -> Nil {
  let payload = parse_key(key)
  interact(subject, "type_key", None, payload)
}

// ---------------------------------------------------------------------------
// Internal: interact helper
// ---------------------------------------------------------------------------

fn interact(
  subject: Subject(RendererMessage),
  action: String,
  selector: Option(String),
  payload: Dict(String, String),
) -> Nil {
  case
    process.call(
      subject,
      fn(reply) { CallInteract(action:, selector:, payload:, reply:) },
      10_000,
    )
  {
    ReplyError(reason) -> panic as { "renderer error: " <> reason }
    _ -> Nil
  }
}

// ---------------------------------------------------------------------------
// Internal: actor init
// ---------------------------------------------------------------------------

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
        Error(_) -> panic as "toddy binary not found"
      }
  }

  let options = case config.format {
    protocol.Msgpack -> ffi.msgpack_port_options()
    protocol.Json -> ffi.json_port_options()
  }

  let env_entries = renderer_env.build(renderer_env.default_opts())
  let env = renderer_env.to_port_env(env_entries)

  let port = ffi.open_port_spawn(renderer_path, config.args, env, options)

  // If windowed, send settings first (required by daemon init)
  case config.send_settings {
    True -> {
      let settings = { app.get_settings(app) }()
      let assert Ok(data) =
        proto_encode.encode_settings(settings, "", config.format)
      ffi.port_command(port, data)
      Nil
    }
    False -> Nil
  }

  // Init the app
  let init_fn = app.get_init(app)
  let #(init_model, init_commands) = init_fn(dynamic.nil())
  let #(model, _events) =
    command_processor.process_commands(app, init_model, init_commands, 0)
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

fn handle_message(
  state: RendererState(model),
  msg: RendererMessage,
) -> actor.Next(RendererState(model), RendererMessage) {
  case msg {
    CallFind(selector:, reply:) -> handle_find(state, selector, reply)
    CallTree(reply:) -> handle_tree(state, reply)
    CallInteract(action:, selector:, payload:, reply:) ->
      handle_interact(state, action, selector, payload, reply)
    CallTreeHash(name:, reply:) -> handle_tree_hash(state, name, reply)
    CallScreenshot(name:, reply:) -> handle_screenshot(state, name, reply)
    CallModel(reply:) -> {
      process.send(reply, ReplyModel(dynamic.unsafe_coerce(state.model)))
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

fn handle_tree(
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
      0,
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

fn handle_port_data(
  state: RendererState(model),
  raw: Dynamic,
) -> actor.Next(RendererState(model), RendererMessage) {
  case dyn_decode.run(raw, dyn_decode.bit_array) {
    Ok(bytes) -> {
      let new_state = dispatch_decoded(state, bytes)
      actor.continue(new_state)
    }
    Error(_) -> actor.continue(state)
  }
}

fn handle_line_data(
  state: RendererState(model),
  line_data: ffi.LineData,
) -> actor.Next(RendererState(model), RendererMessage) {
  case line_data {
    ffi.Eol(data:) -> {
      let new_state = dispatch_decoded(state, data)
      actor.continue(new_state)
    }
    ffi.Noeol(_data) ->
      // Partial line buffering is handled at the port driver level
      // for {line, N} mode -- we just wait for the complete eol.
      actor.continue(state)
  }
}

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
// Internal: decode and dispatch responses
// ---------------------------------------------------------------------------

fn dispatch_decoded(
  state: RendererState(model),
  bytes: BitArray,
) -> RendererState(model) {
  case proto_decode.decode_message(bytes, state.format) {
    Ok(msg) -> handle_decoded_message(state, msg, bytes)
    Error(_) -> state
  }
}

fn handle_decoded_message(
  state: RendererState(model),
  msg: proto_decode.InboundMessage,
  raw_bytes: BitArray,
) -> RendererState(model) {
  case msg {
    proto_decode.Hello(..) ->
      // Handshake -- nothing to do in test mode
      state
    proto_decode.EventMessage(event) ->
      dispatch_event(state, event)
  }

  // Also check if this is a response to a pending request by
  // extracting type/id from the raw wire data.
  |> check_pending_response(raw_bytes)
}

/// Try to extract query_response / interact_response / etc. from raw wire data.
/// The decoder only returns Hello and EventMessage, but the renderer also
/// sends query_response, interact_response, etc. We need to decode those
/// from the raw wire data using Dynamic.
fn check_pending_response(
  state: RendererState(model),
  raw_bytes: BitArray,
) -> RendererState(model) {
  case decode_response_fields(raw_bytes, state.format) {
    Ok(#(msg_type, req_id, data)) ->
      handle_response(state, msg_type, req_id, data)
    Error(_) -> state
  }
}

fn handle_response(
  state: RendererState(model),
  msg_type: String,
  req_id: String,
  data: Dynamic,
) -> RendererState(model) {
  case dict.get(state.pending, req_id) {
    Error(_) -> state
    Ok(entry) -> {
      let pending = dict.delete(state.pending, req_id)
      let state = RendererState(..state, pending:)

      case msg_type, entry.kind {
        "query_response", PendingFind -> {
          let el = decode_find_response(data)
          process.send(entry.reply, ReplyElement(el))
          state
        }
        "query_response", PendingTree -> {
          process.send(entry.reply, ReplyTree(Some(data)))
          state
        }
        "interact_response", PendingInteract(_action) -> {
          let state = dispatch_response_events(state, data)
          process.send(entry.reply, ReplyOk)
          state
        }
        "tree_hash_response", PendingTreeHash(name) -> {
          let hash = get_string_field(data, "hash", "")
          process.send(entry.reply, ReplyTreeHash(TreeHash(name:, hash:)))
          state
        }
        "screenshot_response", PendingScreenshot(name) -> {
          let hash = get_string_field(data, "hash", "")
          let width = get_int_field(data, "width", 0)
          let height = get_int_field(data, "height", 0)
          let pixels = get_binary_field(data, "rgba")
          process.send(
            entry.reply,
            ReplyScreenshot(Screenshot(
              name:,
              hash:,
              width:,
              height:,
              pixels:,
            )),
          )
          state
        }
        "reset_response", PendingReset -> {
          process.send(entry.reply, ReplyOk)
          state
        }
        _, _ -> {
          // Unknown response type for this pending entry -- ignore
          state
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Internal: event dispatching (Elm loop)
// ---------------------------------------------------------------------------

fn dispatch_event(
  state: RendererState(model),
  event: Event,
) -> RendererState(model) {
  let update_fn = app.get_update(state.app)
  let #(new_model, commands) = update_fn(state.model, event)
  let #(model, _events) =
    command_processor.process_commands(state.app, new_model, commands, 0)
  let view_fn = app.get_view(state.app)
  let new_tree = view_fn(model) |> tree.normalize()

  // Send updated snapshot
  let assert Ok(snapshot_data) =
    proto_encode.encode_snapshot(new_tree, "", state.format)
  ffi.port_command(state.port, snapshot_data)

  RendererState(..state, model:, tree: new_tree)
}

fn dispatch_response_events(
  state: RendererState(model),
  data: Dynamic,
) -> RendererState(model) {
  let events = get_events_list(data)
  list.fold(events, state, fn(acc, event_data) {
    let family = get_dyn_string_field(event_data, "family", "")
    let id = get_dyn_string_field(event_data, "id", "")
    case family {
      "" -> acc
      _ -> {
        let event_dict = dynamic_to_string_dict(event_data)
        case event_decoder.decode_test_event(family, id, event_dict) {
          Ok(event) -> dispatch_event(acc, event)
          Error(_) -> acc
        }
      }
    }
  })
}

// ---------------------------------------------------------------------------
// Internal: selector encoding
// ---------------------------------------------------------------------------

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

fn resolve_local_id(node: Node, target_id: String) -> Option(String) {
  let local = case string.split(node.id, "/") {
    [single] -> single
    parts ->
      case list.last(parts) {
        Ok(last) -> last
        Error(_) -> node.id
      }
  }

  case local == target_id {
    True -> Some(node.id)
    False ->
      list.find_map(node.children, fn(child) {
        case resolve_local_id(child, target_id) {
          Some(id) -> Ok(id)
          None -> Error(Nil)
        }
      })
      |> option.from_result
  }
}

// ---------------------------------------------------------------------------
// Internal: helpers
// ---------------------------------------------------------------------------

fn next_id(
  state: RendererState(model),
) -> #(String, RendererState(model)) {
  let id = "req_" <> int.to_string(state.next_id)
  #(id, RendererState(..state, next_id: state.next_id + 1))
}

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

fn parse_key(key: String) -> Dict(String, String) {
  let parts = string.split(key, "+")
  let #(mods, key_parts) = list.split(parts, list.length(parts) - 1)
  let key_name = case key_parts {
    [k] -> k
    _ -> key
  }

  let modifiers =
    list.fold(mods, dict.new(), fn(acc, m) {
      case m {
        "ctrl" -> dict.insert(acc, "ctrl", "true")
        "shift" -> dict.insert(acc, "shift", "true")
        "alt" -> dict.insert(acc, "alt", "true")
        "logo" -> dict.insert(acc, "logo", "true")
        "command" -> dict.insert(acc, "command", "true")
        _ -> acc
      }
    })

  dict.insert(modifiers, "key", key_name)
}

// ---------------------------------------------------------------------------
// Internal: Dynamic field extraction helpers
// ---------------------------------------------------------------------------

/// Decode response fields (type, id, and full data) from raw wire bytes.
fn decode_response_fields(
  bytes: BitArray,
  format: protocol.Format,
) -> Result(#(String, String, Dynamic), Nil) {
  case format {
    protocol.Json -> decode_response_json(bytes)
    protocol.Msgpack -> decode_response_msgpack(bytes)
  }
}

fn decode_response_json(
  bytes: BitArray,
) -> Result(#(String, String, Dynamic), Nil) {
  case json_decode_dynamic(bytes) {
    Ok(dyn) -> {
      let msg_type = get_dyn_string_field(dyn, "type", "")
      let req_id = get_dyn_string_field(dyn, "id", "")
      case msg_type, req_id {
        "", _ -> Error(Nil)
        _, "" -> Error(Nil)
        _, _ -> Ok(#(msg_type, req_id, dyn))
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn decode_response_msgpack(
  bytes: BitArray,
) -> Result(#(String, String, Dynamic), Nil) {
  case msgpack_decode_dynamic(bytes) {
    Ok(dyn) -> {
      let msg_type = get_dyn_string_field(dyn, "type", "")
      let req_id = get_dyn_string_field(dyn, "id", "")
      case msg_type, req_id {
        "", _ -> Error(Nil)
        _, "" -> Error(Nil)
        _, _ -> Ok(#(msg_type, req_id, dyn))
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn decode_find_response(data: Dynamic) -> Option(Element) {
  case get_dyn_field(data, "data") {
    Ok(node_data) ->
      case is_nil_or_empty(node_data) {
        True -> None
        False -> Some(element.from_node(dynamic_to_node(node_data)))
      }
    Error(_) -> None
  }
}

/// Convert a Dynamic value to a Node (best-effort extraction).
fn dynamic_to_node(data: Dynamic) -> Node {
  let id = get_dyn_string_field(data, "id", "")
  let kind = get_dyn_string_field(data, "type", "")
  node.new(id, kind)
}

/// Convert Dynamic to Dict(String, Dynamic) (best-effort).
fn dynamic_to_string_dict(data: Dynamic) -> Dict(String, Dynamic) {
  case dyn_decode.run(data, dyn_decode.dict(dyn_decode.string, dyn_decode.dynamic)) {
    Ok(d) -> d
    Error(_) -> dict.new()
  }
}

fn get_string_field(data: Dynamic, key: String, default: String) -> String {
  get_dyn_string_field(data, key, default)
}

fn get_int_field(data: Dynamic, key: String, default: Int) -> Int {
  case get_dyn_field(data, key) {
    Ok(val) ->
      case dyn_decode.run(val, dyn_decode.int) {
        Ok(i) -> i
        Error(_) -> default
      }
    Error(_) -> default
  }
}

fn get_binary_field(data: Dynamic, key: String) -> BitArray {
  case get_dyn_field(data, key) {
    Ok(val) ->
      case dyn_decode.run(val, dyn_decode.bit_array) {
        Ok(b) -> b
        Error(_) -> <<>>
      }
    Error(_) -> <<>>
  }
}

fn get_events_list(data: Dynamic) -> List(Dynamic) {
  case get_dyn_field(data, "events") {
    Ok(val) ->
      case dyn_decode.run(val, dyn_decode.list(dyn_decode.dynamic)) {
        Ok(events) -> events
        Error(_) -> []
      }
    Error(_) -> []
  }
}

fn get_dyn_string_field(
  data: Dynamic,
  key: String,
  default: String,
) -> String {
  case get_dyn_field(data, key) {
    Ok(val) ->
      case dyn_decode.run(val, dyn_decode.string) {
        Ok(s) -> s
        Error(_) -> default
      }
    Error(_) -> default
  }
}

fn get_dyn_field(data: Dynamic, key: String) -> Result(Dynamic, Nil) {
  case dyn_decode.run(data, dyn_decode.at([key], dyn_decode.dynamic)) {
    Ok(val) -> Ok(val)
    Error(_) -> Error(Nil)
  }
}

fn is_nil_or_empty(data: Dynamic) -> Bool {
  case dyn_decode.run(data, dyn_decode.string) {
    Ok("") -> True
    Ok("null") -> True
    _ ->
      case
        dyn_decode.run(
          data,
          dyn_decode.dict(dyn_decode.string, dyn_decode.dynamic),
        )
      {
        Ok(d) -> dict.is_empty(d)
        Error(_) ->
          // Check if it's an Erlang nil/undefined
          case dyn_decode.run(data, dyn_decode.optional(dyn_decode.dynamic)) {
            Ok(None) -> True
            _ -> False
          }
      }
  }
}

@external(erlang, "gleam_json_ffi", "decode")
fn json_decode_dynamic(bytes: BitArray) -> Result(Dynamic, Dynamic)

@external(erlang, "toddy_test_renderer_ffi", "msgpack_decode_dynamic")
fn msgpack_decode_dynamic(bytes: BitArray) -> Result(Dynamic, Nil)

@external(erlang, "toddy_test_renderer_ffi", "float_to_string")
fn float_to_string(f: Float) -> String

/// Kill a process (normal exit).
@external(erlang, "toddy_test_renderer_ffi", "send_exit")
fn process_send_exit(pid: process.Pid) -> Nil
