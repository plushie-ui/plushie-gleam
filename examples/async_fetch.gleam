//// Async fetch example: demonstrates loading state pattern with
//// command.async for background work.

import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import toddy
import toddy/app
import toddy/command
import toddy/event.{type Event, AsyncResult, WidgetClick}
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
    WidgetClick(id: "fetch", ..) -> #(
      Model(..model, status: Loading),
      command.async(fetch_data, "fetch"),
    )
    AsyncResult(tag: "fetch", result: Ok(value)) -> {
      let data = case decode.run(value, decode.string) {
        Ok(s) -> s
        Error(_) -> "unexpected value"
      }
      #(Model(status: Loaded, data:), command.none())
    }
    AsyncResult(tag: "fetch", result: Error(_)) -> #(
      Model(..model, status: Failed("fetch failed")),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn fetch_data() -> dynamic.Dynamic {
  // Simulate async work -- in a real app this would be an HTTP request
  process.sleep(500)
  dynamic.string("Hello from the async world")
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
