//// Clock example: timer subscription, derived display.

import gleam/int
import gleam/io
import plushie
import plushie/app
import plushie/command
import plushie/event.{type Event, TimerTick}
import plushie/node.{type Node}
import plushie/prop/padding
import plushie/subscription
import plushie/ui

pub type Model {
  Model(seconds: Int)
}

fn init() {
  #(Model(seconds: 0), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    TimerTick(tag: "tick", ..) -> #(
      Model(seconds: model.seconds + 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Node {
  let hours = model.seconds / 3600
  let minutes = { model.seconds % 3600 } / 60
  let secs = model.seconds % 60
  let display = pad2(hours) <> ":" <> pad2(minutes) <> ":" <> pad2(secs)

  ui.window("main", [ui.title("Clock")], [
    ui.column("content", [ui.padding(padding.all(32.0)), ui.spacing(8)], [
      ui.text("time", display, [ui.font_size(48.0)]),
      ui.text_("label", "Elapsed time"),
    ]),
  ])
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

fn subscribe(_model: Model) -> List(subscription.Subscription) {
  [subscription.every(1000, "tick")]
}

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
