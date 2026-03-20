//// Async fetch example: demonstrates loading state pattern.
////
//// Note: Command.async is not yet fully implemented in the runtime.
//// This example shows the intended API pattern.

import gleam/erlang/process
import toddy
import toddy/app
import toddy/command
import toddy/event.{type Event, WidgetClick}
import toddy/node.{type Node}
import toddy/prop/padding
import toddy/ui

type Model {
  Model(status: Status, data: String)
}

type Status {
  Idle
  Loading
  Loaded
  Failed(String)
}

fn init() {
  #(Model(status: Idle, data: ""), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    WidgetClick(id: "fetch", ..) ->
      // When async is implemented, this would be:
      // #(Model(..model, status: Loading), command.async(fetch_data, "fetch"))
      #(Model(status: Loading, data: ""), command.none())
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Node {
  let status_text = case model.status {
    Idle -> "Click Fetch to load data"
    Loading -> "Loading..."
    Loaded -> "Data: " <> model.data
    Failed(reason) -> "Error: " <> reason
  }

  ui.window("main", [ui.title("Async Fetch")], [
    ui.column("content", [ui.padding(padding.all(16.0)), ui.spacing(12)], [
      ui.text_("status", status_text),
      ui.button("fetch", "Fetch Data", [
        ui.disabled(model.status == Loading),
      ]),
    ]),
  ])
}

pub fn main() {
  let my_app = app.simple(init, update, view)
  let _ = toddy.start(my_app, toddy.default_start_opts())
  process.sleep_forever()
}
