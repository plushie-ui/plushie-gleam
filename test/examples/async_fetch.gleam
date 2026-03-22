//// Async fetch example: demonstrates loading state pattern with
//// command.async for background work.

import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/io
import plushie
import plushie/app
import plushie/command
import plushie/event.{type Event, AsyncResult, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/padding
import plushie/ui

pub type Model {
  Model(status: Status, data: String)
}

pub type Status {
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

pub fn app() {
  app.simple(init, update, view)
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
