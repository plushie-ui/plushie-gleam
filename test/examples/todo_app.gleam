//// To-do list with add, toggle, delete, and filter.
////
//// Demonstrates:
//// - `text_input` with `on_submit` for keyboard-driven entry
//// - Scoped IDs via container wrapping for dynamic list items
//// - `command.focus` with scoped paths for refocusing
//// - Filter buttons with conditional list rendering

import gleam/int
import gleam/io
import gleam/list
import gleam/string
import plushie
import plushie/app
import plushie/command
import plushie/event.{
  type Event, WidgetClick, WidgetInput, WidgetSubmit, WidgetToggle,
}
import plushie/node.{type Node}
import plushie/prop/length
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/row
import plushie/widget/text
import plushie/widget/text_input
import plushie/widget/window

// -- Model --------------------------------------------------------------------

pub type Todo {
  Todo(id: String, text: String, done: Bool)
}

pub type Filter {
  All
  Active
  Done
}

pub type Model {
  Model(todos: List(Todo), input: String, filter: Filter, next_id: Int)
}

fn init() {
  #(Model(todos: [], input: "", filter: All, next_id: 1), command.none())
}

// -- Update -------------------------------------------------------------------

fn update(model: Model, event: Event) {
  case event {
    WidgetInput(id: "new_todo", value: val, ..) -> #(
      Model(..model, input: val),
      command.none(),
    )

    WidgetSubmit(id: "new_todo", ..) -> add_todo(model)

    WidgetToggle(id: "toggle", scope: [todo_id, ..], ..) -> {
      let todos =
        list.map(model.todos, fn(t) {
          case t.id == todo_id {
            True -> Todo(..t, done: !t.done)
            False -> t
          }
        })
      #(Model(..model, todos: todos), command.none())
    }

    WidgetClick(id: "delete", scope: [todo_id, ..]) -> {
      let todos = list.filter(model.todos, fn(t) { t.id != todo_id })
      #(Model(..model, todos: todos), command.none())
    }

    WidgetClick(id: "filter_all", ..) -> #(
      Model(..model, filter: All),
      command.none(),
    )
    WidgetClick(id: "filter_active", ..) -> #(
      Model(..model, filter: Active),
      command.none(),
    )
    WidgetClick(id: "filter_done", ..) -> #(
      Model(..model, filter: Done),
      command.none(),
    )

    _ -> #(model, command.none())
  }
}

fn add_todo(model: Model) {
  case string.trim(model.input) {
    "" -> #(model, command.none())
    _ -> {
      let item =
        Todo(
          id: "todo_" <> int.to_string(model.next_id),
          text: model.input,
          done: False,
        )
      let new_model =
        Model(
          ..model,
          todos: [item, ..model.todos],
          input: "",
          next_id: model.next_id + 1,
        )
      #(new_model, command.focus("app/new_todo"))
    }
  }
}

// -- View ---------------------------------------------------------------------

fn view(model: Model) -> Node {
  ui.window("main", [window.Title("Todos")], [
    ui.column(
      "app",
      [
        column.Padding(padding.all(20.0)),
        column.Spacing(12),
        column.Width(length.Fill),
      ],
      [
        ui.text("title", "My Todos", [text.Size(24.0)]),
        ui.text_input("new_todo", model.input, [
          text_input.Placeholder("What needs doing?"),
          text_input.OnSubmit(True),
        ]),
        ui.row("filters", [row.Spacing(8)], [
          ui.button_("filter_all", "All"),
          ui.button_("filter_active", "Active"),
          ui.button_("filter_done", "Done"),
        ]),
        ui.column(
          "list",
          [column.Spacing(4)],
          filtered(model) |> list.map(todo_row),
        ),
      ],
    ),
  ])
}

fn filtered(model: Model) -> List(Todo) {
  case model.filter {
    All -> model.todos
    Active -> list.filter(model.todos, fn(t) { !t.done })
    Done -> list.filter(model.todos, fn(t) { t.done })
  }
}

fn todo_row(entry: Todo) -> Node {
  ui.container(entry.id, [], [
    ui.row("row", [row.Spacing(8)], [
      ui.checkbox("toggle", "", entry.done, []),
      ui.text_("text", entry.text),
      ui.button_("delete", "x"),
    ]),
  ])
}

// -- Entry point --------------------------------------------------------------

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
