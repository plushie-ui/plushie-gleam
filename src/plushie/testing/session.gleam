//// Test session: immutable state wrapper for the Elm loop.
////
//// A `TestSession` holds the current model, normalized tree, and app
//// reference. Each operation (send_event, click, etc.) returns a new
//// session with updated state. No processes, no side effects -- pure
//// functional state threading.

import gleam/dynamic.{type Dynamic}
import gleam/option
import plushie/app.{type App}
import plushie/widget
import plushie/command.{type Command}
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/tree

/// Immutable test session. Each operation returns a new session.
pub opaque type TestSession(model, msg) {
  TestSession(app: App(model, msg), model: model, tree: Node)
}

/// Create a new test session from an app. Calls init, processes
/// commands, renders and normalizes the initial view.
pub fn start(app: App(model, msg)) -> TestSession(model, msg) {
  let init_fn = app.get_init(app)
  let #(model, commands) = init_fn(dynamic.nil())
  let model = process_commands(app, model, commands)
  let tree = render(app, model)
  TestSession(app:, model:, tree:)
}

/// Dispatch an event through the app's update function.
/// Processes resulting commands and re-renders the view.
pub fn send_event(
  session: TestSession(model, msg),
  event: msg,
) -> TestSession(model, msg) {
  let update_fn = app.get_update(session.app)
  let #(model, commands) = update_fn(session.model, event)
  let model = process_commands(session.app, model, commands)
  let tree = render(session.app, model)
  TestSession(..session, model:, tree:)
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

fn render(app: App(model, msg), model: model) -> Node {
  let view_fn = app.get_view(app)
  case tree.normalize_view(view_fn(model), widget.empty_registry()) {
    Ok(normalized) -> normalized
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
        // no-ops in the test backend -- they need a renderer.
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

/// Dispatch an async result through the app's update function.
/// For apps with on_event (custom msg), maps the Event through on_event.
/// For simple apps (msg = Event), coerces the Event to msg at runtime.
fn dispatch_async_result(
  app: App(model, msg),
  model: model,
  tag: String,
  result: Result(Dynamic, Dynamic),
  depth: Int,
) -> model {
  let raw_event = event.AsyncResult(tag:, result:)
  case app.get_on_event(app) {
    option.Some(on_event) -> {
      let msg = on_event(raw_event)
      let update_fn = app.get_update(app)
      let #(new_model, new_commands) = update_fn(model, msg)
      do_process(app, new_model, new_commands, depth + 1)
    }
    option.None -> {
      // Simple app: msg = Event. Coerce at the Erlang level.
      let msg = event_to_msg(raw_event)
      let update_fn = app.get_update(app)
      let #(new_model, new_commands) = update_fn(model, msg)
      do_process(app, new_model, new_commands, depth + 1)
    }
  }
}

fn dispatch_stream_value(
  app: App(model, msg),
  model: model,
  tag: String,
  value: Dynamic,
  depth: Int,
) -> model {
  let raw_event = event.StreamValue(tag:, value:)
  case app.get_on_event(app) {
    option.Some(on_event) -> {
      let msg = on_event(raw_event)
      let update_fn = app.get_update(app)
      let #(new_model, new_commands) = update_fn(model, msg)
      do_process(app, new_model, new_commands, depth + 1)
    }
    option.None -> {
      let msg = event_to_msg(raw_event)
      let update_fn = app.get_update(app)
      let #(new_model, new_commands) = update_fn(model, msg)
      do_process(app, new_model, new_commands, depth + 1)
    }
  }
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
fn collect_stream_values(
  work: fn(fn(Dynamic) -> Nil) -> Dynamic,
) -> #(List(Dynamic), Dynamic)

/// Cast Event to msg for simple apps where msg = Event.
/// The type system can't prove msg = Event when on_event is None,
/// but this is guaranteed by the App constructor invariant.
@external(erlang, "plushie_test_ffi", "identity")
fn event_to_msg(value: Event) -> msg
