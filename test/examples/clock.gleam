//// Clock example showing the current time, updated every second.
////
//// Demonstrates:
//// - `subscription.every` for timer-based updates
//// - Pattern matching on `TimerTick` in update
//// - Erlang FFI for wall-clock time

import gleam/int
import gleam/io
import plushie
import plushie/app
import plushie/command
import plushie/event.{type Event, TimerTick}
import plushie/node.{type Node}
import plushie/prop/alignment
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/subscription
import plushie/ui

pub type Model {
  Model(time: String)
}

fn init() {
  #(Model(time: current_time()), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    TimerTick(tag: "tick", ..) -> #(Model(time: current_time()), command.none())
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Node {
  let assert Ok(muted) = color.from_hex("#888888")

  ui.window("main", [ui.title("Clock")], [
    ui.column(
      "content",
      [
        ui.padding(padding.all(24.0)),
        ui.spacing(16),
        ui.width(length.Fill),
        ui.align_x(alignment.Center),
      ],
      [
        ui.text("clock_display", model.time, [ui.font_size(48.0)]),
        ui.text("subtitle", "Updates every second", [
          ui.font_size(12.0),
          ui.text_color(muted),
        ]),
      ],
    ),
  ])
}

fn subscribe(_model: Model) -> List(subscription.Subscription) {
  [subscription.every(1000, "tick")]
}

fn current_time() -> String {
  let #(hour, minute, second) = erlang_localtime()
  pad2(hour) <> ":" <> pad2(minute) <> ":" <> pad2(second)
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

@external(erlang, "plushie_example_clock_ffi", "localtime_hms")
fn erlang_localtime() -> #(Int, Int, Int)

pub fn app() {
  app.simple(init, update, view)
  |> app.with_subscriptions(subscribe)
}

pub fn main() {
  case plushie.start(app(), plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      io.println_error(
        "Failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
