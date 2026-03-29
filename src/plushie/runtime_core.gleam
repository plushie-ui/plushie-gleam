//// Shared pure functions used by both BEAM and JS runtimes.
////
//// These functions contain the core logic for the Elm update loop:
//// event coalescing, subscription key generation, window detection,
//// window prop extraction, and Event -> msg mapping.
////
//// Extracting these into a shared module eliminates duplication
//// between runtime.gleam (OTP actor) and runtime_web.gleam
//// (callback-driven JS loop).

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import plushie/app.{type App}
import plushie/widget
import plushie/event.{type Event}
import plushie/node.{type Node, type PropValue}
import plushie/subscription.{type Subscription}

// -- Event coalescing ---------------------------------------------------------

/// Determine the coalesce key for an event, if coalescable.
///
/// High-frequency events (mouse moves, sensor resizes) are deferred
/// and only the latest value per key is kept. Returns None for
/// events that should be dispatched immediately.
pub fn coalesce_key(ev: Event) -> Option(String) {
  case ev {
    event.MouseMoved(..) -> Some("mouse_moved")
    event.SensorResize(window_id:, id:, ..) ->
      Some("sensor_resize:" <> window_id <> ":" <> id)
    _ -> None
  }
}

// -- Subscription keys --------------------------------------------------------

/// Convert a Subscription to a unique string key for diffing.
///
/// Timer subscriptions are keyed by interval + tag. Renderer
/// subscriptions are keyed by kind + tag.
pub fn subscription_key_string(sub: Subscription) -> String {
  let key = subscription.key(sub)
  case key {
    subscription.TimerKey(interval_ms:, tag:) ->
      "timer:" <> int.to_string(interval_ms) <> ":" <> tag
    subscription.RendererKey(kind:, tag:) -> "renderer:" <> kind <> ":" <> tag
  }
}

// -- Window detection ---------------------------------------------------------

/// Detect window nodes in the tree.
///
/// Searches the entire tree recursively, matching the renderer's
/// behavior. Nested window nodes inside containers or layout
/// widgets are properly detected.
pub fn detect_windows(tree_node: Node) -> Set(String) {
  collect_window_ids(tree_node, [])
  |> set.from_list()
}

fn collect_window_ids(node: Node, acc: List(String)) -> List(String) {
  let acc = case node.kind {
    "window" -> [node.id, ..acc]
    _ -> acc
  }
  list.fold(node.children, acc, fn(a, child) { collect_window_ids(child, a) })
}

/// Window prop keys tracked for lifecycle sync. When a window node
/// has any of these props and they change, an update op is sent.
pub const window_prop_keys = [
  "title", "size", "width", "height", "position", "min_size", "max_size",
  "maximized", "fullscreen", "visible", "resizable", "closeable", "minimizable",
  "decorations", "transparent", "blur", "level", "exit_on_close_request",
  "scale_factor",
]

/// Extract the tracked window props from a window node found in the tree.
pub fn extract_window_props(
  tree_node: Node,
  window_id: String,
) -> Dict(String, PropValue) {
  case find_window_node(tree_node, window_id) {
    Some(win) ->
      dict.filter(win.props, fn(key, _val) {
        list.contains(window_prop_keys, key)
      })
    None -> dict.new()
  }
}

/// Recursively search the tree for a window node with the given ID.
pub fn find_window_node(tree_node: Node, window_id: String) -> Option(Node) {
  case tree_node.kind, tree_node.id {
    "window", id if id == window_id -> Some(tree_node)
    _, _ -> find_window_in_children(tree_node.children, window_id)
  }
}

fn find_window_in_children(
  children: List(Node),
  window_id: String,
) -> Option(Node) {
  case children {
    [] -> None
    [child, ..rest] ->
      case find_window_node(child, window_id) {
        Some(node) -> Some(node)
        None -> find_window_in_children(rest, window_id)
      }
  }
}

// -- Event -> msg mapping -----------------------------------------------------

/// Map a wire Event to the app's msg type.
///
/// For `simple()` apps (on_event=None), msg is Event and we coerce
/// directly. For `application()` apps, the on_event callback maps
/// Event -> msg.
pub fn map_event(app: App(model, msg), event: Event) -> msg {
  case app.get_on_event(app) {
    Some(mapper) -> mapper(event)
    None -> coerce_event(event)
  }
}

/// Identity coercion for simple() apps where msg = Event.
///
/// This is safe because the only code path that reaches here is
/// when on_event is None, which only happens via simple() where
/// the type parameter msg is instantiated to Event.
@external(erlang, "plushie_ffi", "identity")
@external(javascript, "../plushie_platform_ffi.mjs", "identity")
fn coerce_event(event: Event) -> msg

// -- Canvas dispatch resolution -----------------------------------------------

/// Resolve a canvas widget dispatch result into an optional event
/// for the app. Canvas-internal events that passed through widget
/// handlers without being intercepted are auto-consumed so they
/// don't leak to the app's update function.
///
/// - `Dispatched(None)` -- consumed by a handler
/// - `Dispatched(Some(ev))` -- passed through; auto-consume if
///   canvas-internal, deliver otherwise
/// - `Bypassed(ev)` -- no handlers in scope; always deliver (raw
///   canvas events that aren't wrapped in a canvas widget)
pub fn resolve_dispatch(
  result: widget.DispatchResult,
) -> Option(Event) {
  case result {
    widget.Dispatched(None) -> None
    widget.Dispatched(Some(ev)) ->
      case event.is_canvas_internal(ev) {
        True -> None
        False -> Some(ev)
      }
    widget.Bypassed(ev) -> Some(ev)
  }
}
