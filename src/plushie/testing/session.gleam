//// Test session: immutable state wrapper for the Elm loop.
////
//// A `TestSession` holds the current model, normalized tree, and app
//// reference. Each operation (send_event, click, etc.) returns a new
//// session with updated state. No processes, no side effects: pure
//// functional state threading.
////
//// The session is parameterized over both `model` and `msg`. Wire
//// `Event` values fed to `send_event` are mapped to the app's `msg`
//// via `app.on_event` (or the identity coercion for simple apps where
//// `msg = Event`) before they reach the app's `update`.

import gleam/dynamic.{type Dynamic}
import gleam/option
import plushie/app.{type App}
import plushie/command.{type Command}
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/runtime_core
import plushie/tree
import plushie/widget

/// Immutable test session. Each operation returns a new session.
pub opaque type TestSession(model, msg) {
  TestSession(
    app: App(model, msg),
    model: model,
    tree: Node,
    registry: widget.Registry,
    memo_cache: tree.MemoCache,
  )
}

/// Create a new test session from an app. Calls init, processes
/// commands, renders and normalizes the initial view.
pub fn start(app: App(model, msg)) -> TestSession(model, msg) {
  let init_fn = app.get_init(app)
  let #(model, commands) = init_fn(dynamic.nil())
  let model = process_commands(app, model, commands)
  let #(tree, memo_cache) =
    render(app, model, widget.empty_registry(), tree.empty_memo_cache())
  let registry = widget.derive_registry(tree)
  TestSession(app:, model:, tree:, registry:, memo_cache:)
}

/// Dispatch an event through the app's update function. The event
/// first walks the custom-widget handler chain so widget `handle_event`
/// callbacks can intercept or rewrite it (the same translation the
/// production runtime performs). The resulting event then passes
/// through the app's on_event mapper before reaching update.
pub fn send_event(
  session: TestSession(model, msg),
  event: Event,
) -> TestSession(model, msg) {
  let #(result, new_registry) =
    widget.dispatch_through_widgets(session.registry, event)
  case runtime_core.resolve_dispatch(result) {
    option.None -> rerender(TestSession(..session, registry: new_registry))
    option.Some(resolved) -> {
      let msg = runtime_core.map_event(session.app, resolved)
      let update_fn = app.get_update(session.app)
      let #(model, commands) = update_fn(session.model, msg)
      let model = process_commands(session.app, model, commands)
      let #(tree, memo_cache) =
        render(session.app, model, new_registry, session.memo_cache)
      let registry = widget.derive_registry(tree)
      TestSession(..session, model:, tree:, registry:, memo_cache:)
    }
  }
}

fn rerender(session: TestSession(model, msg)) -> TestSession(model, msg) {
  let #(tree, memo_cache) =
    render(session.app, session.model, session.registry, session.memo_cache)
  let registry = widget.derive_registry(tree)
  TestSession(..session, tree:, registry:, memo_cache:)
}

/// Return the current model.
pub fn model(session: TestSession(model, msg)) -> model {
  session.model
}

/// Return the current normalized tree.
pub fn current_tree(session: TestSession(model, msg)) -> Node {
  session.tree
}

/// Return the underlying app (for helpers that need access).
pub fn get_app(session: TestSession(model, msg)) -> App(model, msg) {
  session.app
}

// -- Internal -----------------------------------------------------------------

// Pass the caller's current widget registry and memo cache into
// normalize_view so custom widget state and tree.memo blocks both
// survive across renders. Mirrors what runtime.gleam does with
// state.cw_registry and state.memo_cache. Returns the new memo
// cache produced by this render so the caller can thread it into
// the next cycle.
fn render(
  app: App(model, msg),
  model: model,
  registry: widget.Registry,
  prev_memo_cache: tree.MemoCache,
) -> #(Node, tree.MemoCache) {
  let view_fn = app.get_view(app)
  let raw = tree.view_list_to_tree(view_fn(model))
  case tree.normalize_view(raw, registry, prev_memo_cache) {
    Ok(result) -> #(result.tree, result.memo_cache)
    Error(message) -> panic as message
  }
}

/// Max depth for recursive command processing (guards against infinite loops).
const max_command_depth = 100

fn process_commands(
  app: App(model, msg),
  model: model,
  commands: Command(msg),
) -> model {
  do_process(app, model, commands, 0)
}

fn do_process(
  app: App(model, msg),
  model: model,
  cmd: Command(msg),
  depth: Int,
) -> model {
  case depth > max_command_depth {
    True -> model
    False ->
      case cmd {
        command.None -> model
        command.Batch(commands:) -> batch_process(app, model, commands, depth)
        command.Done(value:, mapper:) -> {
          let msg = mapper(value)
          let update_fn = app.get_update(app)
          let #(new_model, new_commands) = update_fn(model, msg)
          do_process(app, new_model, new_commands, depth + 1)
        }
        command.Async(work:, tag:) -> {
          let result = work()
          dispatch_async_result(app, model, tag, Ok(result), depth)
        }
        command.Stream(work:, tag:) -> {
          let values = collect_stream_values(work)
          let model = drain_stream_values(app, model, tag, values.0, depth)
          dispatch_async_result(app, model, tag, Ok(values.1), depth)
        }
        // Widget ops, window ops, focus, scroll, timers, etc. are
        // no-ops in the test backend; they need a renderer.
        _ -> model
      }
  }
}

fn batch_process(
  app: App(model, msg),
  model: model,
  commands: List(Command(msg)),
  depth: Int,
) -> model {
  case commands {
    [] -> model
    [cmd, ..rest] -> {
      let model = do_process(app, model, cmd, depth)
      batch_process(app, model, rest, depth)
    }
  }
}

/// Dispatch an async result through the app's update function via
/// the on_event mapper.
fn dispatch_async_result(
  app: App(model, msg),
  model: model,
  tag: String,
  result: Result(Dynamic, Dynamic),
  depth: Int,
) -> model {
  let raw_event = event.Async(event.AsyncEvent(tag:, result:))
  let msg = runtime_core.map_event(app, raw_event)
  let update_fn = app.get_update(app)
  let #(new_model, new_commands) = update_fn(model, msg)
  do_process(app, new_model, new_commands, depth + 1)
}

fn dispatch_stream_value(
  app: App(model, msg),
  model: model,
  tag: String,
  value: Dynamic,
  depth: Int,
) -> model {
  let raw_event = event.Stream(event.StreamEvent(tag:, value:))
  let msg = runtime_core.map_event(app, raw_event)
  let update_fn = app.get_update(app)
  let #(new_model, new_commands) = update_fn(model, msg)
  do_process(app, new_model, new_commands, depth + 1)
}

fn drain_stream_values(
  app: App(model, msg),
  model: model,
  tag: String,
  values: List(Dynamic),
  depth: Int,
) -> model {
  case values {
    [] -> model
    [value, ..rest] -> {
      let model = dispatch_stream_value(app, model, tag, value, depth)
      drain_stream_values(app, model, tag, rest, depth)
    }
  }
}

/// Run a stream work function, collecting emitted values in order.
/// Returns #(emitted_values, final_return_value).
@external(erlang, "plushie_test_ffi", "collect_stream_values")
@external(javascript, "../../plushie_test_ffi.mjs", "collect_stream_values")
fn collect_stream_values(
  work: fn(fn(Dynamic) -> Nil) -> Dynamic,
) -> #(List(Dynamic), Dynamic)
