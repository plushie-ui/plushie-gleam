//// Integration tests for timer subscriptions against the real
//// renderer binary (--mock mode).
////
//// These tests verify that the runtime's subscription lifecycle
//// works end-to-end: timers fire, events dispatch through update,
//// and the model reflects the accumulated state.

import gleam/erlang/process
import plushie/app.{type App}
import plushie/command
import plushie/event.{type Event, TimerTick}
import plushie/node.{type Node}
import plushie/subscription
import plushie/support
import plushie/ui
import plushie/widget/window

// ---------------------------------------------------------------------------
// Test apps
// ---------------------------------------------------------------------------

type TickModel {
  TickModel(ticks: Int)
}

fn tick_init() -> #(TickModel, command.Command(Event)) {
  #(TickModel(ticks: 0), command.none())
}

fn tick_update(
  model: TickModel,
  event: Event,
) -> #(TickModel, command.Command(Event)) {
  case event {
    TimerTick(tag: "t", ..) -> #(
      TickModel(ticks: model.ticks + 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn tick_view(_model: TickModel) -> Node {
  ui.window("main", [window.Title("Tick Test")], [ui.text_("hi", "hello")])
}

fn tick_app() -> App(TickModel, Event) {
  app.simple(tick_init, tick_update, tick_view)
  |> app.with_subscriptions(fn(_model) { [subscription.every(20, "t")] })
}

// -- Toggle app: timer can be turned on/off ---------------------------------

type ToggleModel {
  ToggleModel(ticks: Int, timer_on: Bool)
}

fn toggle_init() -> #(ToggleModel, command.Command(Event)) {
  #(ToggleModel(ticks: 0, timer_on: True), command.none())
}

fn toggle_update(
  model: ToggleModel,
  event: Event,
) -> #(ToggleModel, command.Command(Event)) {
  case event {
    TimerTick(tag: "t", ..) -> #(
      ToggleModel(..model, ticks: model.ticks + 1),
      command.none(),
    )
    event.WidgetClick(window_id: "main", id: "stop", ..) -> #(
      ToggleModel(..model, timer_on: False),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn toggle_view(_model: ToggleModel) -> Node {
  ui.window("main", [window.Title("Toggle Test")], [
    ui.button_("stop", "Stop"),
  ])
}

fn toggle_subscribe(model: ToggleModel) -> List(subscription.Subscription) {
  case model.timer_on {
    True -> [subscription.every(20, "t")]
    False -> []
  }
}

fn toggle_app() -> App(ToggleModel, Event) {
  app.simple(toggle_init, toggle_update, toggle_view)
  |> app.with_subscriptions(toggle_subscribe)
}

// -- Multi-timer app: two timers at different rates -------------------------

type MultiModel {
  MultiModel(fast: Int, slow: Int)
}

fn multi_init() -> #(MultiModel, command.Command(Event)) {
  #(MultiModel(fast: 0, slow: 0), command.none())
}

fn multi_update(
  model: MultiModel,
  event: Event,
) -> #(MultiModel, command.Command(Event)) {
  case event {
    TimerTick(tag: "fast", ..) -> #(
      MultiModel(..model, fast: model.fast + 1),
      command.none(),
    )
    TimerTick(tag: "slow", ..) -> #(
      MultiModel(..model, slow: model.slow + 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn multi_view(_model: MultiModel) -> Node {
  ui.window("main", [window.Title("Multi Test")], [ui.text_("hi", "hello")])
}

fn multi_app() -> App(MultiModel, Event) {
  app.simple(multi_init, multi_update, multi_view)
  |> app.with_subscriptions(fn(_model) {
    [subscription.every(15, "fast"), subscription.every(50, "slow")]
  })
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Timer subscription fires periodically and model accumulates ticks.
pub fn timer_fires_periodically_test() -> Nil {
  let rt = support.start(tick_app(), [])
  let result = support.await(rt, fn(m) { m.ticks >= 3 }, 500)
  support.stop(rt)
  let assert Ok(_) = result
  Nil
}

/// Toggling off a subscription stops the timer from firing.
pub fn subscription_toggle_off_stops_ticks_test() -> Nil {
  let rt = support.start(toggle_app(), [])

  // Wait for some ticks to accumulate
  let assert Ok(before) = support.await(rt, fn(m) { m.ticks >= 2 }, 500)

  // Inject a click event to turn off the timer
  support.dispatch_event(
    rt,
    event.WidgetClick(window_id: "main", id: "stop", scope: []),
  )

  // Wait for the event to be processed
  process.sleep(50)
  let assert Ok(after_stop) = support.model(rt)

  // Give time for any straggler ticks
  process.sleep(100)
  let assert Ok(later) = support.model(rt)

  // Ticks should have stopped (or at most one straggler)
  let assert True = later.ticks - after_stop.ticks <= 1
  let assert True = before.ticks >= 2

  support.stop(rt)
  Nil
}

/// Multiple timers at different rates both fire, fast accumulates more.
pub fn multiple_concurrent_timers_test() -> Nil {
  let rt = support.start(multi_app(), [])
  let result = support.await(rt, fn(m) { m.fast >= 4 && m.slow >= 1 }, 500)
  support.stop(rt)
  let assert Ok(model) = result
  let assert True = model.fast > model.slow
  Nil
}
