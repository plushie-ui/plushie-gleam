# Tutorial: building a todo app

This tutorial walks through building a complete todo app, introducing
one concept per step. By the end you'll understand text inputs,
dynamic lists, scoped IDs, commands, and conditional rendering.

## Step 1: the model

Start with a model that tracks a list of todos and the current input
text.

<!-- test: tutorial_step1_init_test, tutorial_step1_view_test -- keep this code block in sync with the test -->
```gleam
import gleam/list
import toddy/app
import toddy/cli/gui
import toddy/command
import toddy/event.{type Event}
import toddy/node.{type Node}
import toddy/prop/length.{Fill}
import toddy/prop/padding
import toddy/ui

type Todo {
  Todo(id: String, text: String, done: Bool)
}

type Filter {
  All
  Active
  Done
}

type Model {
  Model(todos: List(Todo), input: String, filter: Filter, next_id: Int)
}

fn init() {
  #(Model(todos: [], input: "", filter: All, next_id: 1), command.none())
}

fn update(model: Model, _event: Event) {
  #(model, command.none())
}

fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Todos")], [
    ui.column("app", [ui.padding(padding.all(20.0)), ui.spacing(12), ui.width(Fill)], [
      ui.text("title", "My Todos", [ui.font_size(24.0)]),
      ui.text_("empty", "No todos yet"),
    ]),
  ])
}

pub fn main() {
  gui.run(app.simple(init, update, view), gui.default_opts())
}
```

Run it with `gleam run -m todo_app`. You'll see a title and a placeholder
message. Not much yet, but the structure is in place: `init` sets
up state, `view` renders it.

## Step 2: adding a text input

Add a text input that updates the model on every keystroke, and a
submit handler that creates a todo when the user presses Enter.

<!-- test: tutorial_step2_input_updates_model_test, tutorial_step2_submit_creates_todo_test, tutorial_step2_empty_submit_does_nothing_test -- keep this code block in sync with the test -->
```gleam
import toddy/event.{type Event, WidgetInput, WidgetSubmit}
import gleam/int
import gleam/string

fn update(model: Model, event: Event) {
  case event {
    WidgetInput(id: "new_todo", value: val, ..) -> #(
      Model(..model, input: val),
      command.none(),
    )
    WidgetSubmit(id: "new_todo", ..) ->
      case string.trim(model.input) {
        "" -> #(model, command.none())
        _ -> {
          let todo = Todo(
            id: "todo_" <> int.to_string(model.next_id),
            text: model.input,
            done: False,
          )
          #(
            Model(
              ..model,
              todos: [todo, ..model.todos],
              input: "",
              next_id: model.next_id + 1,
            ),
            command.none(),
          )
        }
      }
    _ -> #(model, command.none())
  }
}
```

And the view:

<!-- test: tutorial_step2_view_has_text_input_test -- keep this code block in sync with the test -->
```gleam
fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Todos")], [
    ui.column("app", [ui.padding(padding.all(20.0)), ui.spacing(12), ui.width(Fill)], [
      ui.text("title", "My Todos", [ui.font_size(24.0)]),
      ui.text_input("new_todo", model.input, [
        ui.placeholder("What needs doing?"),
        ui.on_submit(True),
      ]),
    ]),
  ])
}
```

Type something and press Enter. The input clears (the model's
`input` resets to `""`), but you can't see the todos yet. Let's
fix that.

## Step 3: rendering the list with scoped IDs

Each todo needs its own row with a checkbox and a delete button.
We wrap each item in a named container using the todo's ID. This
creates a **scope** -- children get unique IDs automatically
without manual prefixing.

<!-- test: tutorial_step3_view_renders_todo_list_test, tutorial_step3_todo_row_structure_test -- keep this code block in sync with the test -->
```gleam
fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Todos")], [
    ui.column("app", [ui.padding(padding.all(20.0)), ui.spacing(12), ui.width(Fill)], [
      ui.text("title", "My Todos", [ui.font_size(24.0)]),
      ui.text_input("new_todo", model.input, [
        ui.placeholder("What needs doing?"),
        ui.on_submit(True),
      ]),
      ui.column(
        "list",
        [ui.spacing(4)],
        list.map(model.todos, fn(todo) {
          ui.container(todo.id, [], [
            ui.row("row", [ui.spacing(8)], [
              ui.checkbox("toggle", "", todo.done, []),
              ui.text_("text", todo.text),
              ui.button_("delete", "x"),
            ]),
          ])
        }),
      ),
    ]),
  ])
}
```

Each todo row has `id: todo.id` (e.g., `"todo_1"`). Inside it,
the checkbox has local id `"toggle"` and the button has `"delete"`.
On the wire, these become `"list/todo_1/row/toggle"` and
`"list/todo_1/row/delete"` -- unique across all items.

## Step 4: handling toggle and delete with scope

When the checkbox or delete button is clicked, the event carries the
local `id` and a `scope` list with the todo's row ID as the
immediate parent. Pattern match on both:

<!-- test: tutorial_step4_toggle_test, tutorial_step4_delete_test -- keep this code block in sync with the test -->
```gleam
import toddy/event.{
  type Event, WidgetClick, WidgetInput, WidgetSubmit, WidgetToggle,
}

fn update(model: Model, event: Event) {
  case event {
    // ... input and submit handlers from step 2 ...

    WidgetToggle(id: "toggle", scope: [_row, todo_id, ..], ..) -> {
      let todos = list.map(model.todos, fn(t) {
        case t.id == todo_id {
          True -> Todo(..t, done: !t.done)
          False -> t
        }
      })
      #(Model(..model, todos: todos), command.none())
    }

    WidgetClick(id: "delete", scope: [_row, todo_id, ..], ..) -> #(
      Model(..model, todos: list.filter(model.todos, fn(t) { t.id != todo_id })),
      command.none(),
    )

    _ -> #(model, command.none())
  }
}
```

The `scope: [_row, todo_id, ..]` pattern binds the container's ID
(e.g., `"todo_1"`) regardless of how deep the row is nested. If you
later move the list into a sidebar or tab, the pattern still works.

## Step 5: refocusing with a command

After submitting a todo, the text input loses focus. Let's refocus
it automatically using `command.focus`:

<!-- test: tutorial_step2_submit_creates_todo_test -- keep this code block in sync with the test -->
```gleam
WidgetSubmit(id: "new_todo", ..) ->
  case string.trim(model.input) {
    "" -> #(model, command.none())
    _ -> {
      let todo = Todo(
        id: "todo_" <> int.to_string(model.next_id),
        text: model.input,
        done: False,
      )
      #(
        Model(
          ..model,
          todos: [todo, ..model.todos],
          input: "",
          next_id: model.next_id + 1,
        ),
        command.focus("app/new_todo"),
      )
    }
  }
```

Note the scoped path `"app/new_todo"` -- the text input is inside
the `"app"` column, so its full ID is `"app/new_todo"`. Commands
always use the full scoped path.

## Step 6: filtering

Add filter buttons that toggle between all, active, and completed
todos.

<!-- test: tutorial_step6_filter_all_test, tutorial_step6_filter_done_test -- keep this code block in sync with the test -->
```gleam
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
```

Add the filter buttons and apply the filter in the view:

<!-- test: tutorial_step6_view_has_filter_buttons_test, tutorial_step6_view_filters_todos_test, tutorial_step6_filtered_helper_test -- keep this code block in sync with the test -->
```gleam
fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Todos")], [
    ui.column("app", [ui.padding(padding.all(20.0)), ui.spacing(12), ui.width(Fill)], [
      ui.text("title", "My Todos", [ui.font_size(24.0)]),
      ui.text_input("new_todo", model.input, [
        ui.placeholder("What needs doing?"),
        ui.on_submit(True),
      ]),
      ui.row("filters", [ui.spacing(8)], [
        ui.button_("filter_all", "All"),
        ui.button_("filter_active", "Active"),
        ui.button_("filter_done", "Done"),
      ]),
      ui.column(
        "list",
        [ui.spacing(4)],
        list.map(filtered(model), fn(todo) {
          todo_row(todo)
        }),
      ),
    ]),
  ])
}

fn filtered(model: Model) -> List(Todo) {
  case model.filter {
    All -> model.todos
    Active -> list.filter(model.todos, fn(t) { !t.done })
    Done -> list.filter(model.todos, fn(t) { t.done })
  }
}

fn todo_row(todo: Todo) -> Node {
  ui.container(todo.id, [], [
    ui.row("row", [ui.spacing(8)], [
      ui.checkbox("toggle", "", todo.done, []),
      ui.text_("text", todo.text),
      ui.button_("delete", "x"),
    ]),
  ])
}
```

Notice `todo_row` is extracted as a view helper. In Gleam, each
function that builds UI nodes simply calls `ui.*` functions and
returns a `Node`.

## The complete app

The full source is in
[`examples/todo.gleam`](https://github.com/toddy-ui/toddy-gleam/blob/main/examples/todo.gleam)
with tests in
[`test/toddy/examples/todo_test.gleam`](https://github.com/toddy-ui/toddy-gleam/blob/main/test/toddy/examples/todo_test.gleam).

```gleam
import gleam/int
import gleam/list
import gleam/string
import toddy/app
import toddy/cli/gui
import toddy/command
import toddy/event.{
  type Event, WidgetClick, WidgetInput, WidgetSubmit, WidgetToggle,
}
import toddy/node.{type Node}
import toddy/prop/length.{Fill}
import toddy/prop/padding
import toddy/ui

// -- Types -------------------------------------------------------------------

type Todo {
  Todo(id: String, text: String, done: Bool)
}

type Filter {
  All
  Active
  Done
}

type Model {
  Model(todos: List(Todo), input: String, filter: Filter, next_id: Int)
}

// -- Init --------------------------------------------------------------------

fn init() {
  #(Model(todos: [], input: "", filter: All, next_id: 1), command.none())
}

// -- Update ------------------------------------------------------------------

fn update(model: Model, event: Event) {
  case event {
    WidgetInput(id: "new_todo", value: val, ..) -> #(
      Model(..model, input: val),
      command.none(),
    )

    WidgetSubmit(id: "new_todo", ..) ->
      case string.trim(model.input) {
        "" -> #(model, command.none())
        _ -> {
          let todo = Todo(
            id: "todo_" <> int.to_string(model.next_id),
            text: model.input,
            done: False,
          )
          #(
            Model(
              ..model,
              todos: [todo, ..model.todos],
              input: "",
              next_id: model.next_id + 1,
            ),
            command.focus("app/new_todo"),
          )
        }
      }

    WidgetToggle(id: "toggle", scope: [_row, todo_id, ..], ..) -> {
      let todos = list.map(model.todos, fn(t) {
        case t.id == todo_id {
          True -> Todo(..t, done: !t.done)
          False -> t
        }
      })
      #(Model(..model, todos: todos), command.none())
    }

    WidgetClick(id: "delete", scope: [_row, todo_id, ..], ..) -> #(
      Model(..model, todos: list.filter(model.todos, fn(t) { t.id != todo_id })),
      command.none(),
    )

    WidgetClick(id: "filter_all", ..) -> #(Model(..model, filter: All), command.none())
    WidgetClick(id: "filter_active", ..) -> #(Model(..model, filter: Active), command.none())
    WidgetClick(id: "filter_done", ..) -> #(Model(..model, filter: Done), command.none())

    _ -> #(model, command.none())
  }
}

// -- View --------------------------------------------------------------------

fn view(model: Model) -> Node {
  ui.window("main", [ui.title("Todos")], [
    ui.column("app", [ui.padding(padding.all(20.0)), ui.spacing(12), ui.width(Fill)], [
      ui.text("title", "My Todos", [ui.font_size(24.0)]),
      ui.text_input("new_todo", model.input, [
        ui.placeholder("What needs doing?"),
        ui.on_submit(True),
      ]),
      ui.row("filters", [ui.spacing(8)], [
        ui.button_("filter_all", "All"),
        ui.button_("filter_active", "Active"),
        ui.button_("filter_done", "Done"),
      ]),
      ui.column(
        "list",
        [ui.spacing(4)],
        list.map(filtered(model), fn(todo) {
          todo_row(todo)
        }),
      ),
    ]),
  ])
}

fn filtered(model: Model) -> List(Todo) {
  case model.filter {
    All -> model.todos
    Active -> list.filter(model.todos, fn(t) { !t.done })
    Done -> list.filter(model.todos, fn(t) { t.done })
  }
}

fn todo_row(todo: Todo) -> Node {
  ui.container(todo.id, [], [
    ui.row("row", [ui.spacing(8)], [
      ui.checkbox("toggle", "", todo.done, []),
      ui.text_("text", todo.text),
      ui.button_("delete", "x"),
    ]),
  ])
}

pub fn main() {
  gui.run(app.simple(init, update, view), gui.default_opts())
}
```

## What you've learned

- **Text inputs** with `ui.on_submit(True)` for form-like behavior
- **Scoped IDs** via named containers (`ui.container(todo.id, ..)`)
- **Scope binding** in update (`scope: [_row, todo_id, ..]`)
- **Commands** for side effects (`command.focus` with scoped paths)
- **Conditional rendering** with filter functions
- **View helpers** extracted as private functions

## Next steps

- [Commands](commands.md) -- async work, file dialogs, timers
- [Scoped IDs](scoped-ids.md) -- full scoping reference
- [Composition patterns](composition-patterns.md) -- scaling beyond
  a single module
- [Testing](testing.md) -- unit and integration testing
