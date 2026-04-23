import gleam/dict
import gleam/option
import plushie/app.{type Settings, Settings}
import plushie/command
import plushie/event.{type Event, Click, EventTarget, Input, Submit, Widget}
import plushie/node.{StringVal}
import plushie/prop/padding
import plushie/subscription
import plushie/ui
import plushie/widget/column
import plushie/widget/row
import plushie/widget/text_input
import plushie/widget/window

// -- Types (for update/view examples) -----------------------------------------

type Todo {
  Todo(id: Int, text: String, done: Bool)
}

type Model {
  Model(todos: List(Todo), input: String, auto_refresh: Bool, next_id: Int)
}

fn next_id(model: Model) -> Int {
  model.next_id
}

// -- init examples ------------------------------------------------------------

fn init_simple() {
  #(
    Model(todos: [], input: "", auto_refresh: False, next_id: 1),
    command.none(),
  )
}

// -- update example -----------------------------------------------------------

fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "add_todo", ..))) -> {
      let new_todo = Todo(id: next_id(model), text: model.input, done: False)
      #(
        Model(
          ..model,
          todos: [new_todo, ..model.todos],
          input: "",
          next_id: model.next_id + 1,
        ),
        command.none(),
      )
    }

    Widget(Input(target: EventTarget(id: "todo_field", ..), value:)) -> #(
      Model(..model, input: value),
      command.none(),
    )

    Widget(Submit(target: EventTarget(id: "todo_field", ..), ..)) -> {
      let new_todo = Todo(id: next_id(model), text: model.input, done: False)
      #(
        Model(
          ..model,
          todos: [new_todo, ..model.todos],
          input: "",
          next_id: model.next_id + 1,
        ),
        command.focus("todo_field"),
      )
    }

    _ -> #(model, command.none())
  }
}

// -- subscribe example --------------------------------------------------------

fn subscribe(model: Model) -> List(subscription.Subscription) {
  let subs = [subscription.on_key_press()]

  case model.auto_refresh {
    True -> [subscription.every(5000, "refresh"), ..subs]
    False -> subs
  }
}

// -- settings example ---------------------------------------------------------

fn settings() -> Settings {
  Settings(
    ..app.default_settings(),
    default_text_size: 16.0,
    antialiasing: True,
    fonts: ["priv/fonts/Inter.ttf"],
  )
}

// -- window_config example ----------------------------------------------------

fn window_config(_model: Model) -> dict.Dict(String, node.PropValue) {
  dict.new()
}

// -- Tests --------------------------------------------------------------------

pub fn app_behaviour_init_simple_test() {
  let #(model, cmd) = init_simple()
  assert model.todos == []
  assert model.input == ""
  assert cmd == command.none()
}

pub fn app_behaviour_update_add_todo_test() {
  let #(model, _) = init_simple()
  let #(model, _) =
    update(
      model,
      Widget(Input(
        target: EventTarget(
          window_id: "main",
          id: "todo_field",
          scope: [],
          full: "todo_field",
        ),
        value: "Buy milk",
      )),
    )
  assert model.input == "Buy milk"

  let #(model, cmd) =
    update(
      model,
      Widget(
        Click(target: EventTarget(
          window_id: "main",
          id: "add_todo",
          scope: [],
          full: "add_todo",
        )),
      ),
    )
  assert model.input == ""
  let assert [item] = model.todos
  assert item.text == "Buy milk"
  assert item.done == False
  assert cmd == command.none()
}

pub fn app_behaviour_update_submit_returns_focus_test() {
  let #(model, _) = init_simple()
  let #(model, _) =
    update(
      model,
      Widget(Input(
        target: EventTarget(
          window_id: "main",
          id: "todo_field",
          scope: [],
          full: "todo_field",
        ),
        value: "Walk dog",
      )),
    )
  let #(model, cmd) =
    update(
      model,
      Widget(Submit(
        target: EventTarget(
          window_id: "main",
          id: "todo_field",
          scope: [],
          full: "todo_field",
        ),
        value: "Walk dog",
      )),
    )
  assert model.input == ""
  let assert [item] = model.todos
  assert item.text == "Walk dog"
  assert cmd == command.focus("todo_field")
}

pub fn app_behaviour_update_unknown_event_test() {
  let #(model, _) = init_simple()
  let #(model, cmd) =
    update(
      model,
      Widget(
        Click(target: EventTarget(
          window_id: "main",
          id: "unknown",
          scope: [],
          full: "unknown",
        )),
      ),
    )
  assert model.todos == []
  assert cmd == command.none()
}

pub fn app_behaviour_subscribe_without_auto_refresh_test() {
  let model = Model(todos: [], input: "", auto_refresh: False, next_id: 1)
  let subs = subscribe(model)
  let assert [sub] = subs
  assert sub == subscription.on_key_press()
}

pub fn app_behaviour_subscribe_with_auto_refresh_test() {
  let model = Model(todos: [], input: "", auto_refresh: True, next_id: 1)
  let subs = subscribe(model)
  let assert [timer, key_sub] = subs
  assert timer == subscription.every(5000, "refresh")
  assert key_sub == subscription.on_key_press()
}

pub fn app_behaviour_settings_test() {
  let s = settings()
  assert s.default_text_size == 16.0
  assert s.antialiasing == True
  assert s.fonts == ["priv/fonts/Inter.ttf"]
  assert s.vsync == True
  assert s.scale_factor == 1.0
  assert s.theme == option.None
  assert s.default_font == option.None
}

pub fn app_behaviour_default_settings_test() {
  let s = app.default_settings()
  assert s.antialiasing == True
  assert s.default_text_size == 16.0
  assert s.vsync == True
  assert s.scale_factor == 1.0
  assert s.fonts == []
  assert s.theme == option.None
  assert s.default_font == option.None
  assert s.default_event_rate == option.None
}

pub fn app_behaviour_window_config_returns_empty_dict_test() {
  let model = Model(todos: [], input: "", auto_refresh: False, next_id: 1)
  let config = window_config(model)
  assert dict.size(config) == 0
}

pub fn app_behaviour_window_command_set_window_mode_test() {
  let cmd = command.SetWindowMode(window_id: "main", mode: "fullscreen")
  assert cmd.window_id == "main"
  assert cmd.mode == "fullscreen"
}

pub fn app_behaviour_window_close_command_test() {
  let cmd = command.close_window("main")
  assert cmd
    == command.Renderer(command.Window(command.CloseWindow(window_id: "main")))
}

pub fn app_behaviour_simple_constructor_test() {
  let _app =
    app.simple(init_simple, update, fn(_model: Model) {
      option.Some(ui.window("main", [window.Title("App")], []))
    })
  Nil
}

pub fn app_behaviour_pipeline_with_subscriptions_test() {
  let _app =
    app.simple(init_simple, update, fn(_model: Model) {
      option.Some(ui.window("main", [window.Title("App")], []))
    })
    |> app.with_subscriptions(subscribe)
    |> app.with_settings(settings)
  Nil
}

pub fn app_behaviour_view_basic_structure_test() {
  let tree =
    ui.window("main", [window.Title("Todos")], [
      ui.column(
        "content",
        [column.Padding(padding.all(16.0)), column.Spacing(8.0)],
        [
          ui.row("input-row", [row.Spacing(8.0)], [
            ui.text_input("todo_field", "", [
              text_input.Placeholder("What needs doing?"),
              text_input.OnSubmit(True),
            ]),
            ui.button_("add_todo", "Add"),
          ]),
        ],
      ),
    ])
  assert tree.kind == "window"
  let assert [col] = tree.children
  assert col.kind == "column"
  let assert [row] = col.children
  assert row.kind == "row"
  let assert [input, btn] = row.children
  assert input.kind == "text_input"
  assert dict.get(input.props, "on_submit") == Ok(node.BoolVal(True))
  assert btn.kind == "button"
  assert dict.get(btn.props, "label") == Ok(StringVal("Add"))
}

pub fn app_behaviour_dialog_window_test() {
  let dialog =
    ui.window("confirm", [], [
      ui.column(
        "dialog",
        [column.Padding(padding.all(16.0)), column.Spacing(12.0)],
        [
          ui.text_("prompt", "Are you sure?"),
          ui.row("buttons", [row.Spacing(8.0)], [
            ui.button_("confirm_yes", "Yes"),
            ui.button_("confirm_no", "No"),
          ]),
        ],
      ),
    ])
  assert dialog.kind == "window"
  assert dialog.id == "confirm"
  let assert [col] = dialog.children
  let assert [prompt, btns] = col.children
  assert dict.get(prompt.props, "content") == Ok(StringVal("Are you sure?"))
  let assert [yes, no] = btns.children
  assert dict.get(yes.props, "label") == Ok(StringVal("Yes"))
  assert dict.get(no.props, "label") == Ok(StringVal("No"))
}
