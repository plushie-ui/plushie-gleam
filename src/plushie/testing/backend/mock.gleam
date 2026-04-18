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

@target(erlang)
import gleam/dict.{type Dict}
@target(erlang)
import gleam/dynamic.{type Dynamic}
@target(erlang)
import gleam/dynamic/decode as dyn_decode
@target(erlang)
import gleam/list
@target(erlang)
import gleam/option.{type Option, None, Some}
@target(erlang)
import gleam/string
@target(erlang)
import plushie/app.{type App}
@target(erlang)
import plushie/event.{type Event}
@target(erlang)
import plushie/node.{type Node, BoolVal, StringVal}
@target(erlang)
import plushie/testing/backend.{type TestBackend, TestBackend}
@target(erlang)
import plushie/testing/event_decoder
@target(erlang)
import plushie/testing/session.{type TestSession}
@target(erlang)
import plushie/testing/session_pool.{type PoolSubject}
@target(erlang)
import plushie/tree

@target(erlang)
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
    press_key: fn(sess, key) {
      do_interact(
        sess,
        pool,
        "press",
        None,
        dict.from_list([#("combo", node.StringVal(key))]),
      )
    },
    release_key: fn(sess, key) {
      do_interact(
        sess,
        pool,
        "release",
        None,
        dict.from_list([#("combo", node.StringVal(key))]),
      )
    },
    type_key: fn(sess, key) {
      do_interact(
        sess,
        pool,
        "type_key",
        None,
        dict.from_list([#("combo", node.StringVal(key))]),
      )
    },
    canvas_press: fn(sess, id, x, y) {
      do_interact(
        sess,
        pool,
        "canvas_press",
        Some("#" <> id),
        dict.from_list([
          #("x", node.FloatVal(x)),
          #("y", node.FloatVal(y)),
          #("button", node.StringVal("left")),
        ]),
      )
    },
    paste: fn(sess, id, text) {
      do_interact(
        sess,
        pool,
        "paste",
        Some("#" <> id),
        dict.from_list([#("text", node.StringVal(text))]),
      )
    },
    sort: fn(sess, id, column) {
      do_interact(
        sess,
        pool,
        "sort",
        Some("#" <> id),
        dict.from_list([#("column", node.StringVal(column))]),
      )
    },
    canvas_touch_press: fn(sess, id, x, y, finger) {
      do_interact(
        sess,
        pool,
        "canvas_press",
        Some("#" <> id),
        dict.from_list([
          #("x", node.FloatVal(x)),
          #("y", node.FloatVal(y)),
          #("button", node.StringVal("left")),
          #("pointer", node.StringVal("touch")),
          #("finger", node.IntVal(finger)),
        ]),
      )
    },
    canvas_touch_release: fn(sess, id, x, y, finger) {
      do_interact(
        sess,
        pool,
        "canvas_release",
        Some("#" <> id),
        dict.from_list([
          #("x", node.FloatVal(x)),
          #("y", node.FloatVal(y)),
          #("button", node.StringVal("left")),
          #("pointer", node.StringVal("touch")),
          #("finger", node.IntVal(finger)),
        ]),
      )
    },
    canvas_touch_move: fn(sess, id, x, y, finger) {
      do_interact(
        sess,
        pool,
        "canvas_move",
        Some("#" <> id),
        dict.from_list([
          #("x", node.FloatVal(x)),
          #("y", node.FloatVal(y)),
          #("pointer", node.StringVal("touch")),
          #("finger", node.IntVal(finger)),
        ]),
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

@target(erlang)
fn start_pooled(app: App(model, Event), pool: PoolSubject) -> TestSession(model) {
  // If this test process already owns a session from an earlier test
  // (eunit runs tests within a module in one process), unregister the
  // old session first. The renderer marks sessions as "closing" after
  // a reset and rejects new traffic on the same session ID until
  // `session_closed` arrives; the only safe way to re-run is to get a
  // fresh session ID. Unregister removes the pool's owner mapping so
  // the subsequent register call creates a new session.
  case get_pool_session() {
    Ok(#(prev_pool, prev_id)) -> {
      session_pool.unregister(prev_pool, prev_id)
      erase_pool_session()
    }
    Error(_) -> Nil
  }

  let session_id = session_pool.register(pool)
  put_pool_session(pool, session_id)

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

@target(erlang)
fn stop_pooled(pool: PoolSubject) -> Nil {
  case get_pool_session() {
    Ok(#(_pool_ref, session_id)) -> {
      session_pool.unregister(pool, session_id)
      erase_pool_session()
    }
    Error(_) -> Nil
  }
}

@target(erlang)
fn require_pool_session() -> #(PoolSubject, String) {
  case get_pool_session() {
    Ok(pair) -> pair
    Error(_) -> panic as "pooled backend: no pool session; call start first"
  }
}

@target(erlang)
fn do_interact(
  sess: TestSession(model),
  _pool: PoolSubject,
  action: String,
  selector: Option(String),
  payload: Dict(String, node.PropValue),
) -> TestSession(model) {
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

  // Send interact through pool. Intermediate interact_step messages and
  // the final interact_response are forwarded back as process messages.
  let _req_id = session_pool.send_interact(pool_ref, session_id, msg)

  // Drive the interact loop: headless mode emits `interact_step` between
  // iced event batches and blocks waiting for a fresh snapshot before the
  // next batch. Apply each batch locally, then post the new snapshot so
  // the renderer can unblock. Terminates on `interact_response`.
  //
  // Mock mode uses synthetic events for most actions, in which case the
  // renderer emits a single `interact_response` with all events and no
  // intermediate `interact_step`s; this loop still handles that path
  // correctly by exiting on the first (response, ...) message.
  interact_loop(sess, pool_ref, session_id)
}

@target(erlang)
fn interact_loop(
  sess: TestSession(model),
  pool_ref: PoolSubject,
  session_id: String,
) -> TestSession(model) {
  case receive_interact_message(5000) {
    InteractStep(events) -> {
      let new_sess =
        apply_events_and_snapshot(sess, events, pool_ref, session_id)
      interact_loop(new_sess, pool_ref, session_id)
    }
    InteractResponse(events) ->
      apply_events_and_snapshot(sess, events, pool_ref, session_id)
    InteractTimeout -> sess
  }
}

@target(erlang)
/// Apply the events from one interact batch to the local session, then
/// send the resulting tree as a snapshot back to the renderer. The
/// renderer is blocked waiting for this snapshot between interact_steps
/// in headless mode. For mock mode it is a no-op update but remains
/// cheap and keeps behaviour uniform.
fn apply_events_and_snapshot(
  sess: TestSession(model),
  events: List(Dynamic),
  pool_ref: PoolSubject,
  session_id: String,
) -> TestSession(model) {
  let new_sess =
    list.fold(events, sess, fn(acc, event_data) {
      let family = dyn_string_field(event_data, "family", "")
      let id = dyn_string_field(event_data, "id", "")
      case family {
        "" -> acc
        _ -> {
          let event_dict = dyn_to_string_dict(event_data)
          case event_decoder.decode_test_event(family, id, event_dict) {
            Ok(event) -> session.send_event(acc, event)
            Error(_) -> acc
          }
        }
      }
    })

  let snapshot =
    dict.from_list([
      #("type", node.StringVal("snapshot")),
      #("tree", tree_to_prop_value(session.current_tree(new_sess))),
    ])
  session_pool.send_async(pool_ref, session_id, snapshot)
  new_sess
}

// -- Selector encoding --------------------------------------------------------

@target(erlang)
/// Resolve a local ID (e.g. "count") to its full scoped path
/// (e.g. "content/count") by searching the local tree. If the ID
/// already contains "/" (already scoped) or isn't found, return as-is.
fn resolve_scoped_id(current_tree: Node, id: String) -> String {
  // If already window-qualified (contains "#"), use as-is.
  // Otherwise, search the normalized tree for a matching node.
  // The normalized tree has fully-qualified IDs (e.g. "main#panel/form/save")
  // which is what the renderer expects.
  case string.contains(id, "#") {
    True -> id
    False ->
      case tree.find(current_tree, id) {
        Some(nd) -> nd.id
        None ->
          // tree.find doesn't match partial scoped paths (e.g. "panel/form/save"
          // won't match "main#panel/form/save"). Search for a node whose ID
          // ends with "#" <> id.
          case find_by_scoped_suffix(current_tree, "#" <> id) {
            Some(nd) -> nd.id
            None -> id
          }
      }
  }
}

@target(erlang)
fn find_by_scoped_suffix(node: Node, suffix: String) -> Option(Node) {
  case string.ends_with(node.id, suffix) {
    True -> Some(node)
    False ->
      list.find_map(node.children, fn(child) {
        case find_by_scoped_suffix(child, suffix) {
          Some(n) -> Ok(n)
          None -> Error(Nil)
        }
      })
      |> option.from_result
  }
}

@target(erlang)
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

@target(erlang)
fn read_toggle_state(sess: TestSession(model), id: String) -> Bool {
  let current_tree = session.current_tree(sess)
  case tree.find(current_tree, id) {
    Some(nd) ->
      // Checkbox uses "checked", toggler uses "is_toggled"
      case dict.get(nd.props, "checked") {
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

@target(erlang)
fn read_string_prop_from_tree(
  sess: TestSession(model),
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

@target(erlang)
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

@target(erlang)
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

@target(erlang)
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

@target(erlang)
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

@target(erlang)
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

@target(erlang)
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

@target(erlang)
fn dyn_string_field(data: Dynamic, key: String, default: String) -> String {
  case dyn_decode.run(data, dyn_decode.at([key], dyn_decode.string)) {
    Ok(s) -> s
    Error(_) -> default
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

// -- FFI for process dictionary (pool session) --------------------------------

@target(erlang)
@external(erlang, "plushie_test_pooled_ffi", "put_pool_session")
fn put_pool_session(pool: PoolSubject, session_id: String) -> Nil

@target(erlang)
@external(erlang, "plushie_test_pooled_ffi", "get_pool_session")
fn get_pool_session() -> Result(#(PoolSubject, String), Nil)

@target(erlang)
@external(erlang, "plushie_test_pooled_ffi", "erase_pool_session")
fn erase_pool_session() -> Nil

@target(erlang)
/// One interact batch from the renderer. `InteractStep` is an
/// intermediate batch that must be followed by a snapshot back to
/// the renderer; `InteractResponse` is the final batch. `InteractTimeout`
/// indicates the renderer failed to reply in time.
pub type InteractBatch {
  InteractStep(events: List(Dynamic))
  InteractResponse(events: List(Dynamic))
  InteractTimeout
}

@target(erlang)
@external(erlang, "plushie_test_pooled_ffi", "receive_interact_message")
fn receive_interact_message(timeout: Int) -> InteractBatch

@target(erlang)
import plushie/testing/element
