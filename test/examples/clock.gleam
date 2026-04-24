//// Clock example showing the current time, updated every second.
////
//// Demonstrates:
//// - `subscription.every` for timer-based updates
//// - Pattern matching on `TimerTick` in update
//// - Erlang FFI for wall-clock time

@target(erlang)
import gleam/int
@target(erlang)
import gleam/io
@target(erlang)
import plushie
@target(erlang)
import plushie/app
@target(erlang)
import plushie/command
@target(erlang)
import plushie/event.{type Event, Timer, TimerEvent}
@target(erlang)
import plushie/node.{type Node}
@target(erlang)
import plushie/prop/alignment
@target(erlang)
import plushie/prop/color
@target(erlang)
import plushie/prop/length
@target(erlang)
import plushie/prop/padding
@target(erlang)
import plushie/subscription
@target(erlang)
import plushie/ui
@target(erlang)
import plushie/widget/column
@target(erlang)
import plushie/widget/text
@target(erlang)
import plushie/widget/window

@target(erlang)
pub type Model {
  Model(time: String)
}

@target(erlang)
fn init() {
  #(Model(time: current_time()), command.none())
}

@target(erlang)
fn update(model: Model, event: Event) {
  case event {
    Timer(TimerEvent(tag: "tick", ..)) -> #(
      Model(time: current_time()),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

@target(erlang)
fn view(model: Model) -> List(Node) {
  let assert Ok(muted) = color.from_hex("#888888")

  [
    ui.window("main", [window.Title("Clock")], [
      ui.column(
        "content",
        [
          column.Padding(padding.all(24.0)),
          column.Spacing(16.0),
          column.Width(length.Fill),
          column.AlignX(alignment.Center),
        ],
        [
          ui.text("clock_display", model.time, [text.Size(48.0)]),
          ui.text("subtitle", "Updates every second", [
            text.Size(12.0),
            text.Color(muted),
          ]),
        ],
      ),
    ]),
  ]
}

@target(erlang)
fn subscribe(_model: Model) -> List(subscription.Subscription) {
  [subscription.every(1000, "tick")]
}

@target(erlang)
fn current_time() -> String {
  let #(hour, minute, second) = erlang_localtime()
  pad2(hour) <> ":" <> pad2(minute) <> ":" <> pad2(second)
}

@target(erlang)
fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

@external(erlang, "plushie_example_clock_ffi", "localtime_hms")
fn erlang_localtime() -> #(Int, Int, Int)

@target(erlang)
pub fn app() {
  app.simple(init, update, view)
  |> app.with_subscribe(subscribe)
}

@target(erlang)
pub fn main() {
  case plushie.start(app(), plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      io.println_error(
        "Failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
