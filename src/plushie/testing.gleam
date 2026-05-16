//// Test facade for plushie applications.
////
//// Provides a unified test API that works on both BEAM and JS targets.
//// The backend is resolved once at `start` and carried through the
//// `TestContext`, so there are no repeated env lookups or backend construction.
////
//// ## BEAM target
////
//// Tests run against the real plushie-renderer binary. Set
//// `PLUSHIE_TEST_BACKEND` to choose the backend:
////
////     gleam test                                  # default: mock
////     PLUSHIE_TEST_BACKEND=headless gleam test    # software rendering
////
//// Default: `mock` (real binary in `--mock` mode, sessions pooled).
////
//// ## JavaScript target
////
//// Tests run the app's init/update/view cycle in-memory via the
//// pure session runner. No renderer binary is needed. Widget
//// interactions construct events directly.
////
//// ## Usage
////
////     let ctx = testing.start(my_app())
////     let ctx = testing.click(ctx, "increment")
////     let assert option.Some(el) = testing.find(ctx, "count")
////     should.equal(element.text(el), option.Some("Count: 1"))
////     testing.stop(ctx)

import gleam/dict
import gleam/list
import gleam/option.{type Option}
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/node.{type Node, type PropValue}
@target(erlang)
import plushie/platform
import plushie/testing/backend.{type Selector, type TestBackend}
import plushie/testing/element.{type Element}
import plushie/testing/session.{type TestSession}

// JS-only import for the pure session backend
@target(javascript)
import plushie/testing/backend/session_backend

// BEAM-only imports for the pooled backend
@target(erlang)
import plushie/testing/backend/mock as mock_backend
@target(erlang)
import plushie/testing/session_pool

// -- TestContext ---------------------------------------------------------------

/// A test context: bundles the session with its backend.
///
/// Created by `start`, threaded through all test operations.
/// The backend is resolved once at startup, not on every call.
pub opaque type TestContext(model, msg) {
  TestContext(
    session: TestSession(model, msg),
    backend: TestBackend(model, msg),
  )
}

// -- Session lifecycle -------------------------------------------------------

/// Start a test session for a simple app (msg = Event).
///
/// On BEAM, requires the plushie-renderer binary (panics with
/// setup instructions if not found). On JS, runs in-memory.
pub fn start(app: App(model, msg)) -> TestContext(model, msg) {
  let be = resolve_backend()
  let session = be.start(app)
  TestContext(session:, backend: be)
}

/// Stop the test context and release resources.
pub fn stop(ctx: TestContext(model, msg)) -> Nil {
  ctx.backend.stop(ctx.session)
}

/// Return the current model.
pub fn model(ctx: TestContext(model, msg)) -> model {
  ctx.backend.model(ctx.session)
}

/// Return the current normalized tree.
pub fn tree(ctx: TestContext(model, msg)) -> Node {
  ctx.backend.tree(ctx.session)
}

/// Dispatch a raw event through the update cycle.
pub fn send_event(
  ctx: TestContext(model, msg),
  event: Event,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.send_event(ctx.session, event))
}

// -- Interaction helpers -----------------------------------------------------

/// Simulate a click on a widget by ID.
pub fn click(
  ctx: TestContext(model, msg),
  id: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.click(ctx.session, id))
}

/// Simulate text input on a widget by ID.
pub fn type_text(
  ctx: TestContext(model, msg),
  id: String,
  text: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.type_text(ctx.session, id, text))
}

/// Simulate a checkbox/toggler toggle by ID.
pub fn toggle(
  ctx: TestContext(model, msg),
  id: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.toggle(ctx.session, id))
}

/// Simulate form submission on a widget by ID.
pub fn submit(
  ctx: TestContext(model, msg),
  id: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.submit(ctx.session, id))
}

/// Simulate a slider change by ID.
pub fn slide(
  ctx: TestContext(model, msg),
  id: String,
  value: Float,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.slide(ctx.session, id, value))
}

/// Simulate a key press. Key string uses PascalCase wire format
/// (e.g., "ArrowRight", "Escape", "Tab") with optional modifier
/// prefixes ("ctrl+s", "shift+Tab").
pub fn press_key(
  ctx: TestContext(model, msg),
  key: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.press_key(ctx.session, key))
}

/// Simulate a key release.
pub fn release_key(
  ctx: TestContext(model, msg),
  key: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.release_key(ctx.session, key))
}

/// Simulate a key press and release.
pub fn type_key(
  ctx: TestContext(model, msg),
  key: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.type_key(ctx.session, key))
}

/// Simulate a mouse press on a canvas widget at (x, y) coordinates.
pub fn canvas_press(
  ctx: TestContext(model, msg),
  id: String,
  x: Float,
  y: Float,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.canvas_press(ctx.session, id, x, y))
}

/// Simulate pasting text into a widget by ID.
pub fn paste(
  ctx: TestContext(model, msg),
  id: String,
  text: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.paste(ctx.session, id, text))
}

/// Trigger sort on a table widget by ID and column name.
pub fn sort(
  ctx: TestContext(model, msg),
  id: String,
  column: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.sort(ctx.session, id, column))
}

/// Simulate a touch press on a canvas widget at (x, y) with a finger index.
pub fn canvas_touch_press(
  ctx: TestContext(model, msg),
  id: String,
  x: Float,
  y: Float,
  finger: Int,
) -> TestContext(model, msg) {
  TestContext(
    ..ctx,
    session: ctx.backend.canvas_touch_press(ctx.session, id, x, y, finger),
  )
}

/// Simulate a touch release on a canvas widget at (x, y) with a finger index.
pub fn canvas_touch_release(
  ctx: TestContext(model, msg),
  id: String,
  x: Float,
  y: Float,
  finger: Int,
) -> TestContext(model, msg) {
  TestContext(
    ..ctx,
    session: ctx.backend.canvas_touch_release(ctx.session, id, x, y, finger),
  )
}

/// Simulate a touch move on a canvas widget at (x, y) with a finger index.
pub fn canvas_touch_move(
  ctx: TestContext(model, msg),
  id: String,
  x: Float,
  y: Float,
  finger: Int,
) -> TestContext(model, msg) {
  TestContext(
    ..ctx,
    session: ctx.backend.canvas_touch_move(ctx.session, id, x, y, finger),
  )
}

/// Simulate selection on a widget by ID.
pub fn select(
  ctx: TestContext(model, msg),
  id: String,
  value: String,
) -> TestContext(model, msg) {
  TestContext(..ctx, session: ctx.backend.select(ctx.session, id, value))
}

// -- Element queries ---------------------------------------------------------

/// Find an element by ID or selector string.
///
/// Accepts plain IDs ("save"), scoped IDs ("form/save"),
/// window-qualified IDs ("main#save"), pseudo-selectors (":focused"),
/// and attribute selectors ("[role=button]", "[text=Save]").
///
/// Plain IDs delegate to the backend's find function (which may
/// query the renderer). Semantic selectors search the tree directly.
pub fn find(ctx: TestContext(model, msg), selector: String) -> Option(Element) {
  let parsed = backend.parse_selector(selector)
  case parsed {
    // ID selectors delegate to the backend for renderer-backed find
    backend.ById(id) -> ctx.backend.find(ctx.session, id)
    // Semantic selectors search the tree
    _ -> find_by(ctx, parsed)
  }
}

/// Find an element by a typed Selector.
///
/// Searches the current tree for text content, a11y role/label,
/// or focus state. For ID-based lookup, use `find(ctx, "id")`.
///
/// ```gleam
/// testing.find_by(ctx, backend.ByRole("button"))
/// testing.find_by(ctx, backend.ByText("Save"))
/// testing.find_by(ctx, backend.Focused)
/// ```
pub fn find_by(
  ctx: TestContext(model, msg),
  selector: Selector,
) -> Option(Element) {
  let tree = ctx.backend.tree(ctx.session)
  find_in_tree(tree, selector)
}

/// Search a tree for an element matching a Selector.
///
/// Note: the Focused selector searches for an element with
/// a11y.focused = "true" in the tree props. For runtime-level
/// focus tracking, use plushie.get_focused() instead.
fn find_in_tree(tree: Node, selector: Selector) -> Option(Element) {
  case selector {
    backend.ById(id) -> element.find(in: tree, id:)
    backend.ByText(text) -> find_by_prop_value(tree, text)
    backend.ByRole(role) -> find_by_a11y_field(tree, "role", role)
    backend.ByLabel(label) -> find_by_a11y_field(tree, "label", label)
    backend.InWindow(window_id, inner_selector) -> {
      // Scope the search to the named window's subtree
      case find_window_subtree(tree, window_id) {
        option.Some(window_node) -> find_in_tree(window_node, inner_selector)
        option.None -> option.None
      }
    }
    backend.Focused -> {
      case find_by_a11y_field(tree, "focused", "true") {
        option.Some(_) as found -> found
        option.None -> option.None
      }
    }
  }
}

/// Find a window node by ID in the tree.
fn find_window_subtree(tree: Node, window_id: String) -> Option(Node) {
  case tree.kind == "window" && tree.id == window_id {
    True -> option.Some(tree)
    False ->
      list.find_map(tree.children, fn(child) {
        case find_window_subtree(child, window_id) {
          option.Some(n) -> Ok(n)
          option.None -> Error(Nil)
        }
      })
      |> option.from_result
  }
}

/// Find the first element whose content/label/value/placeholder matches.
fn find_by_prop_value(tree: Node, text: String) -> Option(Element) {
  let keys = ["content", "label", "value", "placeholder"]
  let matches = fn(node: Node) {
    list.any(keys, fn(key) {
      case dict.get(node.props, key) {
        Ok(node.StringVal(v)) -> v == text
        _ -> False
      }
    })
  }
  case matches(tree) {
    True -> option.Some(element.from_node(tree))
    False ->
      list.find_map(tree.children, fn(child) {
        case find_by_prop_value(child, text) {
          option.Some(el) -> Ok(el)
          option.None -> Error(Nil)
        }
      })
      |> option.from_result
  }
}

/// Find the first element with a matching a11y field value.
fn find_by_a11y_field(
  tree: Node,
  field: String,
  value: String,
) -> Option(Element) {
  let matches = fn(node: Node) {
    case dict.get(node.props, "a11y") {
      Ok(node.DictVal(a11y)) ->
        case dict.get(a11y, field) {
          Ok(node.StringVal(v)) -> v == value
          _ -> False
        }
      _ -> False
    }
  }
  case matches(tree) {
    True -> option.Some(element.from_node(tree))
    False ->
      list.find_map(tree.children, fn(child) {
        case find_by_a11y_field(child, field, value) {
          option.Some(el) -> Ok(el)
          option.None -> Error(Nil)
        }
      })
      |> option.from_result
  }
}

/// Extract text content from an element.
pub fn element_text(el: Element) -> Option(String) {
  element.text(el)
}

/// Get a prop value from an element.
pub fn element_prop(el: Element, key: String) -> Option(PropValue) {
  element.prop(el, key)
}

/// Get an element's children.
pub fn element_children(el: Element) -> List(Element) {
  element.children(el)
}

// -- Assertion helpers -------------------------------------------------------

/// Assert that an element with the given selector exists.
pub fn assert_exists(
  ctx: TestContext(model, msg),
  selector: String,
) -> TestContext(model, msg) {
  case find(ctx, selector) {
    option.Some(_) -> ctx
    option.None ->
      panic as {
        "Expected element '" <> selector <> "' to exist, but it was not found"
      }
  }
}

/// Assert that no element with the given selector exists.
pub fn assert_not_exists(
  ctx: TestContext(model, msg),
  selector: String,
) -> TestContext(model, msg) {
  case find(ctx, selector) {
    option.None -> ctx
    option.Some(_) ->
      panic as {
        "Expected element '" <> selector <> "' to not exist, but it was found"
      }
  }
}

/// Assert that an element's text matches the expected value.
pub fn assert_text(
  ctx: TestContext(model, msg),
  selector: String,
  expected: String,
) -> TestContext(model, msg) {
  case find(ctx, selector) {
    option.None ->
      panic as {
        "Expected element '"
        <> selector
        <> "' to exist with text '"
        <> expected
        <> "', but element was not found"
      }
    option.Some(el) -> {
      case element.text(el) {
        option.Some(actual) if actual == expected -> ctx
        option.Some(actual) ->
          panic as {
            "Expected text '"
            <> expected
            <> "' on '"
            <> selector
            <> "', but got '"
            <> actual
            <> "'"
          }
        option.None ->
          panic as {
            "Expected text '"
            <> expected
            <> "' on '"
            <> selector
            <> "', but element has no text content"
          }
      }
    }
  }
}

/// Return the resolved a11y dict for a widget.
///
/// Layers render-pipeline inference (placeholder -> description for
/// text-entry widgets, alt -> label for media widgets) on top of the
/// normalized `a11y` prop so tests see what assistive technology will
/// see. Panics if the selector doesn't match any widget.
pub fn resolved_a11y(
  ctx: TestContext(model, msg),
  selector: String,
) -> dict.Dict(String, PropValue) {
  case find(ctx, selector) {
    option.Some(el) -> element.resolved_a11y(el)
    option.None -> panic as { "Expected element '" <> selector <> "' to exist" }
  }
}

/// Assert that a widget's resolved a11y contains all expected keys.
///
/// Reads through [`resolved_a11y`](#resolved_a11y) so inferred defaults
/// (placeholder -> description, alt -> label) compose with the
/// author's explicit overrides.
pub fn assert_a11y(
  ctx: TestContext(model, msg),
  selector: String,
  expected: List(#(String, PropValue)),
) -> TestContext(model, msg) {
  let actual = resolved_a11y(ctx, selector)
  list.each(expected, fn(pair) {
    let #(key, want) = pair
    case dict.get(actual, key) {
      Ok(got) if got == want -> Nil
      Ok(_) ->
        panic as {
          "assert_a11y: a11y." <> key <> " mismatch for '" <> selector <> "'"
        }
      Error(_) ->
        panic as {
          "assert_a11y: a11y." <> key <> " not found on '" <> selector <> "'"
        }
    }
  })
  ctx
}

/// Dispatch an AnimationFrame event to advance frame-based animations.
///
/// This works with the mock and session backends. On headless/windowed
/// backends, the renderer generates its own animation frames and this
/// function has no effect.
pub fn advance_frame(
  ctx: TestContext(model, msg),
  timestamp: Int,
) -> TestContext(model, msg) {
  send_event(ctx, event.System(event.AnimationFrame(timestamp:)))
}

/// Get diagnostic events from the test context.
/// This is a placeholder that returns an empty list; it will be
/// expanded when runtime telemetry diagnostic interception is added.
pub fn diagnostics(_ctx: TestContext(model, msg)) -> List(String) {
  []
}

// -- Backend resolution (target-specific) ------------------------------------

@target(erlang)
fn resolve_backend() -> TestBackend(model, msg) {
  case platform.get_env("PLUSHIE_TEST_BACKEND") {
    Ok("headless") -> get_or_start_pooled(session_pool.Headless)
    _ -> get_or_start_pooled(session_pool.Mock)
  }
}

@target(erlang)
fn get_or_start_pooled(mode: session_pool.PoolMode) -> TestBackend(model, msg) {
  case get_pool() {
    Ok(pool_subject) -> mock_backend.backend(pool_subject)
    Error(_) -> {
      let config =
        session_pool.PoolConfig(..session_pool.default_config(), mode:)
      let assert Ok(pool_subject) = session_pool.start(config)
      put_pool(pool_subject)
      mock_backend.backend(pool_subject)
    }
  }
}

@target(erlang)
@external(erlang, "plushie_test_pool_ffi", "get_pool")
fn get_pool() -> Result(session_pool.PoolSubject, Nil)

@target(erlang)
@external(erlang, "plushie_test_pool_ffi", "put_pool")
fn put_pool(pool: session_pool.PoolSubject) -> Nil

@target(javascript)
fn resolve_backend() -> TestBackend(model, msg) {
  session_backend.backend()
}
