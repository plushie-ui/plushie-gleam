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
import plushie/prop/color
import plushie/prop/length
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
  ui.window("main", [ui.title("Async Fetch")], [
    ui.column(
      "content",
      [
        ui.padding(padding.all(24.0)),
        ui.spacing(16),
        ui.width(length.Fill),
      ],
      [
        ui.text("header", "Async Command Demo", [ui.font_size(20.0)]),
        ui.button_("fetch", "Fetch Data"),
        status_message(model),
      ],
    ),
  ])
}

fn status_message(model: Model) -> Node {
  case model.status {
    Idle ->
      ui.text("status", "Press the button to start", [
        ui.text_color(hex("#888888")),
      ])
    Loading -> ui.text("status", "Loading...", [ui.text_color(hex("#cc8800"))])
    Loaded ->
      ui.column("result_col", [ui.spacing(4)], [
        ui.text("label", "Result:", [ui.font_size(14.0)]),
        ui.text("result", model.data, [ui.text_color(hex("#22aa44"))]),
      ])
    Failed(reason) ->
      ui.text("error", "Error: " <> reason, [ui.text_color(hex("#cc2222"))])
  }
}

fn hex(s: String) -> color.Color {
  let assert Ok(c) = color.from_hex(s)
  c
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
