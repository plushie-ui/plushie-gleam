//// Custom widget system.
////
//// Custom widgets are pure Gleam widgets that produce UI via canvas shapes
//// with runtime-managed internal state and event transformation. They
//// sit between the renderer and the app, intercepting events in the
//// scope chain and emitting semantic events.
////
//// ## Defining a widget
////
//// ```gleam
//// import plushie/widget
//// import plushie/canvas/shape
//// import plushie/event.{type Event}
////
//// type StarState { StarState(hover: Int) }
//// type StarProps { StarProps(rating: Int, max: Int) }
////
//// pub fn star_rating_def() -> widget.WidgetDef(StarState, StarProps) {
////   widget.WidgetDef(
////     init: fn() { StarState(hover: 0) },
////     view: view_stars,
////     handle_event: handle_star_event,
////     subscriptions: fn(_, _) { [] },
////     cache_key: option.None,
////   )
//// }
////
//// pub fn star_rating(id: String, props: StarProps) -> Node {
////   widget.build(star_rating_def(), id, props)
//// }
//// ```
////
//// ## How it works
////
//// `build` creates a placeholder canvas node tagged with metadata.
//// During tree normalization, the runtime detects the tag, looks up
//// the widget's state from the registry, calls `view`, and
//// recursively normalizes the output. The normalized tree carries
//// metadata for registry derivation after each view cycle.
////
//// Events flow through the scope chain before reaching `app.update`.
//// Each widget in the chain gets a chance to handle the event:
//// `Ignored` passes through, `Consumed` stops the chain, and
//// `Emit(kind, data)` replaces the event with a CustomWidget event and
//// continues. The runtime fills in `id` and `scope` automatically
//// from the widget's position in the tree.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import plushie/event.{type Event, type EventTarget, EventTarget}
import plushie/node.{type Node, type PropValue, Node}
import plushie/platform
import plushie/prop/a11y.{type A11y}
import plushie/subscription.{type Subscription}

// -- Widget definition -------------------------------------------------------

/// Definition of a widget's behaviour.
///
/// `state` is the widget's internal state (managed by the runtime).
/// `props` is the widget's input from the parent view function.
///
/// For stateless composites, use `simple` or `with_handler` instead
/// of constructing WidgetDef directly.
pub type WidgetDef(state, props) {
  WidgetDef(
    /// Create the initial state for a new widget instance.
    init: fn() -> state,
    /// Produce the widget's node tree from its id, props, and state.
    view: fn(String, props, state) -> Node,
    /// Handle an event. Returns the action and (possibly updated) state.
    handle_event: fn(Event, state) -> #(EventAction, state),
    /// Subscriptions for this widget instance.
    subscriptions: fn(props, state) -> List(Subscription),
    /// Optional cache key derivation for view memoization.
    ///
    /// When `Some(f)`, `f(props, state)` produces a cheap comparison key.
    /// If the key matches the previous render cycle, the normalizer
    /// skips calling `view` and reuses the cached subtree along with
    /// its registry entry. Cross-cycle equality is by `==` on the
    /// returned `Dynamic`; cheap structural representations
    /// (tuples of primitives, small records) work best.
    cache_key: Option(fn(props, state) -> Dynamic),
  )
}

/// Create a stateless view-only widget. Events from child widgets
/// pass through to the app's update (transparent to events).
///
/// ```gleam
/// let labeled_input_def = widget.simple(fn(id, props: InputProps) {
///   ui.column(id, [], [
///     ui.text_(id <> "/label", props.label),
///     ui.text_input(id <> "/input", props.value, []),
///   ])
/// })
/// ```
pub fn simple(view: fn(String, props) -> Node) -> WidgetDef(Nil, props) {
  WidgetDef(
    init: fn() { Nil },
    view: fn(id, props, _state) { view(id, props) },
    handle_event: fn(_event, state) { #(Ignored, state) },
    subscriptions: fn(_, _) { [] },
    cache_key: None,
  )
}

/// Create a stateless widget with an event handler. The handler
/// intercepts events from child widgets and can transform, consume,
/// or ignore them.
///
/// ```gleam
/// let note_card_def = widget.with_handler(
///   fn(id, props: CardProps) {
///     ui.column(id, [], [
///       ui.text_(id <> "/title", props.title),
///       ui.button_(id <> "/open", "Open"),
///     ])
///   },
///   fn(event) {
///     case event {
///       event.Widget(event.Click(target: event.EventTarget(id: "open", ..))) ->
///         widget.Emit("open", dynamic.nil())
///       _ -> widget.Ignored
///     }
///   },
/// )
/// ```
pub fn with_handler(
  view: fn(String, props) -> Node,
  handle_event: fn(Event) -> EventAction,
) -> WidgetDef(Nil, props) {
  WidgetDef(
    init: fn() { Nil },
    view: fn(id, props, _state) { view(id, props) },
    handle_event: fn(event, state) { #(handle_event(event), state) },
    subscriptions: fn(_, _) { [] },
    cache_key: None,
  )
}

/// Result of a widget's event handler.
pub type EventAction {
  /// Not handled: continue to next handler in scope chain.
  Ignored
  /// Captured, no output: stop chain, don't dispatch to app.
  Consumed
  /// Captured with semantic event. The runtime constructs a
  /// CustomWidget event with the widget's id/scope filled in automatically.
  /// `kind` is the event family (e.g., "click", "select", "change").
  /// `data` carries event-specific payload as Dynamic.
  Emit(kind: String, data: Dynamic)
  /// Captured with internal state change only. Like Consumed but
  /// signals that the widget's state was updated (triggers re-render).
  UpdateState
}

/// Emit a string value. Convenience for `Emit(kind, dynamic.string(value))`.
pub fn emit_string(kind: String, value: String) -> EventAction {
  Emit(kind:, data: dynamic.string(value))
}

/// Emit a float value. Convenience for `Emit(kind, dynamic.float(value))`.
pub fn emit_float(kind: String, value: Float) -> EventAction {
  Emit(kind:, data: dynamic.float(value))
}

/// Emit an int value. Convenience for `Emit(kind, dynamic.int(value))`.
pub fn emit_int(kind: String, value: Int) -> EventAction {
  Emit(kind:, data: dynamic.int(value))
}

/// Emit a bool value. Convenience for `Emit(kind, dynamic.bool(value))`.
pub fn emit_bool(kind: String, value: Bool) -> EventAction {
  Emit(kind:, data: dynamic.bool(value))
}

/// Emit with no payload value. Convenience for `Emit(kind, dynamic.nil())`.
pub fn emit_none(kind: String) -> EventAction {
  Emit(kind:, data: dynamic.nil())
}

// -- Receive-side decoders ---------------------------------------------------
//
// Mirrors of the `emit_*` helpers for apps consuming CustomWidget events.
// Use these for single-value payloads. For structured payloads, pass any
// `gleam/dynamic/decode.Decoder` to `decode.run(data, decoder)` directly
// (or have the widget module export its own decoder alongside `def()`).

/// Decode a string payload. Convenience for `decode.run(data, decode.string)`.
pub fn decode_string(data: Dynamic) -> Result(String, List(decode.DecodeError)) {
  decode.run(data, decode.string)
}

/// Decode a float payload. Convenience for `decode.run(data, decode.float)`.
pub fn decode_float(data: Dynamic) -> Result(Float, List(decode.DecodeError)) {
  decode.run(data, decode.float)
}

/// Decode an int payload. Convenience for `decode.run(data, decode.int)`.
pub fn decode_int(data: Dynamic) -> Result(Int, List(decode.DecodeError)) {
  decode.run(data, decode.int)
}

/// Decode a bool payload. Convenience for `decode.run(data, decode.bool)`.
pub fn decode_bool(data: Dynamic) -> Result(Bool, List(decode.DecodeError)) {
  decode.run(data, decode.bool)
}

// -- Placeholder node --------------------------------------------------------

/// Single metadata key for all widget data. Holds a WidgetMeta packed
/// as a PropValue. Stripped during normalization; never reaches the wire.
const widget_meta_key = "__widget__"

/// Packed widget metadata stored under a single meta key.
/// The fields are type-erased PropValues wrapping the original typed
/// values via identity coercion. State is None on initial placeholders
/// (before normalization) and Some after render_placeholder attaches it.
pub opaque type WidgetMeta {
  WidgetMeta(def: PropValue, props: PropValue, state: Option(PropValue))
}

/// Build a placeholder node for a widget.
///
/// The returned node has kind "canvas" and carries metadata props
/// that the runtime uses during normalization to produce the real
/// canvas tree with the widget's current state.
pub fn build(def: WidgetDef(state, props), id: String, props: props) -> Node {
  // Store the def and props in the meta field (not props).
  // Meta is never sent to the renderer or included in tree diffs.
  let wm =
    WidgetMeta(
      def: to_dynamic_prop(def),
      props: to_dynamic_prop(props),
      state: None,
    )
  let meta = dict.from_list([#(widget_meta_key, to_dynamic_prop(wm))])
  Node(id:, kind: "canvas", props: dict.new(), children: [], meta:)
}

/// Standard widget prop keys that are forwarded from the placeholder
/// to the rendered output during normalization. Widget authors don't
/// need to manually forward these.
const standard_widget_props = ["a11y", "event_rate"]

/// Attach accessibility properties to a widget placeholder.
/// These are automatically forwarded to the rendered output during
/// tree normalization; widget authors don't need to handle them.
pub fn set_a11y(node: Node, accessibility: A11y) -> Node {
  Node(
    ..node,
    props: dict.insert(node.props, "a11y", a11y.to_prop_value(accessibility)),
  )
}

/// Attach an event rate limit to a widget placeholder.
/// Forwarded to the rendered output automatically.
///
/// A rate of zero means "track only, never emit": the renderer
/// tracks the event source but suppresses delivery entirely.
pub fn set_event_rate(node: Node, rate: Int) -> Node {
  Node(..node, props: dict.insert(node.props, "event_rate", node.IntVal(rate)))
}

/// Merge standard widget props (a11y, event_rate) from the placeholder
/// into the rendered node's props. Called during normalization.
pub fn merge_standard_props(
  rendered_props: Dict(String, PropValue),
  placeholder_props: Dict(String, PropValue),
) -> Dict(String, PropValue) {
  list.fold(standard_widget_props, rendered_props, fn(props, key) {
    case dict.get(placeholder_props, key) {
      Ok(val) -> dict.insert(props, key, val)
      Error(_) -> props
    }
  })
}

// -- Registry ----------------------------------------------------------------

/// A registry entry for a widget instance. Stores type-erased
/// state and pre-bound closures so the registry can be heterogeneous.
pub type RegistryEntry {
  RegistryEntry(
    /// Produce the widget's node tree given its scoped ID.
    view: fn(String) -> Node,
    /// Handle an event. Returns the action and an updated entry.
    handle_event: fn(Event) -> #(EventAction, RegistryEntry),
    /// Collect subscriptions for this widget instance.
    subscriptions: fn() -> List(Subscription),
    /// The widget's current state as Dynamic (for re-injection during
    /// normalization).
    state: Dynamic,
    /// The widget's props as Dynamic (for re-injection).
    props: Dynamic,
    /// The widget def as Dynamic (for re-injection).
    def: Dynamic,
  )
}

/// The widget registry: maps window-aware widget keys to entries.
pub type Registry =
  Dict(String, RegistryEntry)

/// Create an empty registry.
pub fn empty_registry() -> Registry {
  dict.new()
}

/// Create a registry entry from a typed def, props, and state.
/// The entry captures the concrete types in closures.
pub fn make_entry(
  def: WidgetDef(state, props),
  props: props,
  state: state,
) -> RegistryEntry {
  RegistryEntry(
    view: fn(id) { def.view(id, props, state) },
    handle_event: fn(ev) {
      let #(action, new_state) = def.handle_event(ev, state)
      #(action, make_entry(def, props, new_state))
    },
    subscriptions: fn() { def.subscriptions(props, state) },
    state: coerce(state),
    props: coerce(props),
    def: coerce(def),
  )
}

// -- Normalization support ---------------------------------------------------

/// Check if a node is a widget placeholder (has widget metadata).
pub fn is_placeholder(node: Node) -> Bool {
  dict.has_key(node.meta, widget_meta_key)
}

/// Compute a placeholder's cache_key dep value, if the widget's
/// `WidgetDef` defines one. Uses the existing registry entry's state
/// when present; falls back to a fresh `init()` state for first-time
/// widgets. Returns `None` when the node is not a placeholder, the
/// widget did not opt in to memoisation, or the cache_key call
/// raised.
pub fn placeholder_cache_key(
  node: Node,
  window_id: String,
  scoped_id: String,
  registry: Registry,
) -> Option(Dynamic) {
  case dict.get(node.meta, widget_meta_key) {
    Ok(meta_prop) -> {
      let wm: WidgetMeta = from_dynamic_prop(meta_prop)
      let typed_def: WidgetDef(a, b) = from_dynamic_prop(wm.def)
      case typed_def.cache_key {
        Some(f) -> {
          let typed_props: b = from_dynamic_prop(wm.props)
          let key = widget_key(window_id, scoped_id)
          let typed_state: a = case dict.get(registry, key) {
            Ok(existing) -> coerce_from_dynamic(existing.state)
            Error(_) -> typed_def.init()
          }
          case platform.try_call(fn() { f(typed_props, typed_state) }) {
            Ok(dep) -> Some(dep)
            Error(_) -> None
          }
        }
        None -> None
      }
    }
    Error(_) -> None
  }
}

/// Render a widget placeholder using the registry.
///
/// Returns the rendered + normalized canvas node and an updated
/// registry entry, or None if the node isn't a placeholder or
/// the widget isn't in the registry.
pub fn render_placeholder(
  node: Node,
  window_id: String,
  scoped_id: String,
  local_id: String,
  registry: Registry,
) -> Option(#(Node, RegistryEntry)) {
  case dict.get(node.meta, widget_meta_key) {
    Ok(meta_prop) -> {
      let wm: WidgetMeta = from_dynamic_prop(meta_prop)
      let key = widget_key(window_id, scoped_id)
      // Look up existing state or create initial
      let entry = case dict.get(registry, key) {
        Ok(existing) -> {
          // Update the entry with fresh def and props from the
          // placeholder while keeping existing state
          rebuild_entry(
            from_dynamic_prop(wm.def),
            from_dynamic_prop(wm.props),
            coerce_from_dynamic(existing.state),
          )
        }
        Error(_) -> {
          // New widget: create entry with initial state
          init_entry(from_dynamic_prop(wm.def), from_dynamic_prop(wm.props))
        }
      }

      // Call view with the local (pre-scoped) ID. The view function
      // should think in local IDs; scoping is applied by the caller.
      let rendered = entry.view(local_id)

      // Attach metadata to the rendered node for registry derivation.
      // Use the scoped_id as the node ID (it was already computed by
      // normalize). Keep the rendered node's kind and children.
      let updated_wm =
        WidgetMeta(
          def: wm.def,
          props: wm.props,
          state: Some(to_dynamic_prop(entry.state)),
        )
      let final_meta =
        dict.from_list([#(widget_meta_key, to_dynamic_prop(updated_wm))])
      let final_node = Node(..rendered, id: scoped_id, meta: final_meta)
      Some(#(final_node, entry))
    }
    Error(_) -> None
  }
}

/// Derive the registry from a normalized tree.
///
/// Walks the tree and extracts widget metadata from nodes.
/// Returns a fresh registry with entries for all widgets
/// found in the tree.
pub fn derive_registry(tree: Node) -> Registry {
  derive_from_node(tree, "", dict.new())
}

fn derive_from_node(node: Node, window_id: String, acc: Registry) -> Registry {
  let current_window_id = case node.kind {
    "window" -> node.id
    _ -> window_id
  }

  let acc = case dict.get(node.meta, widget_meta_key) {
    Ok(meta_prop) -> {
      let wm: WidgetMeta = from_dynamic_prop(meta_prop)
      case wm.state {
        Some(state_prop) -> {
          let entry =
            rebuild_entry(
              from_dynamic_prop(wm.def),
              from_dynamic_prop(wm.props),
              from_dynamic_prop(state_prop),
            )
          dict.insert(acc, widget_key(current_window_id, node.id), entry)
        }
        None -> acc
      }
    }
    Error(_) -> acc
  }

  list.fold(node.children, acc, fn(acc, child) {
    derive_from_node(child, current_window_id, acc)
  })
}

// -- Event dispatch ----------------------------------------------------------

/// Result of dispatching an event through the widget chain.
pub type DispatchResult {
  /// Handlers were consulted; Some = event to deliver, None = consumed.
  Dispatched(Option(Event))
  /// No handlers in scope; event was not routed through any widget.
  /// Raw canvas events should reach update/2; widget-internal events
  /// from a widget scope should be auto-consumed at the call site.
  Bypassed(Event)
}

/// Route an event through widget handlers in the scope chain.
///
/// Returns `Dispatched(Some(event))` when handlers were consulted but
/// the event passed through, `Dispatched(None)` when consumed, or
/// `Bypassed(event)` when no handlers existed in the event's scope.
pub fn dispatch_through_widgets(
  registry: Registry,
  ev: Event,
) -> #(DispatchResult, Registry) {
  let target = extract_target(ev)
  let window_id = case target {
    Some(t) -> t.window_id
    None -> ""
  }
  let scope = case target {
    Some(t) -> t.scope
    None -> []
  }
  let ev_id = case target {
    Some(t) -> t.id
    None -> ""
  }

  // Build handler chain: walk scope innermost to outermost
  let chain = build_handler_chain(registry, window_id, scope, ev_id)

  case chain {
    [] -> #(Bypassed(ev), registry)
    _ -> {
      let #(result, registry) = walk_chain(registry, ev, chain)
      #(Dispatched(result), registry)
    }
  }
}

/// Build the handler chain from scope (innermost to outermost).
///
/// For events with empty scope, check if the event target itself
/// is a registered widget (direct-ID fallback for canvas events
/// like press/move/release whose scope is empty but whose target
/// may be a widget).
fn build_handler_chain(
  registry: Registry,
  window_id: String,
  scope: List(String),
  event_id: String,
) -> List(String) {
  let path = strip_window(scope, window_id)
  let chain =
    scope_to_widget_ids(window_id, path)
    |> list.map(fn(id) { widget_key(window_id, id) })
    |> list.filter(fn(id) { dict.has_key(registry, id) })

  case chain {
    [] -> {
      // No parent widgets in scope. Check if the event's
      // target itself is a widget. Reconstruct the full
      // scoped ID: scope (reversed to forward order) + event id.
      let target_id =
        widget_key(window_id, scope_to_id(window_id, path, event_id))
      case dict.has_key(registry, target_id) {
        True -> [target_id]
        False -> []
      }
    }
    _ -> chain
  }
}

/// Drop the trailing window_id from a reversed scope list if present.
/// `make_target` appends window_id to scope; this undoes that so the
/// remaining elements are purely the within-window path.
fn strip_window(scope: List(String), window_id: String) -> List(String) {
  case window_id, list.reverse(scope) {
    "", _ -> scope
    _, [last, ..rest] if last == window_id -> list.reverse(rest)
    _, _ -> scope
  }
}

/// Reconstruct the canonical scoped ID for an event target, matching
/// the form produced by tree normalization: `window#path/path/id` for
/// windowed apps, `path/path/id` otherwise. The scope is innermost-
/// first (window-stripped) as produced by `strip_window`.
///
/// scope_to_id("", ["form"], "submit") => "form/submit"
/// scope_to_id("", [], "picker") => "picker"
/// scope_to_id("main", [], "dimmer") => "main#dimmer"
/// scope_to_id("main", ["content"], "dimmer") => "main#content/dimmer"
fn scope_to_id(window_id: String, path: List(String), id: String) -> String {
  let body = case path {
    [] -> id
    _ -> string.join(list.reverse(path), "/") <> "/" <> id
  }
  case window_id {
    "" -> body
    _ -> window_id <> "#" <> body
  }
}

/// Convert a within-window path (innermost first) to a list of
/// progressively shorter scoped IDs, from innermost to outermost.
/// Each ID is in the canonical form returned by tree normalization.
///
/// scope_to_widget_ids("main", ["child", "parent"])
///   => ["main#parent/child", "main#parent"]
/// scope_to_widget_ids("", ["child", "parent"])
///   => ["parent/child", "parent"]
fn scope_to_widget_ids(window_id: String, path: List(String)) -> List(String) {
  let forward = list.reverse(path)
  build_scope_ids(window_id, forward, [], [])
}

fn build_scope_ids(
  window_id: String,
  parts: List(String),
  prefix: List(String),
  acc: List(String),
) -> List(String) {
  case parts {
    // acc is built by prepending, so the longest (innermost) scoped ID
    // is already first, exactly the order we want (inner to outer).
    [] -> acc
    [part, ..rest] -> {
      let new_prefix = list.append(prefix, [part])
      let body = string.join(new_prefix, "/")
      let scoped_id = case window_id {
        "" -> body
        _ -> window_id <> "#" <> body
      }
      build_scope_ids(window_id, rest, new_prefix, [scoped_id, ..acc])
    }
  }
}

/// Walk the handler chain, dispatching the event to each widget.
/// If a handler raises, log a warning and treat it as Ignored so
/// one misbehaving widget doesn't crash the entire runtime.
fn walk_chain(
  registry: Registry,
  ev: Event,
  chain: List(String),
) -> #(Option(Event), Registry) {
  case chain {
    [] -> #(Some(ev), registry)
    [widget_id, ..rest] -> {
      case dict.get(registry, widget_id) {
        Ok(entry) -> {
          case platform.try_call(fn() { entry.handle_event(ev) }) {
            Ok(#(action, new_entry)) -> {
              let registry = dict.insert(registry, widget_id, new_entry)
              case action {
                Ignored -> walk_chain(registry, ev, rest)
                Consumed -> #(None, registry)
                UpdateState -> #(None, registry)
                Emit(kind:, data:) -> {
                  // Construct the full event with id/scope resolved
                  // from the interception context.
                  let #(window_id, id, scope) =
                    resolve_emit_identity(ev, widget_id)
                  let emitted =
                    event.Widget(event.CustomWidget(
                      kind:,
                      target: EventTarget(window_id:, id:, scope:, full: id),
                      value: dynamic.nil(),
                      data:,
                    ))
                  walk_chain(registry, emitted, rest)
                }
              }
            }
            Error(_) -> {
              platform.log_warning(
                "plushie: widget \""
                <> widget_id
                <> "\" raised in handle_event, treating as Ignored",
              )
              walk_chain(registry, ev, rest)
            }
          }
        }
        Error(_) -> walk_chain(registry, ev, rest)
      }
    }
  }
}

// -- Widget-scoped subscriptions ---------------------------------------------

/// Namespace prefix for widget subscription tags.
const cw_tag_prefix = "__cw:"

/// Collect subscriptions from all widgets in the registry.
///
/// Each subscription's tag is namespaced with the widget's scoped ID
/// so the runtime can route timer events back to the correct widget.
pub fn collect_subscriptions(registry: Registry) -> List(Subscription) {
  dict.fold(registry, [], fn(acc, widget_key, entry) {
    let subs = case platform.try_call(entry.subscriptions) {
      Ok(s) -> s
      Error(reason) -> {
        platform.log_error(
          "plushie: widget subscriptions() crashed for '"
          <> widget_key
          <> "': "
          <> string.inspect(reason),
        )
        []
      }
    }
    let namespaced = list.map(subs, fn(sub) { namespace_tag(sub, widget_key) })
    list.append(acc, namespaced)
  })
}

/// Namespace a subscription's tag for a widget.
/// Only timer subscriptions have user-facing tags that need namespacing.
/// Renderer subscriptions are returned unchanged.
fn namespace_tag(sub: Subscription, widget_key: String) -> Subscription {
  case sub {
    subscription.Every(interval_ms:, tag:) -> {
      let new_tag = cw_tag_prefix <> widget_key <> key_sep <> tag
      subscription.Every(interval_ms:, tag: new_tag)
    }
    subscription.Renderer(..) -> sub
  }
}

/// Check if a subscription tag is namespaced for a widget.
pub fn is_widget_tag(tag: String) -> Bool {
  string.starts_with(tag, cw_tag_prefix)
}

/// Parse a namespaced tag into (widget_id, inner_tag).
/// Returns None if the tag isn't namespaced.
pub fn parse_widget_tag(tag: String) -> Option(#(String, String)) {
  case string.starts_with(tag, cw_tag_prefix) {
    False -> None
    True -> {
      let rest = string.drop_start(tag, string.length(cw_tag_prefix))
      case string.split(rest, key_sep) {
        [widget_key, inner_tag] -> Some(#(widget_key, inner_tag))
        _ -> None
      }
    }
  }
}

/// Route a timer event to the correct widget.
///
/// If the timer tag is namespaced, look up the widget, create a
/// TimerTick with the inner tag, dispatch through the widget's
/// handler, and return the result. Emitted events are dispatched
/// through the scope chain so parent widgets can intercept.
///
/// Returns `#(Some(event), registry)` if the event should reach
/// `app.update`, or `#(None, registry)` if handled internally.
/// For non-widget timers, returns `None`; the caller is
/// responsible for constructing the appropriate TimerTick.
pub fn handle_widget_timer(
  registry: Registry,
  tag: String,
  timestamp: Int,
) -> #(Option(Event), Registry) {
  case parse_widget_tag(tag) {
    None -> #(None, registry)
    Some(#(widget_id, inner_tag)) -> {
      case dict.get(registry, widget_id) {
        Ok(entry) -> {
          let timer_event =
            event.Timer(event.TimerEvent(tag: inner_tag, timestamp:))
          case platform.try_call(fn() { entry.handle_event(timer_event) }) {
            Ok(#(action, new_entry)) -> {
              let registry = dict.insert(registry, widget_id, new_entry)
              case action {
                Ignored -> #(None, registry)
                Consumed -> #(None, registry)
                UpdateState -> #(None, registry)
                Emit(kind:, data:) -> {
                  let #(window_id, id, scope) =
                    resolve_emit_identity(timer_event, widget_id)
                  let emitted =
                    event.Widget(event.CustomWidget(
                      kind:,
                      target: EventTarget(window_id:, id:, scope:, full: id),
                      value: dynamic.nil(),
                      data:,
                    ))
                  let #(result, registry) =
                    dispatch_through_widgets(registry, emitted)
                  case result {
                    Dispatched(ev) -> #(ev, registry)
                    Bypassed(ev) -> #(Some(ev), registry)
                  }
                }
              }
            }
            Error(_) -> {
              platform.log_warning(
                "plushie: widget \""
                <> widget_id
                <> "\" raised in timer handler, ignoring",
              )
              #(None, registry)
            }
          }
        }
        Error(_) -> #(None, registry)
      }
    }
  }
}

// -- Metadata stripping ------------------------------------------------------

/// Resolve the id and scope for an emitted event from the
/// interception context. Matches the Elixir SDK's resolve_emit_identity.
///
/// For widget events with scope: the innermost scope element is the
/// widget's local ID; remaining elements are the parent scope.
/// Resolve the (window_id, id, scope) identity that an emitted
/// CustomWidget event should carry, given the inbound event and the
/// registered widget that produced the Emit.
///
/// The intercepting widget is the source of truth: its registered
/// key identifies the widget unambiguously, even when the inbound
/// event originated at an interactive shape inside the widget (whose
/// scope begins with the widget id) or at the widget's own canvas
/// (whose target id IS the widget). For non-widget events such as
/// timers, the inbound target may be absent entirely.
fn resolve_emit_identity(
  _ev: Event,
  widget_id: String,
) -> #(String, String, List(String)) {
  split_widget_key(widget_id)
}

fn split_widget_key(widget_key: String) -> #(String, String, List(String)) {
  case string.split(widget_key, key_sep) {
    [window_id, scoped_id] -> {
      let #(local, inner_scope) = split_scoped_widget_id(scoped_id)
      // Append the window to scope to match the convention used by
      // `event.make_target` (innermost-first, window last).
      let scope = case window_id {
        "" -> inner_scope
        _ -> list.append(inner_scope, [window_id])
      }
      #(window_id, local, scope)
    }
    _ -> #("", widget_key, [])
  }
}

/// Split a canonical scoped ID into (local_id, inner_scope) where
/// inner_scope is innermost-first and does NOT include the window.
///
/// "main#content/dimmer" -> #("dimmer", ["content"])
/// "main#dimmer"          -> #("dimmer", [])
/// "form/submit"          -> #("submit", ["form"])
/// "dimmer"               -> #("dimmer", [])
fn split_scoped_widget_id(scoped_id: String) -> #(String, List(String)) {
  // Strip the window prefix if present. The window is the segment
  // before the `#`; the rest is the within-window path.
  let path = case string.split_once(scoped_id, "#") {
    Ok(#(_window, rest)) -> rest
    Error(_) -> scoped_id
  }
  let parts = string.split(path, "/")
  case list.reverse(parts) {
    [local, ..parent_parts] -> #(local, parent_parts)
    _ -> #(scoped_id, [])
  }
}

// strip_metadata is no longer needed. Metadata lives in the
// separate `meta` field on Node, which is never included in
// props diffing or wire encoding.

// -- Target extraction -------------------------------------------------------

/// Extract the EventTarget from a scoped event.
///
/// Returns Some(target) for widget, pointer, element, and pane events
/// that carry scope identity. Returns None for events without a target
/// (system events, timer events, key events, etc.).
pub fn extract_target(ev: Event) -> Option(EventTarget) {
  case ev {
    event.Widget(widget_ev) -> Some(widget_event_target(widget_ev))
    _ -> None
  }
}

/// Extract the EventTarget from any WidgetEvent variant.
fn widget_event_target(ev: event.WidgetEvent) -> EventTarget {
  case ev {
    event.Click(target:) -> target
    event.Input(target:, ..) -> target
    event.Submit(target:, ..) -> target
    event.Toggle(target:, ..) -> target
    event.Select(target:, ..) -> target
    event.Slide(target:, ..) -> target
    event.SlideRelease(target:, ..) -> target
    event.Paste(target:, ..) -> target
    event.Scrolled(target:, ..) -> target
    event.Open(target:) -> target
    event.Close(target:) -> target
    event.OptionHovered(target:, ..) -> target
    event.Sort(target:, ..) -> target
    event.KeyBinding(target:, ..) -> target
    event.LinkClicked(target:, ..) -> target
    event.Press(target:, ..) -> target
    event.Release(target:, ..) -> target
    event.Move(target:, ..) -> target
    event.Scroll(target:, ..) -> target
    event.Enter(target:, ..) -> target
    event.Exit(target:, ..) -> target
    event.DoubleClick(target:, ..) -> target
    event.Resize(target:, ..) -> target
    event.Focused(target:) -> target
    event.Blurred(target:) -> target
    event.Drag(target:, ..) -> target
    event.DragEnd(target:, ..) -> target
    event.TransitionComplete(target:, ..) -> target
    event.Status(target:, ..) -> target
    event.PaneResized(target:, ..) -> target
    event.PaneDragged(target:, ..) -> target
    event.PaneClicked(target:, ..) -> target
    event.PaneFocusCycle(target:, ..) -> target
    event.CustomWidget(target:, ..) -> target
    event.WidgetKeyPress(target:, ..) -> target
    event.WidgetKeyRelease(target:, ..) -> target
  }
}

/// Extract the scope from an event.
///
/// Convenience accessor that delegates to `extract_target`.
/// Returns an empty list for events that don't carry scope
/// (system events, timer events, etc.).
pub fn event_scope(ev: Event) -> List(String) {
  case extract_target(ev) {
    Some(t) -> t.scope
    None -> []
  }
}

/// Extract the local widget ID from an event.
///
/// Convenience accessor that delegates to `extract_target`.
/// Returns an empty string for events that don't carry an ID
/// (system events, timer events, etc.).
pub fn event_id(ev: Event) -> String {
  case extract_target(ev) {
    Some(t) -> t.id
    None -> ""
  }
}

/// Extract the window ID from an event.
///
/// Convenience accessor that delegates to `extract_target`.
/// Returns an empty string for events that don't carry a window ID
/// (system events, timer events, etc.).
pub fn event_window_id(ev: Event) -> String {
  case extract_target(ev) {
    Some(t) -> t.window_id
    None -> ""
  }
}

const key_sep = "\u{001F}"

pub fn widget_key(window_id: String, scoped_id: String) -> String {
  window_id <> key_sep <> scoped_id
}

// -- Internal helpers --------------------------------------------------------

/// Store a typed value as a Dynamic PropValue.
fn to_dynamic_prop(value: a) -> PropValue {
  // We use StringVal as a carrier. The actual value is the Dynamic
  // stored via the identity coercion. This is an internal mechanism
  // stripped before wire encoding.
  coerce_to_prop(value)
}

/// Recover a typed value from a Dynamic PropValue.
fn from_dynamic_prop(prop: PropValue) -> a {
  coerce_from_prop(prop)
}

/// Create a new entry from a def with initial state.
fn init_entry(def: a, props: b) -> RegistryEntry {
  // The def and props are Dynamic at this point (recovered from props).
  // We use identity coercion to get back to the typed world.
  let typed_def: WidgetDef(c, b) = coerce(def)
  let state = typed_def.init()
  make_entry(typed_def, props, state)
}

/// Rebuild an entry from erased def, props, and state.
fn rebuild_entry(def: a, props: b, state: c) -> RegistryEntry {
  let typed_def: WidgetDef(c, b) = coerce(def)
  make_entry(typed_def, props, state)
}

/// Identity coercion for internal widget plumbing.
///
/// These bypass the type system to store heterogeneous widget types
/// in a single registry. Safety relies on two invariants:
///
/// 1. coerce_to_prop/coerce_from_prop round-trip: a value stored via
///    to_dynamic_prop in build/render_placeholder is recovered via
///    from_dynamic_prop in derive_registry within the same tree.
///    The WidgetMeta record travels through the tree as a single
///    coerced PropValue under one meta key.
///
/// 2. coerce/coerce_from_dynamic recover values stored by make_entry:
///    the WidgetDef, props, and state are coerced to Dynamic on
///    entry creation and recovered when rebuilding the entry. The types
///    are guaranteed to match because the def is the same object that
///    originally created the state.
///
/// These functions are private. Widget authors never interact with them.
@external(erlang, "plushie_ffi", "identity")
@external(javascript, "../plushie_platform_ffi.mjs", "identity")
fn coerce_to_prop(value: a) -> PropValue

@external(erlang, "plushie_ffi", "identity")
@external(javascript, "../plushie_platform_ffi.mjs", "identity")
fn coerce_from_prop(value: PropValue) -> a

@external(erlang, "plushie_ffi", "identity")
@external(javascript, "../plushie_platform_ffi.mjs", "identity")
fn coerce_from_dynamic(value: Dynamic) -> a

@external(erlang, "plushie_ffi", "identity")
@external(javascript, "../plushie_platform_ffi.mjs", "identity")
fn coerce(value: a) -> b
