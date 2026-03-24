//// Pooled test backend sharing a single renderer process.
////
//// Each test gets its own session managed by a SessionPool. Wire I/O
//// goes through the shared pool while model, tree, and event dispatch
//// are managed locally. This enables concurrent test execution against
//// one renderer process.
////
//// ## Usage
////
//// Start a pool in test setup:
////
////     let assert Ok(pool) = session_pool.start(
////       session_pool.PoolConfig(..session_pool.default_config(),
////         renderer_path: Some("/path/to/plushie"),
////       ),
////     )
////
//// Create the backend:
////
////     let backend = pooled.backend(pool)

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dyn_decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/node.{type Node, BoolVal, StringVal}
import plushie/testing/backend.{type TestBackend, TestBackend}
import plushie/testing/event_decoder
import plushie/testing/session.{type TestSession}
import plushie/testing/session_pool.{type PoolSubject}
import plushie/tree

/// Create a pooled test backend.
pub fn backend(pool: PoolSubject) -> TestBackend(model) {
  TestBackend(
    start: fn(app) { start_pooled(app, pool) },
    stop: fn(_sess) { stop_pooled(pool) },
    find: fn(sess, id) {
      let #(pool_ref, session_id) = require_pool_session()
      let resolved_id = resolve_scoped_id(session.current_tree(sess), id)
      let sel = encode_selector("#" <> resolved_id)
      let msg =
        dict.from_list([
          #("type", node.StringVal("query")),
          #("target", node.StringVal("find")),
          #("selector", node.DictVal(sel)),
        ])
      case
        session_pool.send_message(pool_ref, session_id, msg, "query_response")
      {
        Ok(data) -> decode_find_data(data)
        Error(_) -> None
      }
    },
    click: fn(sess, id) {
      do_interact(sess, pool, "click", Some("#" <> id), dict.new())
    },
    type_text: fn(sess, id, text) {
      do_interact(
        sess,
        pool,
        "type_text",
        Some("#" <> id),
        dict.from_list([#("text", node.StringVal(text))]),
      )
    },
    submit: fn(sess, id) {
      let value = read_string_prop_from_tree(sess, id, "value")
      do_interact(
        sess,
        pool,
        "submit",
        Some("#" <> id),
        dict.from_list([#("value", node.StringVal(value))]),
      )
    },
    toggle: fn(sess, id) {
      let current = read_toggle_state(sess, id)
      let value = case current {
        True -> node.BoolVal(False)
        False -> node.BoolVal(True)
      }
      do_interact(
        sess,
        pool,
        "toggle",
        Some("#" <> id),
        dict.from_list([#("value", value)]),
      )
    },
    select: fn(sess, id, value) {
      do_interact(
        sess,
        pool,
        "select",
        Some("#" <> id),
        dict.from_list([#("value", node.StringVal(value))]),
      )
    },
    slide: fn(sess, id, value) {
      do_interact(
        sess,
        pool,
        "slide",
        Some("#" <> id),
        dict.from_list([#("value", node.FloatVal(value))]),
      )
    },
    model: fn(sess) { session.model(sess) },
    tree: fn(sess) { session.current_tree(sess) },
    reset: fn(sess) {
      let #(pool_ref, session_id) = require_pool_session()
      let app = session.get_app(sess)

      // Reset the renderer session
      let msg = dict.from_list([#("type", node.StringVal("reset"))])
      case
        session_pool.send_message(pool_ref, session_id, msg, "reset_response")
      {
        Ok(_) -> Nil
        Error(_) -> Nil
      }

      // Re-init app locally
      let new_sess = session.start(app)

      // Send fresh snapshot
      let snapshot =
        dict.from_list([
          #("type", node.StringVal("snapshot")),
          #("tree", tree_to_prop_value(session.current_tree(new_sess))),
        ])
      session_pool.send_async(pool_ref, session_id, snapshot)

      new_sess
    },
    send_event: fn(sess, ev) {
      let new_sess = session.send_event(sess, ev)
      // Sync the updated tree to the renderer so subsequent
      // find queries reflect the new state.
      let #(pool_ref, session_id) = require_pool_session()
      let snapshot =
        dict.from_list([
          #("type", node.StringVal("snapshot")),
          #("tree", tree_to_prop_value(session.current_tree(new_sess))),
        ])
      session_pool.send_async(pool_ref, session_id, snapshot)
      new_sess
    },
  )
}

// -- Internal -----------------------------------------------------------------

fn start_pooled(
  app: App(model, Event),
  pool: PoolSubject,
) -> TestSession(model, Event) {
  // If there's already a session from an earlier test in the same
  // process (eunit runs tests within a module in one process),
  // send a reset to the renderer to clear its state. Then reuse
  // the existing session ID rather than registering a new one.
  let session_id = case get_pool_session() {
    Ok(#(prev_pool, prev_id)) -> {
      let reset_msg = dict.from_list([#("type", node.StringVal("reset"))])
      case
        session_pool.send_message(
          prev_pool,
          prev_id,
          reset_msg,
          "reset_response",
        )
      {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
      prev_id
    }
    Error(_) -> {
      let id = session_pool.register(pool)
      put_pool_session(pool, id)
      id
    }
  }

  let sess = session.start(app)

  // Send initial snapshot to the renderer session
  let snapshot =
    dict.from_list([
      #("type", node.StringVal("snapshot")),
      #("tree", tree_to_prop_value(session.current_tree(sess))),
    ])
  session_pool.send_async(pool, session_id, snapshot)

  sess
}

fn stop_pooled(pool: PoolSubject) -> Nil {
  case get_pool_session() {
    Ok(#(_pool_ref, session_id)) -> {
      session_pool.unregister(pool, session_id)
      erase_pool_session()
    }
    Error(_) -> Nil
  }
}

fn require_pool_session() -> #(PoolSubject, String) {
  case get_pool_session() {
    Ok(pair) -> pair
    Error(_) -> panic as "pooled backend: no pool session -- call start first"
  }
}

fn do_interact(
  sess: TestSession(model, Event),
  _pool: PoolSubject,
  action: String,
  selector: Option(String),
  payload: Dict(String, node.PropValue),
) -> TestSession(model, Event) {
  let #(pool_ref, session_id) = require_pool_session()
  let current_tree = session.current_tree(sess)
  let sel = case selector {
    Some("#" <> id) ->
      encode_selector("#" <> resolve_scoped_id(current_tree, id))
    Some(s) -> encode_selector(s)
    None -> dict.new()
  }

  let msg =
    dict.from_list([
      #("type", node.StringVal("interact")),
      #("action", node.StringVal(action)),
      #("selector", node.DictVal(sel)),
      #("payload", node.DictVal(payload)),
    ])

  // Send interact through pool (blocking for response)
  let _req_id = session_pool.send_interact(pool_ref, session_id, msg)

  // Wait for interact_response (which comes as a process message)
  let events = wait_for_interact_response(5000)

  // Process the events through the local Elm loop
  dispatch_events(sess, events)
}

fn dispatch_events(
  sess: TestSession(model, Event),
  events: List(Dynamic),
) -> TestSession(model, Event) {
  list.fold(events, sess, fn(acc, event_data) {
    let family = dyn_string_field(event_data, "family", "")
    let id = dyn_string_field(event_data, "id", "")
    case family {
      "" -> acc
      _ -> {
        let event_dict = dyn_to_string_dict(event_data)
        case event_decoder.decode_test_event(family, id, event_dict) {
          Ok(event) -> {
            let new_sess = session.send_event(acc, event_to_msg(event))

            // Send snapshot after each event (matches production behaviour)
            let #(pool_ref, session_id) = require_pool_session()
            let snapshot =
              dict.from_list([
                #("type", node.StringVal("snapshot")),
                #("tree", tree_to_prop_value(session.current_tree(new_sess))),
              ])
            session_pool.send_async(pool_ref, session_id, snapshot)

            new_sess
          }
          Error(_) -> acc
        }
      }
    }
  })
}

// -- Selector encoding --------------------------------------------------------

/// Resolve a local ID (e.g. "count") to its full scoped path
/// (e.g. "content/count") by searching the local tree. If the ID
/// already contains "/" (already scoped) or isn't found, return as-is.
fn resolve_scoped_id(current_tree: Node, id: String) -> String {
  case string.contains(id, "/") {
    True -> id
    False ->
      case tree.find(current_tree, id) {
        Some(nd) -> nd.id
        None -> id
      }
  }
}

fn encode_selector(selector: String) -> Dict(String, node.PropValue) {
  case selector {
    "#" <> id ->
      dict.from_list([
        #("by", StringVal("id")),
        #("value", StringVal(id)),
      ])
    _ ->
      dict.from_list([
        #("by", StringVal("text")),
        #("value", StringVal(selector)),
      ])
  }
}

// -- Tree helpers -------------------------------------------------------------

fn read_toggle_state(sess: TestSession(model, Event), id: String) -> Bool {
  let current_tree = session.current_tree(sess)
  case tree.find(current_tree, id) {
    Some(nd) ->
      case dict.get(nd.props, "is_checked") {
        Ok(BoolVal(v)) -> v
        _ ->
          case dict.get(nd.props, "is_toggled") {
            Ok(BoolVal(v)) -> v
            _ -> False
          }
      }
    None -> False
  }
}

fn read_string_prop_from_tree(
  sess: TestSession(model, Event),
  id: String,
  key: String,
) -> String {
  let current_tree = session.current_tree(sess)
  case tree.find(current_tree, id) {
    Some(nd) ->
      case dict.get(nd.props, key) {
        Ok(StringVal(s)) -> s
        _ -> ""
      }
    None -> ""
  }
}

fn tree_to_prop_value(nd: Node) -> node.PropValue {
  node.DictVal(
    dict.from_list([
      #("id", StringVal(nd.id)),
      #("type", StringVal(nd.kind)),
      #("props", node.DictVal(nd.props)),
      #("children", node.ListVal(list.map(nd.children, tree_to_prop_value))),
    ]),
  )
}

// -- Find response decoding ---------------------------------------------------

fn decode_find_data(raw: Dynamic) -> Option(element.Element) {
  case dyn_decode.run(raw, dyn_decode.at(["data"], dyn_decode.dynamic)) {
    Ok(data) ->
      case is_nil_or_empty(data) {
        True -> None
        False -> {
          let id = dyn_string_field(data, "id", "")
          let kind = dyn_string_field(data, "type", "")
          let props = decode_props(data)
          let children = decode_children(data)
          Some(element.from_node(
            node.new(id, kind)
            |> node.with_props(dict.to_list(props))
            |> node.with_children(children),
          ))
        }
      }
    Error(_) -> None
  }
}

fn decode_props(data: Dynamic) -> Dict(String, node.PropValue) {
  case
    dyn_decode.run(
      data,
      dyn_decode.at(
        ["props"],
        dyn_decode.dict(dyn_decode.string, dyn_decode.dynamic),
      ),
    )
  {
    Ok(raw_dict) ->
      dict.map_values(raw_dict, fn(_k, v) { decode_prop_value(v) })
    Error(_) -> dict.new()
  }
}

fn decode_prop_value(raw: Dynamic) -> node.PropValue {
  case dyn_decode.run(raw, dyn_decode.string) {
    Ok(s) -> node.StringVal(s)
    Error(_) ->
      case dyn_decode.run(raw, dyn_decode.float) {
        Ok(f) -> node.FloatVal(f)
        Error(_) ->
          case dyn_decode.run(raw, dyn_decode.int) {
            Ok(i) -> node.IntVal(i)
            Error(_) ->
              case dyn_decode.run(raw, dyn_decode.bool) {
                Ok(b) -> node.BoolVal(b)
                Error(_) -> node.StringVal("")
              }
          }
      }
  }
}

fn decode_children(data: Dynamic) -> List(Node) {
  case
    dyn_decode.run(
      data,
      dyn_decode.at(["children"], dyn_decode.list(dyn_decode.dynamic)),
    )
  {
    Ok(children_list) ->
      list.filter_map(children_list, fn(child) {
        let id = dyn_string_field(child, "id", "")
        let kind = dyn_string_field(child, "type", "")
        case id {
          "" -> Error(Nil)
          _ ->
            Ok(
              node.new(id, kind)
              |> node.with_props(dict.to_list(decode_props(child))),
            )
        }
      })
    Error(_) -> []
  }
}

fn is_nil_or_empty(data: Dynamic) -> Bool {
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

// -- Dynamic helpers ----------------------------------------------------------

fn dyn_string_field(data: Dynamic, key: String, default: String) -> String {
  case dyn_decode.run(data, dyn_decode.at([key], dyn_decode.string)) {
    Ok(s) -> s
    Error(_) -> default
  }
}

fn dyn_to_string_dict(data: Dynamic) -> Dict(String, Dynamic) {
  case
    dyn_decode.run(data, dyn_decode.dict(dyn_decode.string, dyn_decode.dynamic))
  {
    Ok(d) -> d
    Error(_) -> dict.new()
  }
}

// -- FFI for process dictionary (pool session) --------------------------------

@external(erlang, "plushie_test_pooled_ffi", "put_pool_session")
fn put_pool_session(pool: PoolSubject, session_id: String) -> Nil

@external(erlang, "plushie_test_pooled_ffi", "get_pool_session")
fn get_pool_session() -> Result(#(PoolSubject, String), Nil)

@external(erlang, "plushie_test_pooled_ffi", "erase_pool_session")
fn erase_pool_session() -> Nil

@external(erlang, "plushie_test_pooled_ffi", "wait_for_interact_response")
fn wait_for_interact_response(timeout: Int) -> List(Dynamic)

/// Cast Event to msg for simple apps where msg = Event.
@external(erlang, "plushie_test_ffi", "identity")
fn event_to_msg(value: Event) -> msg

import plushie/testing/element
