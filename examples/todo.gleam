//// To-do list example: text input, dynamic list, scoped events.

import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import plushie
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick, WidgetInput, WidgetSubmit}
import plushie/node.{type Node}
import plushie/prop/padding
import plushie/ui

pub type Model {
  Model(todos: List(String), input: String, next_id: Int)
}

fn init() {
  #(Model(todos: [], input: "", next_id: 1), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    WidgetInput(id: "new-todo", value:, ..) -> #(
      Model(..model, input: value),
      command.none(),
    )
    WidgetSubmit(id: "new-todo", ..) | WidgetClick(id: "add", ..) ->
      case model.input {
        "" -> #(model, command.none())
        text -> #(
          Model(
            todos: list.append(model.todos, [text]),
            input: "",
            next_id: model.next_id + 1,
          ),
          command.focus("new-todo"),
        )
      }
    WidgetClick(id: "clear", ..) -> #(
      Model(..model, todos: [], next_id: 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> Node {
  ui.window("main", [ui.title("To-Do List")], [
    ui.column("content", [ui.padding(padding.all(16.0)), ui.spacing(8)], [
      ui.row("input-row", [ui.spacing(8)], [
        ui.text_input("new-todo", model.input, [
          ui.placeholder("What needs doing?"),
          ui.on_submit(True),
        ]),
        ui.button_("add", "Add"),
      ]),
      ui.column(
        "todo-list",
        [ui.spacing(4)],
        list.index_map(model.todos, fn(item, idx) {
          ui.text_(
            "todo-" <> int.to_string(idx),
            int.to_string(idx + 1) <> ". " <> item,
          )
        }),
      ),
      ui.row("footer", [ui.spacing(8)], [
        ui.text_("count", int.to_string(list.length(model.todos)) <> " items"),
        ui.button_("clear", "Clear All"),
      ]),
    ]),
  ])
}

pub fn app() {
  app.simple(init, update, view)
}

pub fn main() {
  case plushie.start(app(), plushie.default_start_opts()) {
    Ok(_) -> process.sleep_forever()
    Error(err) ->
      io.println_error(
        "Failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
