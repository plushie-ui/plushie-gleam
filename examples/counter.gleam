//// Counter example: demonstrates the basic toddy app pattern.

import gleam/erlang/process
import gleam/int
import toddy
import toddy/app
import toddy/command
import toddy/event.{type Event, WidgetClick}
import toddy/node.{type Node}
import toddy/prop/padding
import toddy/ui

type Model {
  Model(count: Int)
}

fn init() {
  #(Model(count: 0), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "inc", ..) -> #(
      Model(count: model.count + 1),
      command.none(),
    )
    WidgetClick(id: "dec", ..) -> #(
      Model(count: model.count - 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Counter")], [
    ui.column("content", [ui.padding(padding.all(16.0)), ui.spacing(8)], [
      ui.text_("count", "Count: " <> int.to_string(model.count)),
      ui.row("buttons", [ui.spacing(8)], [
        ui.button_("inc", "+"),
        ui.button_("dec", "-"),
      ]),
    ]),
  ])
}

pub fn main() {
  let counter = app.simple(init, update, view)
  let _ = toddy.start(counter, toddy.default_start_opts())
  process.sleep_forever()
}
