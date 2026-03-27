import gleam/dict
import gleam/int
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node, FloatVal, IntVal, StringVal}
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/row
import plushie/widget/text
import plushie/widget/window

// -- Types (reproduced from the getting-started doc) --------------------------

type Model {
  Model(count: Int)
}

fn init() {
  #(Model(count: 0), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    WidgetClick(window_id: "main", id: "increment", ..) -> #(
      Model(count: model.count + 1),
      command.none(),
    )
    WidgetClick(window_id: "main", id: "decrement", ..) -> #(
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
        ui.text("count", "Count: " <> int.to_string(model.count), [
          text.Size(20.0),
        ]),
        ui.row("buttons", [row.Spacing(8)], [
          ui.button_("increment", "+"),
          ui.button_("decrement", "-"),
        ]),
      ],
    ),
  ])
}

// -- Tests --------------------------------------------------------------------

pub fn getting_started_counter_init_test() {
  let #(model, cmd) = init()
  assert model.count == 0
  assert cmd == command.none()
}

pub fn getting_started_counter_increment_test() {
  let #(model, _) = init()
  let #(model, _) =
    update(model, WidgetClick(window_id: "main", id: "increment", scope: []))
  assert model.count == 1
}

pub fn getting_started_counter_decrement_test() {
  let #(model, _) = init()
  let #(model, _) =
    update(model, WidgetClick(window_id: "main", id: "decrement", scope: []))
  assert model.count == -1
}

pub fn getting_started_counter_unknown_event_test() {
  let #(model, _) = init()
  let #(model, cmd) =
    update(model, WidgetClick(window_id: "main", id: "unknown", scope: []))
  assert model.count == 0
  assert cmd == command.none()
}

pub fn getting_started_counter_view_test() {
  let #(model, _) = init()
  let tree = view(model)
  assert tree.kind == "window"
  assert tree.id == "main"
  assert dict.get(tree.props, "title") == Ok(StringVal("Counter"))

  let assert [column] = tree.children
  assert column.kind == "column"
  assert column.id == "content"
  assert dict.get(column.props, "spacing") == Ok(IntVal(8))

  let assert [text_node, row_node] = column.children
  assert text_node.kind == "text"
  assert dict.get(text_node.props, "content") == Ok(StringVal("Count: 0"))
  assert dict.get(text_node.props, "size") == Ok(FloatVal(20.0))

  assert row_node.kind == "row"
  let assert [inc, dec] = row_node.children
  assert inc.id == "increment"
  assert dict.get(inc.props, "label") == Ok(StringVal("+"))
  assert dec.id == "decrement"
  assert dict.get(dec.props, "label") == Ok(StringVal("-"))
}

pub fn getting_started_counter_view_after_increments_test() {
  let #(model, _) = init()
  let #(model, _) =
    update(model, WidgetClick(window_id: "main", id: "increment", scope: []))
  let #(model, _) =
    update(model, WidgetClick(window_id: "main", id: "increment", scope: []))
  let tree = view(model)
  let assert [column] = tree.children
  let assert [text_node, _] = column.children
  assert dict.get(text_node.props, "content") == Ok(StringVal("Count: 2"))
}
