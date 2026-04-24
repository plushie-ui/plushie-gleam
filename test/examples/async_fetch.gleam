//// Async fetch example: demonstrates loading state pattern with
//// command.async for background work.

@target(erlang)
import gleam/dynamic
@target(erlang)
import gleam/dynamic/decode
@target(erlang)
import gleam/erlang/process
@target(erlang)
import gleam/io
@target(erlang)
import plushie
@target(erlang)
import plushie/app
@target(erlang)
import plushie/command
@target(erlang)
import plushie/event.{type Event, Async, AsyncEvent, Click, EventTarget, Widget}
import plushie/node.{type Node}
import plushie/prop/color
import plushie/prop/length
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/text
import plushie/widget/window

pub type Model {
  Model(status: Status, data: String)
}

pub type Status {
  Idle
  Loading
  Loaded
  Failed(String)
}

@target(erlang)
fn init() {
  #(Model(status: Idle, data: ""), command.none())
}

@target(erlang)
fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "fetch", ..))) -> #(
      Model(..model, status: Loading),
      command.task(fetch_data, "fetch"),
    )
    Async(AsyncEvent(tag: "fetch", result: Ok(value))) -> {
      let data = case decode.run(value, decode.string) {
        Ok(s) -> s
        Error(_) -> "unexpected value"
      }
      #(Model(status: Loaded, data:), command.none())
    }
    Async(AsyncEvent(tag: "fetch", result: Error(_))) -> #(
      Model(..model, status: Failed("fetch failed")),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

@target(erlang)
fn fetch_data() -> dynamic.Dynamic {
  // Simulate async work; in a real app this would be an HTTP request
  process.sleep(500)
  dynamic.string("Hello from the async world")
}

@target(erlang)
fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("Async Fetch")], [
      ui.column(
        "content",
        [
          column.Padding(padding.all(24.0)),
          column.Spacing(16.0),
          column.Width(length.Fill),
        ],
        [
          ui.text("header", "Async Command Demo", [text.Size(20.0)]),
          ui.button_("fetch", "Fetch Data"),
          status_message(model),
        ],
      ),
    ]),
  ]
}

@target(erlang)
fn status_message(model: Model) -> Node {
  case model.status {
    Idle ->
      ui.text("status", "Press the button to start", [
        text.Color(hex("#888888")),
      ])
    Loading -> ui.text("status", "Loading...", [text.Color(hex("#cc8800"))])
    Loaded ->
      ui.column("result_col", [column.Spacing(4.0)], [
        ui.text("label", "Result:", [text.Size(14.0)]),
        ui.text("result", model.data, [text.Color(hex("#22aa44"))]),
      ])
    Failed(reason) ->
      ui.text("error", "Error: " <> reason, [text.Color(hex("#cc2222"))])
  }
}

@target(erlang)
fn hex(s: String) -> color.Color {
  let assert Ok(c) = color.from_hex(s)
  c
}

@target(erlang)
pub fn app() {
  app.simple(init, update, view)
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
