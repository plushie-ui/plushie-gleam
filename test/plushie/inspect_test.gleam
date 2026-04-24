import gleam/string
import gleeunit/should
import plushie/app
import plushie/command
import plushie/event.{type Event}
import plushie/inspect
import plushie/ui
import plushie/widget/window

type Model {
  Model
}

fn init() {
  #(Model, command.none())
}

fn update(model: Model, _event: Event) {
  #(model, command.none())
}

fn view(_model: Model) {
  [
    ui.window("main", [window.Title("Inspect Test")], [
      ui.text_("label", "Hello"),
    ]),
  ]
}

fn message_contains(err: inspect.InspectError, text: String) {
  inspect.error_message(err)
  |> string.contains(text)
  |> should.be_true
}

pub fn to_json_returns_initial_tree_test() {
  let my_app = app.simple(init, update, view)
  let assert Ok(json) = inspect.to_json(my_app)

  json
  |> string.contains("window")
  |> should.be_true

  json
  |> string.contains("main#label")
  |> should.be_true
}

pub fn to_json_reports_init_crash_test() {
  let my_app = app.simple(fn() { panic as "init broke" }, update, view)

  let assert Error(err) = inspect.to_json(my_app)
  message_contains(err, "app init")
  message_contains(err, "init broke")
}

pub fn to_json_reports_view_crash_test() {
  let my_app = app.simple(init, update, fn(_model) { panic as "view broke" })

  let assert Error(err) = inspect.to_json(my_app)
  message_contains(err, "app view")
  message_contains(err, "view broke")
}

pub fn to_json_reports_normalization_crash_test() {
  let my_app =
    app.simple(init, update, fn(_model) {
      [
        ui.window("main", [], [
          ui.column("body", [], [
            ui.text_("dup", "First"),
            ui.text_("dup", "Second"),
          ]),
        ]),
      ]
    })

  let assert Error(err) = inspect.to_json(my_app)
  message_contains(err, "tree normalization")
}
