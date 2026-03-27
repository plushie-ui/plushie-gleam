//// Canvas widget extension system.
////
//// Canvas widgets are pure Gleam widgets that render via canvas shapes
//// with runtime-managed internal state and event transformation. They
//// sit between the renderer and the app, intercepting events in the
//// scope chain and emitting semantic events.
////
//// ## Defining a canvas widget
////
//// ```gleam
//// import plushie/canvas_widget
//// import plushie/canvas/shape
//// import plushie/event.{type Event}
////
//// type StarState { StarState(hover: Int) }
//// type StarProps { StarProps(rating: Int, max: Int) }
////
//// pub fn star_rating_def() -> canvas_widget.CanvasWidgetDef(StarState, StarProps) {
////   canvas_widget.CanvasWidgetDef(
////     init: fn() { StarState(hover: 0) },
////     render: render_stars,
////     handle_event: handle_star_event,
////     subscriptions: fn(_, _) { [] },
////   )
//// }
////
//// pub fn star_rating(id: String, props: StarProps) -> Node {
////   canvas_widget.build(star_rating_def(), id, props)
//// }
//// ```
////
//// ## How it works
////
//// `build` creates a placeholder canvas node tagged with metadata.
//// During tree normalization, the runtime detects the tag, looks up
//// the widget's state from the registry, calls `render`, and
//// recursively normalizes the output. The normalized tree carries
//// metadata for registry derivation after each render cycle.
////
//// Events flow through the scope chain before reaching `app.update`.
//// Each canvas widget in the chain gets a chance to handle the event:
//// `Ignored` passes through, `Consumed` stops the chain, and
//// `Emit(kind, data)` replaces the event with a WidgetEvent and
//// continues. The runtime fills in `id` and `scope` automatically
//// from the widget's position in the tree.

import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import plushie/event.{type Event}
import plushie/node.{type Node, type PropValue, Node}
import plushie/platform
import plushie/subscription.{type Subscription}

// -- Canvas widget definition ------------------------------------------------

/// Definition of a canvas widget's behaviour.
///
/// `state` is the widget's internal state (managed by the runtime).
/// `props` is the widget's input from the parent view function.
pub type CanvasWidgetDef(state, props) {
  CanvasWidgetDef(
    /// Create the initial state for a new widget instance.
    init: fn() -> state,
    /// Render the widget to a canvas node tree.
    render: fn(String, props, state) -> Node,
    /// Handle an event. Returns the action and (possibly updated) state.
    handle_event: fn(Event, state) -> #(EventAction, state),
    /// Subscriptions for this widget instance.
    subscriptions: fn(props, state) -> List(Subscription),
  )
}

/// Result of a canvas widget's event handler.
pub type EventAction {
  /// Not handled -- continue to next handler in scope chain.
  Ignored
  /// Captured, no output -- stop chain, don't dispatch to app.
  Consumed
  /// Captured with semantic event. The runtime constructs a
  /// WidgetEvent with the widget's id/scope filled in automatically.
  /// `kind` is the event family (e.g., "click", "select", "change").
  /// `data` carries event-specific payload as Dynamic.
  Emit(kind: String, data: Dynamic)
  /// Captured with internal state change only. Like Consumed but
  /// signals that the widget's state was updated (triggers re-render).
  UpdateState
}

// -- Placeholder node --------------------------------------------------------

/// Metadata prop key marking a node as a canvas widget placeholder.
/// Stripped during normalization; never reaches the wire.
const meta_key = "__canvas_widget__"

/// Metadata prop key carrying the widget's encoded props.
const props_key = "__canvas_widget_props__"

/// Metadata prop key carrying the widget's state (post-normalization).
const state_key = "__canvas_widget_state__"

/// Build a placeholder node for a canvas widget.
///
/// The returned node has kind "canvas" and carries metadata props
/// that the runtime uses during normalization to render the real
/// canvas tree with the widget's current state.
pub fn build(
  def: CanvasWidgetDef(state, props),
  id: String,
  props: props,
) -> Node {
  // Store the def and props in the meta field (not props).
  // Meta is never sent to the renderer or included in tree diffs.
  let meta =
    dict.from_list([
      #(meta_key, to_dynamic_prop(def)),
      #(props_key, to_dynamic_prop(props)),
    ])
  Node(id:, kind: "canvas", props: dict.new(), children: [], meta:)
}

// -- Registry ----------------------------------------------------------------

/// A registry entry for a canvas widget instance. Stores type-erased
/// state and pre-bound closures so the registry can be heterogeneous.
pub type RegistryEntry {
  RegistryEntry(
    /// Render the widget given its scoped ID. Returns a canvas node tree.
    render: fn(String) -> Node,
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

/// The canvas widget registry: maps window-aware widget keys to entries.
pub type Registry =
  Dict(String, RegistryEntry)

/// Create an empty registry.
pub fn empty_registry() -> Registry {
  dict.new()
}

/// Create a registry entry from a typed def, props, and state.
/// The entry captures the concrete types in closures.
pub fn make_entry(
  def: CanvasWidgetDef(state, props),
  props: props,
  state: state,
) -> RegistryEntry {
  RegistryEntry(
    render: fn(id) { def.render(id, props, state) },
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

/// Check if a node is a canvas widget placeholder (has metadata props).
pub fn is_placeholder(node: Node) -> Bool {
  dict.has_key(node.meta, meta_key)
}

/// Render a canvas widget placeholder using the registry.
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
  case dict.get(node.meta, meta_key), dict.get(node.meta, props_key) {
    Ok(def_prop), Ok(props_prop) -> {
      let key = widget_key(window_id, scoped_id)
      // Look up existing state or create initial
      let entry = case dict.get(registry, key) {
        Ok(existing) -> {
          // Update the entry with fresh def and props from the
          // placeholder while keeping existing state
          rebuild_entry(
            from_dynamic_prop(def_prop),
            from_dynamic_prop(props_prop),
            coerce_from_dynamic(existing.state),
          )
        }
        Error(_) -> {
          // New widget: create entry with initial state
          let def = from_dynamic_prop(def_prop)
          let props = from_dynamic_prop(props_prop)
          init_entry(def, props)
        }
      }

      // Render with the local (pre-scoped) ID. The render function
      // should think in local IDs; scoping is applied by the caller.
      let rendered = entry.render(local_id)

      // Attach metadata to the rendered node for registry derivation.
      // Use the scoped_id as the node ID (it was already computed by
      // normalize). Keep the rendered node's kind and children.
      let widget_meta =
        dict.from_list([
          #(meta_key, def_prop),
          #(props_key, props_prop),
          #(state_key, to_dynamic_prop(entry.state)),
        ])
      let final_node = Node(..rendered, id: scoped_id, meta: widget_meta)
      Some(#(final_node, entry))
    }
    _, _ -> None
  }
}

/// Derive the registry from a normalized tree.
///
/// Walks the tree and extracts canvas widget metadata from nodes.
/// Returns a fresh registry with entries for all canvas widgets
/// found in the tree.
pub fn derive_registry(tree: Node) -> Registry {
  derive_from_node(tree, "", dict.new())
}

fn derive_from_node(node: Node, window_id: String, acc: Registry) -> Registry {
  let current_window_id = case node.kind {
    "window" -> node.id
    _ -> window_id
  }

  let acc = case
    dict.get(node.meta, meta_key),
    dict.get(node.meta, props_key),
    dict.get(node.meta, state_key)
  {
    Ok(def_prop), Ok(props_prop), Ok(state_prop) -> {
      let entry =
        rebuild_entry(
          from_dynamic_prop(def_prop),
          from_dynamic_prop(props_prop),
          from_dynamic_prop(state_prop),
        )
      dict.insert(acc, widget_key(current_window_id, node.id), entry)
    }
    _, _, _ -> acc
  }

  list.fold(node.children, acc, fn(acc, child) {
    derive_from_node(child, current_window_id, acc)
  })
}

// -- Event dispatch ----------------------------------------------------------

/// Route an event through canvas widget handlers in the scope chain.
///
/// Returns `#(Some(event), registry)` if the event should reach
/// `app.update`, or `#(None, registry)` if consumed. The registry
/// is returned with any state updates from handlers.
pub fn dispatch_through_widgets(
  registry: Registry,
  ev: Event,
) -> #(Option(Event), Registry) {
  let window_id = extract_window_id(ev)
  let scope = extract_scope(ev)
  let event_id = extract_id(ev)

  // Build handler chain: walk scope innermost to outermost
  let chain = build_handler_chain(registry, window_id, scope, event_id)

  case chain {
    [] -> #(Some(ev), registry)
    _ -> walk_chain(registry, ev, chain)
  }
}

/// Build the handler chain from scope (innermost to outermost).
///
/// For events with empty scope, check if the event target itself
/// is a registered canvas widget (direct-ID fallback for canvas
/// events like press/move/release whose scope is empty but whose
/// target may be a canvas widget).
fn build_handler_chain(
  registry: Registry,
  window_id: String,
  scope: List(String),
  event_id: String,
) -> List(String) {
  let chain =
    scope_to_widget_ids(scope)
    |> list.map(fn(id) { widget_key(window_id, id) })
    |> list.filter(fn(id) { dict.has_key(registry, id) })

  case chain {
    [] -> {
      // No parent canvas_widgets in scope. Check if the event's
      // target itself is a canvas_widget. Reconstruct the full
      // scoped ID: scope (reversed to forward order) + event id.
      let target_id = widget_key(window_id, scope_to_id(scope, event_id))
      case dict.has_key(registry, target_id) {
        True -> [target_id]
        False -> []
      }
    }
    _ -> chain
  }
}

/// Reconstruct a full scoped ID from a reversed scope list and a
/// local ID. The scope is reversed (innermost first) as stored in
/// events; this function reverses it to forward order before joining.
///
/// scope_to_id(["form"], "submit") => "form/submit"
/// scope_to_id([], "picker") => "picker"
/// scope_to_id(["inner", "outer"], "btn") => "outer/inner/btn"
fn scope_to_id(scope: List(String), id: String) -> String {
  case scope {
    [] -> id
    _ -> string.join(list.reverse(scope), "/") <> "/" <> id
  }
}

/// Convert a reversed scope list to forward-order scoped IDs,
/// from innermost to outermost.
///
/// scope = ["child", "parent"] produces ["parent/child", "parent"]
fn scope_to_widget_ids(scope: List(String)) -> List(String) {
  let forward = list.reverse(scope)
  build_scope_ids(forward, [], [])
}

fn build_scope_ids(
  parts: List(String),
  prefix: List(String),
  acc: List(String),
) -> List(String) {
  case parts {
    // acc is built by prepending, so the longest (innermost) scoped ID
    // is already first -- exactly the order we want (inner to outer).
    [] -> acc
    [part, ..rest] -> {
      let new_prefix = list.append(prefix, [part])
      let scoped_id = string.join(new_prefix, "/")
      build_scope_ids(rest, new_prefix, [scoped_id, ..acc])
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
                    event.WidgetEvent(
                      kind:,
                      window_id:,
                      id:,
                      scope:,
                      value: coerce(Nil),
                      data:,
                    )
                  walk_chain(registry, emitted, rest)
                }
              }
            }
            Error(_) -> {
              platform.log_warning(
                "plushie: canvas_widget \""
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

/// Namespace prefix for canvas widget subscription tags.
const cw_tag_prefix = "__cw:"

/// Collect subscriptions from all canvas widgets in the registry.
///
/// Each subscription's tag is namespaced with the widget's scoped ID
/// so the runtime can route timer events back to the correct widget.
pub fn collect_subscriptions(registry: Registry) -> List(Subscription) {
  dict.fold(registry, [], fn(acc, widget_key, entry) {
    let subs = entry.subscriptions()
    let namespaced = list.map(subs, fn(sub) { namespace_tag(sub, widget_key) })
    list.append(acc, namespaced)
  })
}

/// Namespace a subscription's tag for a canvas widget.
fn namespace_tag(sub: Subscription, widget_key: String) -> Subscription {
  let old_tag = subscription.tag(sub)
  let new_tag = cw_tag_prefix <> widget_key <> key_sep <> old_tag
  subscription.set_tag(sub, new_tag)
}

/// Check if a subscription tag is namespaced for a canvas widget.
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

/// Route a timer event to the correct canvas widget.
///
/// If the timer tag is namespaced, look up the widget, create a
/// TimerTick with the inner tag, dispatch through the widget's
/// handler, and return the result. Emitted events are dispatched
/// through the scope chain so parent canvas widgets can intercept.
///
/// Returns `#(Some(event), registry)` if the event should reach
/// `app.update`, or `#(None, registry)` if handled internally.
/// For non-widget timers, returns `None` -- the caller is
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
          let timer_event = event.TimerTick(tag: inner_tag, timestamp:)
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
                    event.WidgetEvent(
                      kind:,
                      window_id:,
                      id:,
                      scope:,
                      value: coerce(Nil),
                      data:,
                    )
                  dispatch_through_widgets(registry, emitted)
                }
              }
            }
            Error(_) -> {
              platform.log_warning(
                "plushie: canvas_widget \""
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
/// canvas widget's local ID; remaining elements are the parent scope.
/// For non-widget events (timers): split the registered widget_id
/// on "/" to derive id/scope.
fn resolve_emit_identity(
  ev: Event,
  widget_id: String,
) -> #(String, String, List(String)) {
  let window_id = extract_window_id(ev)
  let scope = extract_scope(ev)
  case scope {
    [canvas_id, ..parent_scope] -> #(window_id, canvas_id, parent_scope)
    [] -> {
      let id = extract_id(ev)
      case id {
        "" -> {
          let #(widget_window_id, local_id, widget_scope) =
            split_widget_key(widget_id)
          #(widget_window_id, local_id, widget_scope)
        }
        _ -> #(window_id, id, [])
      }
    }
  }
}

fn split_widget_key(widget_key: String) -> #(String, String, List(String)) {
  case string.split(widget_key, key_sep) {
    [window_id, scoped_id] -> {
      let #(local, scope) = split_scoped_widget_id(scoped_id)
      #(window_id, local, scope)
    }
    _ -> #("", widget_key, [])
  }
}

fn split_scoped_widget_id(widget_id: String) -> #(String, List(String)) {
  let parts = string.split(widget_id, "/")
  case list.reverse(parts) {
    [local, ..parent_parts] -> #(local, parent_parts)
    _ -> #(widget_id, [])
  }
}

// strip_metadata is no longer needed -- metadata lives in the
// separate `meta` field on Node, which is never included in
// props diffing or wire encoding.

// -- Scope extraction --------------------------------------------------------

/// Extract the scope from an event.
///
/// The scope is a reversed ancestor list (innermost first). For
/// example, a button "save" inside container "form" has
/// `scope: ["form"]`. Returns an empty list for events that don't
/// carry scope (system events, timer events, etc.).
///
/// Returns an empty list for events that don't carry scope
/// (system events, timer events, etc.).
pub fn extract_scope(ev: Event) -> List(String) {
  case ev {
    // Widget events
    event.WidgetClick(scope:, ..) -> scope
    event.WidgetInput(scope:, ..) -> scope
    event.WidgetSubmit(scope:, ..) -> scope
    event.WidgetToggle(scope:, ..) -> scope
    event.WidgetSelect(scope:, ..) -> scope
    event.WidgetSlide(scope:, ..) -> scope
    event.WidgetSlideRelease(scope:, ..) -> scope
    event.WidgetPaste(scope:, ..) -> scope
    event.WidgetScroll(scope:, ..) -> scope
    event.WidgetOpen(scope:, ..) -> scope
    event.WidgetClose(scope:, ..) -> scope
    event.WidgetOptionHovered(scope:, ..) -> scope
    event.WidgetSort(scope:, ..) -> scope
    event.WidgetKeyBinding(scope:, ..) -> scope
    // Sensor
    event.SensorResize(scope:, ..) -> scope
    // Mouse area events
    event.MouseAreaRightPress(scope:, ..) -> scope
    event.MouseAreaRightRelease(scope:, ..) -> scope
    event.MouseAreaMiddlePress(scope:, ..) -> scope
    event.MouseAreaMiddleRelease(scope:, ..) -> scope
    event.MouseAreaDoubleClick(scope:, ..) -> scope
    event.MouseAreaEnter(scope:, ..) -> scope
    event.MouseAreaExit(scope:, ..) -> scope
    event.MouseAreaMove(scope:, ..) -> scope
    event.MouseAreaScroll(scope:, ..) -> scope
    // Canvas events
    event.CanvasPress(scope:, ..) -> scope
    event.CanvasRelease(scope:, ..) -> scope
    event.CanvasMove(scope:, ..) -> scope
    event.CanvasScroll(scope:, ..) -> scope
    // Canvas element events
    event.CanvasElementEnter(scope:, ..) -> scope
    event.CanvasElementLeave(scope:, ..) -> scope
    event.CanvasElementClick(scope:, ..) -> scope
    event.CanvasElementDrag(scope:, ..) -> scope
    event.CanvasElementDragEnd(scope:, ..) -> scope
    event.CanvasElementFocused(scope:, ..) -> scope
    event.CanvasElementBlurred(scope:, ..) -> scope
    event.CanvasElementKeyPress(scope:, ..) -> scope
    event.CanvasElementKeyRelease(scope:, ..) -> scope
    // Canvas container events
    event.CanvasFocused(scope:, ..) -> scope
    event.CanvasBlurred(scope:, ..) -> scope
    event.CanvasGroupFocused(scope:, ..) -> scope
    event.CanvasGroupBlurred(scope:, ..) -> scope
    // Pane events
    event.PaneResized(scope:, ..) -> scope
    event.PaneDragged(scope:, ..) -> scope
    event.PaneClicked(scope:, ..) -> scope
    event.PaneFocusCycle(scope:, ..) -> scope
    // Events without scope
    _ -> []
  }
}

/// Extract the local widget ID from an event.
///
/// Returns an empty string for events that don't carry an ID
/// (system events, timer events, etc.).
pub fn extract_id(ev: Event) -> String {
  case ev {
    // Widget events
    event.WidgetClick(id:, ..) -> id
    event.WidgetInput(id:, ..) -> id
    event.WidgetSubmit(id:, ..) -> id
    event.WidgetToggle(id:, ..) -> id
    event.WidgetSelect(id:, ..) -> id
    event.WidgetSlide(id:, ..) -> id
    event.WidgetSlideRelease(id:, ..) -> id
    event.WidgetPaste(id:, ..) -> id
    event.WidgetScroll(id:, ..) -> id
    event.WidgetOpen(id:, ..) -> id
    event.WidgetClose(id:, ..) -> id
    event.WidgetOptionHovered(id:, ..) -> id
    event.WidgetSort(id:, ..) -> id
    event.WidgetKeyBinding(id:, ..) -> id
    // Sensor
    event.SensorResize(id:, ..) -> id
    // Mouse area events
    event.MouseAreaRightPress(id:, ..) -> id
    event.MouseAreaRightRelease(id:, ..) -> id
    event.MouseAreaMiddlePress(id:, ..) -> id
    event.MouseAreaMiddleRelease(id:, ..) -> id
    event.MouseAreaDoubleClick(id:, ..) -> id
    event.MouseAreaEnter(id:, ..) -> id
    event.MouseAreaExit(id:, ..) -> id
    event.MouseAreaMove(id:, ..) -> id
    event.MouseAreaScroll(id:, ..) -> id
    // Canvas events
    event.CanvasPress(id:, ..) -> id
    event.CanvasRelease(id:, ..) -> id
    event.CanvasMove(id:, ..) -> id
    event.CanvasScroll(id:, ..) -> id
    // Canvas element events
    event.CanvasElementEnter(id:, ..) -> id
    event.CanvasElementLeave(id:, ..) -> id
    event.CanvasElementClick(id:, ..) -> id
    event.CanvasElementDrag(id:, ..) -> id
    event.CanvasElementDragEnd(id:, ..) -> id
    event.CanvasElementFocused(id:, ..) -> id
    event.CanvasElementBlurred(id:, ..) -> id
    event.CanvasElementKeyPress(id:, ..) -> id
    event.CanvasElementKeyRelease(id:, ..) -> id
    // Canvas container events
    event.CanvasFocused(id:, ..) -> id
    event.CanvasBlurred(id:, ..) -> id
    event.CanvasGroupFocused(id:, ..) -> id
    event.CanvasGroupBlurred(id:, ..) -> id
    // Pane events
    event.PaneResized(id:, ..) -> id
    event.PaneDragged(id:, ..) -> id
    event.PaneClicked(id:, ..) -> id
    event.PaneFocusCycle(id:, ..) -> id
    _ -> ""
  }
}

pub fn extract_window_id(ev: Event) -> String {
  case ev {
    event.WidgetClick(window_id:, ..) -> window_id
    event.WidgetInput(window_id:, ..) -> window_id
    event.WidgetSubmit(window_id:, ..) -> window_id
    event.WidgetToggle(window_id:, ..) -> window_id
    event.WidgetSelect(window_id:, ..) -> window_id
    event.WidgetSlide(window_id:, ..) -> window_id
    event.WidgetSlideRelease(window_id:, ..) -> window_id
    event.WidgetPaste(window_id:, ..) -> window_id
    event.WidgetScroll(window_id:, ..) -> window_id
    event.WidgetOpen(window_id:, ..) -> window_id
    event.WidgetClose(window_id:, ..) -> window_id
    event.WidgetOptionHovered(window_id:, ..) -> window_id
    event.WidgetSort(window_id:, ..) -> window_id
    event.WidgetKeyBinding(window_id:, ..) -> window_id
    event.WidgetEvent(window_id:, ..) -> window_id
    event.SensorResize(window_id:, ..) -> window_id
    event.MouseAreaRightPress(window_id:, ..) -> window_id
    event.MouseAreaRightRelease(window_id:, ..) -> window_id
    event.MouseAreaMiddlePress(window_id:, ..) -> window_id
    event.MouseAreaMiddleRelease(window_id:, ..) -> window_id
    event.MouseAreaDoubleClick(window_id:, ..) -> window_id
    event.MouseAreaEnter(window_id:, ..) -> window_id
    event.MouseAreaExit(window_id:, ..) -> window_id
    event.MouseAreaMove(window_id:, ..) -> window_id
    event.MouseAreaScroll(window_id:, ..) -> window_id
    event.CanvasPress(window_id:, ..) -> window_id
    event.CanvasRelease(window_id:, ..) -> window_id
    event.CanvasMove(window_id:, ..) -> window_id
    event.CanvasScroll(window_id:, ..) -> window_id
    event.CanvasElementEnter(window_id:, ..) -> window_id
    event.CanvasElementLeave(window_id:, ..) -> window_id
    event.CanvasElementClick(window_id:, ..) -> window_id
    event.CanvasElementDrag(window_id:, ..) -> window_id
    event.CanvasElementDragEnd(window_id:, ..) -> window_id
    event.CanvasElementFocused(window_id:, ..) -> window_id
    event.CanvasElementBlurred(window_id:, ..) -> window_id
    event.CanvasElementKeyPress(window_id:, ..) -> window_id
    event.CanvasElementKeyRelease(window_id:, ..) -> window_id
    event.CanvasFocused(window_id:, ..) -> window_id
    event.CanvasBlurred(window_id:, ..) -> window_id
    event.CanvasGroupFocused(window_id:, ..) -> window_id
    event.CanvasGroupBlurred(window_id:, ..) -> window_id
    event.PaneResized(window_id:, ..) -> window_id
    event.PaneDragged(window_id:, ..) -> window_id
    event.PaneClicked(window_id:, ..) -> window_id
    event.PaneFocusCycle(window_id:, ..) -> window_id
    _ -> ""
  }
}

const key_sep = "\u{001F}"

fn widget_key(window_id: String, scoped_id: String) -> String {
  window_id <> key_sep <> scoped_id
}

// -- Internal helpers --------------------------------------------------------

/// Store a typed value as a Dynamic PropValue.
fn to_dynamic_prop(value: a) -> PropValue {
  // We use StringVal as a carrier -- the actual value is the Dynamic
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
  let typed_def: CanvasWidgetDef(c, b) = coerce(def)
  let state = typed_def.init()
  make_entry(typed_def, props, state)
}

/// Rebuild an entry from erased def, props, and state.
fn rebuild_entry(def: a, props: b, state: c) -> RegistryEntry {
  let typed_def: CanvasWidgetDef(c, b) = coerce(def)
  make_entry(typed_def, props, state)
}

/// Identity coercion for internal canvas_widget plumbing.
///
/// These bypass the type system to store heterogeneous widget types
/// in a single registry. Safety relies on two invariants:
///
/// 1. coerce_to_prop/coerce_from_prop round-trip: a value stored via
///    coerce_to_prop in render_placeholder is recovered via
///    coerce_from_prop in derive_registry within the same tree.
///
/// 2. coerce/coerce_from_dynamic recover values stored by make_entry:
///    the CanvasWidgetDef, props, and state are coerced to Dynamic on
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
