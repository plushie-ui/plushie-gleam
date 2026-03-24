//// Counter example: demonstrates the basic plushie app pattern.

import gleam/int
import gleam/io
import plushie
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node}
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/row
import plushie/widget/window

pub type Model {
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
  ui.window("main", [window.Title("Counter")], [
    ui.column(
      "content",
      [column.Padding(padding.all(16.0)), column.Spacing(8)],
      [
        ui.text_("count", "Count: " <> int.to_string(model.count)),
        ui.row("buttons", [row.Spacing(8)], [
          ui.button_("inc", "+"),
          ui.button_("dec", "-"),
        ]),
      ],
    ),
  ])
}

pub fn app() {
  app.simple(init, update, view)
}

pub fn main() {
  case plushie.start(app(), plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) -> {
      io.println_error(
        "Failed to start: " <> plushie.start_error_to_string(err),
      )
    }
  }
}
