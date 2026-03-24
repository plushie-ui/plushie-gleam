//// Test helpers for runtime integration tests.
////
//// These helpers start a real plushie application (supervisor + bridge
//// + runtime + renderer binary) and provide typed state query and
//// polling utilities for assertions.
////
//// The supervisor is started in an unlinked owner process so its
//// shutdown signal doesn't propagate to the eunit test runner. The
//// owner monitors the test process and self-terminates if it dies,
//// preventing resource leaks on test failure.
////
//// ## Usage
////
////     let rt = support.start(my_app, [])
////     let result = support.await(rt, fn(m) { m.ticks >= 2 }, 500)
////     support.stop(rt)
////     let assert Ok(_) = result

import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import plushie
import plushie/app.{type App}
import plushie/event.{type Event}
import plushie/node.{type Node}

/// A running test app instance, parameterized over the model type
/// for fully typed state queries.
pub opaque type TestApp(model) {
  TestApp(instance: plushie.Instance(model), stop_signal: Subject(Nil))
}

/// Start a plushie application for testing.
///
/// Launches the full supervisor tree (bridge + runtime + renderer)
/// in an unlinked owner process to isolate exit signals from the
/// test runner. The renderer runs in `--mock` mode (protocol only,
/// no rendering) unless overridden via `extra_renderer_args`.
///
/// The owner process monitors the calling process (the test) and
/// self-terminates if it dies, preventing 60-second resource leaks
/// on test failure.
///
/// Panics if the application fails to start (binary not found,
/// supervisor init failure, etc.).
pub fn start(
  app: App(model, msg),
  extra_renderer_args: List(String),
) -> TestApp(model) {
  let instance_reply = process.new_subject()
  let caller_pid = process.self()

  process.spawn_unlinked(fn() {
    // Subjects must be created in the owner process (the process
    // that will receive on them).
    let stop_signal = process.new_subject()

    // Monitor the test process so we clean up if it dies.
    let caller_monitor = process.monitor(caller_pid)

    let opts =
      plushie.StartOpts(..plushie.default_start_opts(), renderer_args: [
        "--mock",
        ..extra_renderer_args
      ])
    let assert Ok(instance) = plushie.start(app, opts)
    process.send(instance_reply, #(instance, stop_signal))

    // Block until stop is called OR the test process dies.
    let selector =
      process.new_selector()
      |> process.select(stop_signal)
      |> process.select_specific_monitor(caller_monitor, fn(_down) { Nil })
    let _ = process.selector_receive(selector, 60_000)
    plushie.stop(instance)
  })

  let assert Ok(#(instance, stop_signal)) =
    process.receive(instance_reply, 10_000)
  TestApp(instance:, stop_signal:)
}

/// Query the current model with full type safety.
///
/// The model type is preserved from the App passed to `start`.
pub fn model(rt: TestApp(model)) -> Result(model, Nil) {
  plushie.get_model(rt.instance)
}

/// Query the current normalized tree.
pub fn tree(rt: TestApp(_)) -> Result(Option(Node), Nil) {
  plushie.get_tree(rt.instance)
}

/// Dispatch an event to the running application.
///
/// The event is processed through the normal update cycle as if
/// it came from the renderer.
pub fn dispatch_event(rt: TestApp(_), event: Event) -> Nil {
  plushie.dispatch_event(rt.instance, event)
}

/// Register an effect stub so the renderer returns a controlled
/// response instead of executing the real effect.
///
/// Blocks until the renderer confirms the stub is stored.
pub fn register_effect_stub(
  rt: TestApp(_),
  kind: String,
  response: node.PropValue,
) -> Result(Nil, Nil) {
  plushie.register_effect_stub(rt.instance, kind, response)
}

/// Remove a previously registered effect stub.
///
/// Blocks until the renderer confirms the stub is removed.
pub fn unregister_effect_stub(rt: TestApp(_), kind: String) -> Result(Nil, Nil) {
  plushie.unregister_effect_stub(rt.instance, kind)
}

/// Stop the test application.
///
/// Signals the owner process to shut down the supervisor.
pub fn stop(rt: TestApp(_)) -> Nil {
  process.send(rt.stop_signal, Nil)
}

/// Poll the model until a condition is met or timeout expires.
///
/// Queries the runtime model every 10ms and passes it to the
/// condition function. Returns `Ok(model)` as soon as the condition
/// returns `True`, or `Error(Nil)` if the timeout is reached.
pub fn await(
  rt: TestApp(model),
  condition: fn(model) -> Bool,
  timeout_ms: Int,
) -> Result(model, Nil) {
  let deadline = monotonic_time_ms() + timeout_ms
  poll(rt, condition, deadline)
}

fn poll(
  rt: TestApp(model),
  condition: fn(model) -> Bool,
  deadline: Int,
) -> Result(model, Nil) {
  case model(rt) {
    Ok(m) ->
      case condition(m) {
        True -> Ok(m)
        False ->
          case monotonic_time_ms() >= deadline {
            True -> Error(Nil)
            False -> {
              process.sleep(10)
              poll(rt, condition, deadline)
            }
          }
      }
    Error(_) -> Error(Nil)
  }
}

@external(erlang, "plushie_ffi", "monotonic_time_ms")
fn monotonic_time_ms() -> Int
