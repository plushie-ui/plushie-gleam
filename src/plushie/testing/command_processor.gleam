//// Synchronous command processor for test backends.
////
//// Executes async, stream, done, and batch commands synchronously so that
//// update side effects resolve immediately in tests. Widget ops, window
//// ops, timers, and cancel are silently skipped (they need a renderer).
////
//// Since execution is synchronous, await_async returns immediately --
//// commands have already completed by the time it is called.

import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option, None, Some}
import plushie/app.{type App}
import plushie/command.{type Command}
import plushie/event.{type Event}

/// Default max depth for recursive command processing (guards against
/// infinite loops).
const default_max_depth = 100

/// Process commands synchronously, threading model state through each
/// update dispatch. Returns the final model and list of events processed.
///
/// `max_depth` controls recursion depth: `None` uses the default limit,
/// `Some(n)` uses n.
pub fn process_commands(
  app: App(model, msg),
  model: model,
  commands: Command(msg),
  max_depth: Option(Int),
) -> #(model, List(Event)) {
  let effective_max = case max_depth {
    Some(n) -> n
    None -> default_max_depth
  }
  do_process(app, model, commands, 0, effective_max, [])
}

fn do_process(
  app: App(model, msg),
  model: model,
  cmd: Command(msg),
  depth: Int,
  max_depth: Int,
  events: List(Event),
) -> #(model, List(Event)) {
  case depth > max_depth {
    True -> #(model, events)
    False ->
      case cmd {
        command.None -> #(model, events)
        command.Batch(commands:) ->
          batch_process(app, model, commands, depth, max_depth, events)
        command.Done(value:, mapper:) -> {
          let msg = mapper(value)
          let update_fn = app.get_update(app)
          let #(new_model, new_commands) = update_fn(model, msg)
          do_process(app, new_model, new_commands, depth + 1, max_depth, events)
        }
        command.Async(work:, tag:) -> {
          let result = work()
          dispatch_async_result(
            app,
            model,
            tag,
            Ok(result),
            depth,
            max_depth,
            events,
          )
        }
        command.Stream(work:, tag:) -> {
          let values = collect_stream_values(work)
          let #(model, events) =
            drain_stream_values(
              app,
              model,
              tag,
              values.0,
              depth,
              max_depth,
              events,
            )
          dispatch_async_result(
            app,
            model,
            tag,
            Ok(values.1),
            depth,
            max_depth,
            events,
          )
        }
        // Widget ops, window ops, focus, scroll, timers, etc. are
        // no-ops in the test backend -- they need a renderer.
        _ -> #(model, events)
      }
  }
}

fn batch_process(
  app: App(model, msg),
  model: model,
  commands: List(Command(msg)),
  depth: Int,
  max_depth: Int,
  events: List(Event),
) -> #(model, List(Event)) {
  case commands {
    [] -> #(model, events)
    [cmd, ..rest] -> {
      let #(model, events) =
        do_process(app, model, cmd, depth, max_depth, events)
      batch_process(app, model, rest, depth, max_depth, events)
    }
  }
}

fn dispatch_async_result(
  app: App(model, msg),
  model: model,
  tag: String,
  result: Result(Dynamic, Dynamic),
  depth: Int,
  max_depth: Int,
  events: List(Event),
) -> #(model, List(Event)) {
  let raw_event = event.AsyncResult(tag:, result:)
  let events = [raw_event, ..events]
  case app.get_on_event(app) {
    option.Some(on_event) -> {
      let msg = on_event(raw_event)
      let update_fn = app.get_update(app)
      let #(new_model, new_commands) = update_fn(model, msg)
      do_process(app, new_model, new_commands, depth + 1, max_depth, events)
    }
    option.None -> {
      let msg = event_to_msg(raw_event)
      let update_fn = app.get_update(app)
      let #(new_model, new_commands) = update_fn(model, msg)
      do_process(app, new_model, new_commands, depth + 1, max_depth, events)
    }
  }
}

fn dispatch_stream_value(
  app: App(model, msg),
  model: model,
  tag: String,
  value: Dynamic,
  depth: Int,
  max_depth: Int,
  events: List(Event),
) -> #(model, List(Event)) {
  let raw_event = event.StreamValue(tag:, value:)
  let events = [raw_event, ..events]
  case app.get_on_event(app) {
    option.Some(on_event) -> {
      let msg = on_event(raw_event)
      let update_fn = app.get_update(app)
      let #(new_model, new_commands) = update_fn(model, msg)
      do_process(app, new_model, new_commands, depth + 1, max_depth, events)
    }
    option.None -> {
      let msg = event_to_msg(raw_event)
      let update_fn = app.get_update(app)
      let #(new_model, new_commands) = update_fn(model, msg)
      do_process(app, new_model, new_commands, depth + 1, max_depth, events)
    }
  }
}

fn drain_stream_values(
  app: App(model, msg),
  model: model,
  tag: String,
  values: List(Dynamic),
  depth: Int,
  max_depth: Int,
  events: List(Event),
) -> #(model, List(Event)) {
  case values {
    [] -> #(model, events)
    [value, ..rest] -> {
      let #(model, events) =
        dispatch_stream_value(app, model, tag, value, depth, max_depth, events)
      drain_stream_values(app, model, tag, rest, depth, max_depth, events)
    }
  }
}

/// Run a stream work function, collecting emitted values in order.
@external(erlang, "plushie_test_ffi", "collect_stream_values")
fn collect_stream_values(
  work: fn(fn(Dynamic) -> Nil) -> Dynamic,
) -> #(List(Dynamic), Dynamic)

/// Cast Event to msg for simple apps where msg = Event.
@external(erlang, "plushie_test_ffi", "identity")
fn event_to_msg(value: Event) -> msg
