//// Integration tests for commands against the real renderer binary
//// (--mock mode).
////
//// These tests verify that commands issued from init and update are
//// executed correctly through the full runtime: send_after fires
//// after its delay, async tasks complete and deliver results, batch
//// commands all execute, and streams emit intermediate values.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dyn_decode
import gleam/erlang/process
import plushie/app.{type App}
import plushie/command
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/support
import plushie/ui

// ---------------------------------------------------------------------------
// send_after app: schedules a message in init
// ---------------------------------------------------------------------------

type SendAfterModel {
  SendAfterModel(value: Int)
}

fn send_after_init() -> #(SendAfterModel, command.Command(Event)) {
  #(
    SendAfterModel(value: 0),
    command.send_after(20, event.TimerTick(tag: "init_timer", timestamp: 0)),
  )
}

fn send_after_update(
  model: SendAfterModel,
  event: Event,
) -> #(SendAfterModel, command.Command(Event)) {
  case event {
    event.TimerTick(tag: "init_timer", ..) -> #(
      SendAfterModel(value: model.value + 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn send_after_view(_model: SendAfterModel) -> Node {
  ui.window("main", [ui.title("SendAfter Test")], [
    ui.text_("hi", "hello"),
  ])
}

fn send_after_app() -> App(SendAfterModel, Event) {
  app.simple(send_after_init, send_after_update, send_after_view)
}

// ---------------------------------------------------------------------------
// async app: fires async on click, delivers result through update
// ---------------------------------------------------------------------------

type AsyncModel {
  AsyncModel(result: Int)
}

fn async_init() -> #(AsyncModel, command.Command(Event)) {
  #(AsyncModel(result: 0), command.none())
}

fn async_update(
  model: AsyncModel,
  event: Event,
) -> #(AsyncModel, command.Command(Event)) {
  case event {
    event.WidgetClick(id: "go", ..) -> #(
      model,
      command.async(fn() { to_dynamic(42) }, "compute"),
    )
    event.AsyncResult(tag: "compute", result: Ok(value)) -> {
      let assert Ok(n) = dyn_decode.run(value, dyn_decode.int)
      #(AsyncModel(result: n), command.none())
    }
    _ -> #(model, command.none())
  }
}

fn async_view(_model: AsyncModel) -> Node {
  ui.window("main", [ui.title("Async Test")], [
    ui.button_("go", "Go"),
  ])
}

fn async_app() -> App(AsyncModel, Event) {
  app.simple(async_init, async_update, async_view)
}

// ---------------------------------------------------------------------------
// batch app: multiple send_after commands in init
// ---------------------------------------------------------------------------

type BatchModel {
  BatchModel(a: Bool, b: Bool)
}

fn batch_init() -> #(BatchModel, command.Command(Event)) {
  #(
    BatchModel(a: False, b: False),
    command.batch([
      command.send_after(15, event.TimerTick(tag: "batch_a", timestamp: 0)),
      command.send_after(15, event.TimerTick(tag: "batch_b", timestamp: 0)),
    ]),
  )
}

fn batch_update(
  model: BatchModel,
  event: Event,
) -> #(BatchModel, command.Command(Event)) {
  case event {
    event.TimerTick(tag: "batch_a", ..) -> #(
      BatchModel(..model, a: True),
      command.none(),
    )
    event.TimerTick(tag: "batch_b", ..) -> #(
      BatchModel(..model, b: True),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn batch_view(_model: BatchModel) -> Node {
  ui.window("main", [ui.title("Batch Test")], [ui.text_("hi", "hello")])
}

fn batch_app() -> App(BatchModel, Event) {
  app.simple(batch_init, batch_update, batch_view)
}

// ---------------------------------------------------------------------------
// error recovery app: update raises on specific event
// ---------------------------------------------------------------------------

type ErrorModel {
  ErrorModel(count: Int)
}

fn error_init() -> #(ErrorModel, command.Command(Event)) {
  #(ErrorModel(count: 0), command.none())
}

fn error_update(
  model: ErrorModel,
  event: Event,
) -> #(ErrorModel, command.Command(Event)) {
  case event {
    event.WidgetClick(id: "crash", ..) -> panic as "intentional test crash"
    event.WidgetClick(id: "inc", ..) -> #(
      ErrorModel(count: model.count + 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn error_view(_model: ErrorModel) -> Node {
  ui.window("main", [ui.title("Error Test")], [
    ui.button_("crash", "Crash"),
    ui.button_("inc", "Inc"),
  ])
}

fn error_app() -> App(ErrorModel, Event) {
  app.simple(error_init, error_update, error_view)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// send_after from init fires and delivers the event through update.
pub fn send_after_fires_from_init_test() -> Nil {
  let rt = support.start(send_after_app(), [])
  let result = support.await(rt, fn(m) { m.value >= 1 }, 500)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}

/// Async command completes and result is dispatched through update.
pub fn async_completes_and_dispatches_result_test() -> Nil {
  let rt = support.start(async_app(), [])
  // Trigger the async command via a click
  support.dispatch_event(rt, event.WidgetClick(id: "go", scope: []))
  let result = support.await(rt, fn(m) { m.result == 42 }, 500)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}

/// Batch commands from init all execute.
pub fn batch_commands_all_execute_test() -> Nil {
  let rt = support.start(batch_app(), [])
  let result = support.await(rt, fn(m) { m.a && m.b }, 500)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}

/// Widen a value to Dynamic for async command payloads.
@external(erlang, "plushie_test_ffi", "identity")
fn to_dynamic(value: a) -> Dynamic

/// Exception in update doesn't crash the runtime. The runtime
/// survives and can process subsequent events normally.
pub fn update_exception_does_not_crash_runtime_test() -> Nil {
  let rt = support.start(error_app(), [])

  // Send the crashing event
  support.dispatch_event(rt, event.WidgetClick(id: "crash", scope: []))
  process.sleep(50)

  // Runtime should still be alive -- send a normal event
  support.dispatch_event(rt, event.WidgetClick(id: "inc", scope: []))
  let result = support.await(rt, fn(m) { m.count >= 1 }, 500)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}
