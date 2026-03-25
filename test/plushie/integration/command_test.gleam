//// Integration tests for commands against the real renderer binary
//// (--mock mode).
////
//// These tests verify that commands issued from init and update are
//// executed correctly through the full runtime: send_after fires
//// after its delay, async tasks complete and deliver results, batch
//// commands all execute, streams emit intermediate values, and
//// exceptions in update/view don't crash the runtime.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dyn_decode
import gleam/erlang/process
import gleam/int
import gleam/list
import plushie/app.{type App}
import plushie/command
import plushie/event.{type Event}
import plushie/node.{type Node}
import plushie/support
import plushie/ui
import plushie/widget/window

// ---------------------------------------------------------------------------
// Test apps
// ---------------------------------------------------------------------------

// -- send_after: schedules a message in init --------------------------------

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
  ui.window("main", [window.Title("SendAfter Test")], [
    ui.text_("hi", "hello"),
  ])
}

fn send_after_app() -> App(SendAfterModel, Event) {
  app.simple(send_after_init, send_after_update, send_after_view)
}

// -- async: fires on click, delivers result through update ------------------

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
  ui.window("main", [window.Title("Async Test")], [ui.button_("go", "Go")])
}

fn async_app() -> App(AsyncModel, Event) {
  app.simple(async_init, async_update, async_view)
}

// -- batch: multiple send_after commands in init ----------------------------

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
  ui.window("main", [window.Title("Batch Test")], [ui.text_("hi", "hello")])
}

fn batch_app() -> App(BatchModel, Event) {
  app.simple(batch_init, batch_update, batch_view)
}

// -- stream: emits intermediate values, then completes ----------------------

type StreamModel {
  StreamModel(chunks: List(String), done: Bool)
}

fn stream_init() -> #(StreamModel, command.Command(Event)) {
  #(StreamModel(chunks: [], done: False), command.none())
}

fn stream_update(
  model: StreamModel,
  event: Event,
) -> #(StreamModel, command.Command(Event)) {
  case event {
    event.WidgetClick(id: "go", ..) -> #(
      model,
      command.stream(
        fn(emit) {
          emit(to_dynamic("a"))
          emit(to_dynamic("b"))
          emit(to_dynamic("c"))
          to_dynamic("done")
        },
        "chunks",
      ),
    )
    event.StreamValue(tag: "chunks", value:) -> {
      let assert Ok(s) = dyn_decode.run(value, dyn_decode.string)
      #(
        StreamModel(..model, chunks: list.append(model.chunks, [s])),
        command.none(),
      )
    }
    event.AsyncResult(tag: "chunks", ..) -> #(
      StreamModel(..model, done: True),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn stream_view(_model: StreamModel) -> Node {
  ui.window("main", [window.Title("Stream Test")], [ui.button_("go", "Go")])
}

fn stream_app() -> App(StreamModel, Event) {
  app.simple(stream_init, stream_update, stream_view)
}

// -- error recovery: update/view raise on specific events -------------------

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
  ui.window("main", [window.Title("Error Test")], [
    ui.button_("crash", "Crash"),
    ui.button_("inc", "Inc"),
  ])
}

fn error_app() -> App(ErrorModel, Event) {
  app.simple(error_init, error_update, error_view)
}

type ViewCrashModel {
  ViewCrashModel(crash_view: Bool, count: Int)
}

fn view_crash_init() -> #(ViewCrashModel, command.Command(Event)) {
  #(ViewCrashModel(crash_view: False, count: 0), command.none())
}

fn view_crash_update(
  model: ViewCrashModel,
  event: Event,
) -> #(ViewCrashModel, command.Command(Event)) {
  case event {
    event.WidgetClick(id: "crash_view", ..) -> #(
      ViewCrashModel(..model, crash_view: True),
      command.none(),
    )
    event.WidgetClick(id: "fix_view", ..) -> #(
      ViewCrashModel(crash_view: False, count: model.count + 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn view_crash_view(model: ViewCrashModel) -> Node {
  case model.crash_view {
    True -> panic as "intentional view crash"
    False ->
      ui.window("main", [window.Title("View Crash Test")], [
        ui.button_("crash_view", "Crash View"),
        ui.button_("fix_view", "Fix View"),
      ])
  }
}

fn view_crash_app() -> App(ViewCrashModel, Event) {
  app.simple(view_crash_init, view_crash_update, view_crash_view)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Widen a value to Dynamic for async/stream command payloads.
@external(erlang, "plushie_test_ffi", "identity")
fn to_dynamic(value: a) -> Dynamic

// -- done: immediate value delivery ------------------------------------------

type DoneModel {
  DoneModel(result: Int)
}

fn done_init() -> #(DoneModel, command.Command(Event)) {
  let value: Dynamic = coerce_to_dynamic(99)
  #(
    DoneModel(result: 0),
    command.done(value, fn(d) {
      let assert Ok(n) = dyn_decode.run(d, dyn_decode.int)
      event.TimerTick(tag: "done:" <> int.to_string(n), timestamp: 0)
    }),
  )
}

@external(erlang, "plushie_test_ffi", "identity")
fn coerce_to_dynamic(value: a) -> Dynamic

fn done_update(
  model: DoneModel,
  event: Event,
) -> #(DoneModel, command.Command(Event)) {
  case event {
    event.TimerTick(tag: "done:99", ..) -> #(
      DoneModel(result: 99),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn done_view(_model: DoneModel) -> Node {
  ui.window("main", [window.Title("Done Test")], [
    ui.text_("label", "done"),
  ])
}

fn done_app() -> App(DoneModel, Event) {
  app.simple(done_init, done_update, done_view)
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

/// Stream command emits intermediate values through update, then
/// completes with an AsyncResult.
pub fn stream_emits_intermediate_values_test() -> Nil {
  let rt = support.start(stream_app(), [])
  support.dispatch_event(rt, event.WidgetClick(id: "go", scope: []))
  let result =
    support.await(rt, fn(m) { m.done && list.length(m.chunks) >= 3 }, 500)
  support.stop(rt)
  let assert Ok(model) = result
  let assert ["a", "b", "c"] = model.chunks
  Nil
}

/// Exception in update doesn't crash the runtime. The runtime
/// survives and can process subsequent events normally.
pub fn update_exception_does_not_crash_runtime_test() -> Nil {
  let rt = support.start(error_app(), [])
  support.dispatch_event(rt, event.WidgetClick(id: "crash", scope: []))
  process.sleep(50)
  support.dispatch_event(rt, event.WidgetClick(id: "inc", scope: []))
  let result = support.await(rt, fn(m) { m.count >= 1 }, 500)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}

/// Done command delivers an already-resolved value immediately
/// through the mapper function and into update.
pub fn done_delivers_value_immediately_test() -> Nil {
  let rt = support.start(done_app(), [])
  let result = support.await(rt, fn(m) { m.result == 99 }, 500)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}

/// Exception in view doesn't crash the runtime. The runtime
/// preserves the previous tree and can recover on the next
/// successful view render.
pub fn view_exception_does_not_crash_runtime_test() -> Nil {
  let rt = support.start(view_crash_app(), [])
  support.dispatch_event(rt, event.WidgetClick(id: "crash_view", scope: []))
  process.sleep(50)
  support.dispatch_event(rt, event.WidgetClick(id: "fix_view", scope: []))
  let result = support.await(rt, fn(m) { m.count >= 1 }, 500)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}
