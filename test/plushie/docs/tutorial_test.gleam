import gleam/dict
import gleam/int
import gleam/list
import gleam/string
import plushie/command
import plushie/event.{
  type Event, WidgetClick, WidgetInput, WidgetSubmit, WidgetToggle,
}
import plushie/node.{type Node, BoolVal, FloatVal, IntVal, StringVal}
import plushie/prop/length.{Fill}
import plushie/prop/padding
import plushie/ui

// -- Types (reproduced from tutorial doc) -------------------------------------

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

// -- Step 1 functions ---------------------------------------------------------

fn init() {
  #(Model(todos: [], input: "", filter: All, next_id: 1), command.none())
}

// -- Step 2+ update (full version from the complete app) ----------------------

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
          let new_todo =
            Todo(
              id: "todo_" <> int.to_string(model.next_id),
              text: model.input,
              done: False,
            )
          #(
            Model(
              ..model,
              todos: [new_todo, ..model.todos],
              input: "",
              next_id: model.next_id + 1,
            ),
            command.focus("app/new_todo"),
          )
        }
      }

    WidgetToggle(id: "toggle", scope: [_row, todo_id, ..], ..) -> {
      let todos =
        list.map(model.todos, fn(t) {
          case t.id == todo_id {
            True -> Todo(..t, done: !t.done)
            False -> t
          }
        })
      #(Model(..model, todos: todos), command.none())
    }

    WidgetClick(id: "delete", scope: [_row, todo_id, ..]) -> #(
      Model(..model, todos: list.filter(model.todos, fn(t) { t.id != todo_id })),
      command.none(),
    )

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

// -- View helpers (from step 6) -----------------------------------------------

fn filtered(model: Model) -> List(Todo) {
  case model.filter {
    All -> model.todos
    Active -> list.filter(model.todos, fn(t) { !t.done })
    Done -> list.filter(model.todos, fn(t) { t.done })
  }
}

fn todo_row(t: Todo) -> Node {
  ui.container(t.id, [], [
    ui.row("row", [ui.spacing(8)], [
      ui.checkbox("toggle", "", t.done, []),
      ui.text_("text", t.text),
      ui.button_("delete", "x"),
    ]),
  ])
}

// -- Step 1: initial view -----------------------------------------------------

fn step1_view(_model: Model) -> Node {
  ui.window("main", [ui.title("Todos")], [
    ui.column(
      "app",
      [ui.padding(padding.all(20.0)), ui.spacing(12), ui.width(Fill)],
      [
        ui.text("title", "My Todos", [ui.font_size(24.0)]),
        ui.text_("empty", "No todos yet"),
      ],
    ),
  ])
}

// -- Step 3: view with list ---------------------------------------------------

fn step3_view(model: Model) -> Node {
  ui.window("main", [ui.title("Todos")], [
    ui.column(
      "app",
      [ui.padding(padding.all(20.0)), ui.spacing(12), ui.width(Fill)],
      [
        ui.text("title", "My Todos", [ui.font_size(24.0)]),
        ui.text_input("new_todo", model.input, [
          ui.placeholder("What needs doing?"),
          ui.on_submit(True),
        ]),
        ui.column(
          "list",
          [ui.spacing(4)],
          list.map(model.todos, fn(t) {
            ui.container(t.id, [], [
              ui.row("row", [ui.spacing(8)], [
                ui.checkbox("toggle", "", t.done, []),
                ui.text_("text", t.text),
                ui.button_("delete", "x"),
              ]),
            ])
          }),
        ),
      ],
    ),
  ])
}

// -- Step 6: full view --------------------------------------------------------

fn full_view(model: Model) -> Node {
  ui.window("main", [ui.title("Todos")], [
    ui.column(
      "app",
      [ui.padding(padding.all(20.0)), ui.spacing(12), ui.width(Fill)],
      [
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
          list.map(filtered(model), fn(t) { todo_row(t) }),
        ),
      ],
    ),
  ])
}

// -- Tests --------------------------------------------------------------------

pub fn tutorial_step1_init_test() {
  let #(model, cmd) = init()
  assert model.todos == []
  assert model.input == ""
  assert model.next_id == 1
  assert cmd == command.none()
}

pub fn tutorial_step1_view_test() {
  let #(model, _) = init()
  let tree = step1_view(model)
  assert tree.kind == "window"
  assert dict.get(tree.props, "title") == Ok(StringVal("Todos"))

  let assert [col] = tree.children
  assert col.kind == "column"
  assert col.id == "app"
  assert dict.get(col.props, "spacing") == Ok(IntVal(12))
  assert dict.get(col.props, "width") == Ok(StringVal("fill"))

  let assert [title, empty] = col.children
  assert title.kind == "text"
  assert dict.get(title.props, "content") == Ok(StringVal("My Todos"))
  assert dict.get(title.props, "size") == Ok(FloatVal(24.0))
  assert empty.kind == "text"
  assert dict.get(empty.props, "content") == Ok(StringVal("No todos yet"))
}

pub fn tutorial_step2_input_updates_model_test() {
  let #(model, _) = init()
  let #(model, _) =
    update(model, WidgetInput(id: "new_todo", scope: [], value: "Buy milk"))
  assert model.input == "Buy milk"
}

pub fn tutorial_step2_submit_creates_todo_test() {
  let #(model, _) = init()
  let #(model, _) =
    update(model, WidgetInput(id: "new_todo", scope: [], value: "Buy milk"))
  let #(model, cmd) =
    update(model, WidgetSubmit(id: "new_todo", scope: [], value: "Buy milk"))
  assert model.input == ""
  assert model.next_id == 2
  let assert [item] = model.todos
  assert item.text == "Buy milk"
  assert item.id == "todo_1"
  assert item.done == False
  assert cmd == command.focus("app/new_todo")
}

pub fn tutorial_step2_empty_submit_does_nothing_test() {
  let #(model, _) = init()
  let #(model, _) =
    update(model, WidgetInput(id: "new_todo", scope: [], value: "   "))
  let #(model, cmd) =
    update(model, WidgetSubmit(id: "new_todo", scope: [], value: "   "))
  assert model.todos == []
  assert cmd == command.none()
}

pub fn tutorial_step2_view_has_text_input_test() {
  let #(model, _) = init()
  let model = Model(..model, input: "Hello")
  let tree = step3_view(model)
  let assert [col] = tree.children
  let assert [_title, input, _list] = col.children
  assert input.kind == "text_input"
  assert input.id == "new_todo"
  assert dict.get(input.props, "value") == Ok(StringVal("Hello"))
  assert dict.get(input.props, "placeholder")
    == Ok(StringVal("What needs doing?"))
  assert dict.get(input.props, "on_submit") == Ok(BoolVal(True))
}

pub fn tutorial_step3_view_renders_todo_list_test() {
  let model =
    Model(
      todos: [
        Todo(id: "todo_1", text: "Buy milk", done: False),
        Todo(id: "todo_2", text: "Walk dog", done: True),
      ],
      input: "",
      filter: All,
      next_id: 3,
    )
  let tree = step3_view(model)
  let assert [col] = tree.children
  let assert [_title, _input, list_col] = col.children
  assert list_col.kind == "column"
  assert list_col.id == "list"
  assert dict.get(list_col.props, "spacing") == Ok(IntVal(4))

  let assert [row1, row2] = list_col.children
  assert row1.id == "todo_1"
  assert row1.kind == "container"
  assert row2.id == "todo_2"
}

pub fn tutorial_step3_todo_row_structure_test() {
  let item = Todo(id: "todo_1", text: "Buy milk", done: False)
  let row = todo_row(item)
  assert row.id == "todo_1"
  assert row.kind == "container"
  let assert [inner_row] = row.children
  assert inner_row.kind == "row"
  assert inner_row.id == "row"
  assert dict.get(inner_row.props, "spacing") == Ok(IntVal(8))

  let assert [cb, text, btn] = inner_row.children
  assert cb.kind == "checkbox"
  assert cb.id == "toggle"
  assert dict.get(cb.props, "is_toggled") == Ok(BoolVal(False))
  assert text.kind == "text"
  assert dict.get(text.props, "content") == Ok(StringVal("Buy milk"))
  assert btn.kind == "button"
  assert btn.id == "delete"
  assert dict.get(btn.props, "label") == Ok(StringVal("x"))
}

pub fn tutorial_step4_toggle_test() {
  let model =
    Model(
      todos: [Todo(id: "todo_1", text: "Buy milk", done: False)],
      input: "",
      filter: All,
      next_id: 2,
    )
  let #(model, _) =
    update(
      model,
      WidgetToggle(
        id: "toggle",
        scope: ["row", "todo_1", "list", "app"],
        value: True,
      ),
    )
  let assert [item] = model.todos
  assert item.done == True
}

pub fn tutorial_step4_delete_test() {
  let model =
    Model(
      todos: [Todo(id: "todo_1", text: "Buy milk", done: False)],
      input: "",
      filter: All,
      next_id: 2,
    )
  let #(model, _) =
    update(
      model,
      WidgetClick(id: "delete", scope: ["row", "todo_1", "list", "app"]),
    )
  assert model.todos == []
}

pub fn tutorial_step6_filter_all_test() {
  let #(model, _) = init()
  let #(model, _) = update(model, WidgetClick(id: "filter_active", scope: []))
  assert model.filter == Active
  let #(model, _) = update(model, WidgetClick(id: "filter_all", scope: []))
  assert model.filter == All
}

pub fn tutorial_step6_filter_done_test() {
  let #(model, _) = init()
  let #(model, _) = update(model, WidgetClick(id: "filter_done", scope: []))
  assert model.filter == Done
}

pub fn tutorial_step6_filtered_helper_test() {
  let model =
    Model(
      todos: [
        Todo(id: "todo_1", text: "Buy milk", done: False),
        Todo(id: "todo_2", text: "Walk dog", done: True),
        Todo(id: "todo_3", text: "Read book", done: False),
      ],
      input: "",
      filter: All,
      next_id: 4,
    )
  assert list.length(filtered(model)) == 3
  assert list.length(filtered(Model(..model, filter: Active))) == 2
  assert list.length(filtered(Model(..model, filter: Done))) == 1
}

pub fn tutorial_step6_view_has_filter_buttons_test() {
  let #(model, _) = init()
  let tree = full_view(model)
  let assert [col] = tree.children
  let assert [_title, _input, filters, _list] = col.children
  assert filters.kind == "row"
  assert filters.id == "filters"
  let assert [all_btn, active_btn, done_btn] = filters.children
  assert all_btn.id == "filter_all"
  assert dict.get(all_btn.props, "label") == Ok(StringVal("All"))
  assert active_btn.id == "filter_active"
  assert done_btn.id == "filter_done"
}

pub fn tutorial_step6_view_filters_todos_test() {
  let model =
    Model(
      todos: [
        Todo(id: "todo_1", text: "Buy milk", done: False),
        Todo(id: "todo_2", text: "Walk dog", done: True),
      ],
      input: "",
      filter: Active,
      next_id: 3,
    )
  let tree = full_view(model)
  let assert [col] = tree.children
  let assert [_title, _input, _filters, list_col] = col.children
  let assert [row] = list_col.children
  assert row.id == "todo_1"
}
