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
import plushie/event.{type Event, EventTarget}
import plushie/node.{type Node, type PropValue}
import plushie/subscription.{type Subscription}
import plushie/widget

// -- Runtime tuning -----------------------------------------------------------

/// Maximum synchronous `Command.dispatch` chain depth before the
/// runtime guard fires.
///
/// `Command.dispatch` schedules a follow-up msg back through the
/// runtime; a pathological update that keeps returning another
/// dispatch would fill the mailbox (BEAM) or pump the microtask
/// queue (JS) indefinitely. Past this cap, the runtime drops the
/// command and emits a typed `DispatchLoopExceeded` diagnostic so
/// the loop is visible.
pub const dispatch_depth_limit: Int = 100

/// Short human-readable rendering of a typed diagnostic variant,
/// used for log lines. Matches the tag the renderer emits on the
/// wire so log scraping and telemetry stay consistent.
pub fn describe_diagnostic(diag: event.Diagnostic) -> String {
  case diag {
    event.DuplicateId(id:, ..) -> "duplicate_id: " <> id
    event.EmptyId(type_name:) -> "empty_id: " <> type_name
    event.MultipleTopLevelWindows(..) -> "multiple_top_level_windows"
    event.UnknownWindow(window_id:, subscription_tag:) ->
      "unknown_window: subscription "
      <> subscription_tag
      <> " targets "
      <> window_id
    event.UnrecognizedWidgetPlaceholder(id:) ->
      "unrecognized_widget_placeholder: " <> id
    event.TreeDepthExceeded(id:, ..) -> "tree_depth_exceeded: " <> id
    event.TooManyDuplicates(..) -> "too_many_duplicates"
    event.WidgetIdInvalid(reason:, type_name:, id:, ..) ->
      "widget_id_invalid: " <> type_name <> " " <> id <> " (" <> reason <> ")"
    event.MissingAccessibleName(type_name:, id:) ->
      "missing_accessible_name: " <> type_name <> " " <> id
    event.A11yRefUnresolved(id:, key:, ..) ->
      "a11y_ref_unresolved: " <> id <> " " <> key
    event.PropRangeExceeded(id:, prop:, ..) ->
      "prop_range_exceeded: " <> id <> " prop " <> prop
    event.PropTypeMismatch(id:, prop:, ..) ->
      "prop_type_mismatch: " <> id <> " prop " <> prop
    event.PropUnknown(id:, prop:, ..) ->
      "prop_unknown: " <> id <> " prop " <> prop
    event.ContentLengthExceeded(id:, field:, ..) ->
      "content_length_exceeded: " <> id <> "." <> field
    event.FontCacheCapExceeded(..) -> "font_cache_cap_exceeded"
    event.FontCapExceeded(..) -> "font_cap_exceeded"
    event.FontFamilyNotFound(family:) -> "font_family_not_found: " <> family
    event.InvalidSettings(detail:) -> "invalid_settings: " <> detail
    event.RequiredWidgetsMissing(..) -> "required_widgets_missing"
    event.WidgetPanic(id:, type_name:, label:) ->
      "widget_panic: " <> type_name <> " " <> id <> " in " <> label
    event.SvgParseError(id:, ..) -> "svg_parse_error: " <> id
    event.SvgDecodeTimeout(id:, ..) -> "svg_decode_timeout: " <> id
    event.DashCacheCapExceeded(..) -> "dash_cache_cap_exceeded"
    event.EmitterCoalesceCapExceeded(..) -> "emitter_coalesce_cap_exceeded"
    event.WidgetIdTypeCollision(id:, ..) -> "widget_id_type_collision: " <> id
    event.ViewPanicked(message:, ..) -> "view_panicked: " <> message
    event.UpdatePanicked(message:, ..) -> "update_panicked: " <> message
    event.UnknownMessageType(msg_type:) -> "unknown_message_type: " <> msg_type
    event.DispatchLoopExceeded(..) -> "dispatch_loop_exceeded"
    event.BufferOverflow(..) -> "buffer_overflow"
  }
}

// -- Event coalescing ---------------------------------------------------------

/// Determine the coalesce key for an event, if coalescable.
///
/// High-frequency events (mouse moves, sensor resizes) are deferred
/// and only the latest value per key is kept. Returns None for
/// events that should be dispatched immediately.
pub fn coalesce_key(ev: Event) -> Option(String) {
  case ev {
    event.Widget(event.Move(target: EventTarget(scope: [], ..), ..)) ->
      Some("pointer_move")
    event.Widget(event.Resize(target: EventTarget(window_id:, id:, ..), ..)) ->
      Some("resize:" <> window_id <> ":" <> id)
    _ -> None
  }
}

// -- Subscription keys --------------------------------------------------------

/// Convert a Subscription to a unique string key for diffing.
///
/// Timer subscriptions are keyed by interval + tag. Renderer
/// subscriptions are keyed by kind + window_id.
pub fn subscription_key_string(sub: Subscription) -> String {
  let key = subscription.key(sub)
  case key {
    subscription.TimerKey(interval_ms:, tag:) ->
      "timer:" <> int.to_string(interval_ms) <> ":" <> tag
    subscription.RendererKey(kind:, window_id:) ->
      case window_id {
        option.None -> "renderer:" <> kind
        option.Some(wid) -> "renderer:" <> kind <> ":" <> wid
      }
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

/// Derive both the widget registry and window set from a single tree walk.
///
/// Prefer using the registry and windows returned by
/// `tree.normalize_view` / `tree.normalize_with_memo` which accumulate
/// both during normalization at no extra cost. This function exists
/// for cases where only a pre-normalized tree is available.
pub fn derive_all(tree_node: Node) -> #(widget.Registry, Set(String)) {
  let registry = widget.derive_registry(tree_node)
  let windows = detect_windows(tree_node)
  #(registry, windows)
}

/// Window prop keys tracked for lifecycle sync. When a window node
/// has any of these props and they change, an update op is sent.
pub const window_prop_keys = [
  "title", "size", "width", "height", "position", "min_size", "max_size",
  "maximized", "fullscreen", "visible", "resizable", "closeable", "minimizable",
  "decorations", "transparent", "blur", "level", "exit_on_close_request",
  "scale_factor", "theme",
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
/// - `Dispatched(None)`: consumed by a handler
/// - `Dispatched(Some(ev))`: passed through; auto-consume if
///   event passed through all handlers
/// - `Bypassed(ev)`: no handlers in scope; always deliver
pub fn resolve_dispatch(result: widget.DispatchResult) -> Option(Event) {
  case result {
    widget.Dispatched(None) -> None
    widget.Dispatched(Some(ev)) -> Some(ev)
    widget.Bypassed(ev) -> Some(ev)
  }
}
