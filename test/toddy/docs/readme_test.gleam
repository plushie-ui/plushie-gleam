import gleam/dict
import gleam/int
import gleeunit/should
import toddy/command
import toddy/event.{type Event, WidgetClick}
import toddy/node.{type Node, IntVal, StringVal}
import toddy/prop/padding
import toddy/ui

// -- Types matching the README counter example --------------------------------

type Model {
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
  ui.window("main", [ui.title("Counter")], [
    ui.column("content", [ui.padding(padding.all(16.0)), ui.spacing(8)], [
      ui.text_("count", "Count: " <> int.to_string(model.count)),
      ui.row("buttons", [ui.spacing(8)], [
        ui.button_("inc", "+"),
        ui.button_("dec", "-"),
      ]),
    ]),
  ])
}

// -- Tests --------------------------------------------------------------------

pub fn readme_counter_init_test() {
  let #(model, cmd) = init()
  should.equal(model.count, 0)
  should.equal(cmd, command.None)
}

pub fn readme_counter_increment_test() {
  let #(model, _) = init()
  let #(model, _) = update(model, WidgetClick(id: "inc", scope: []))
  should.equal(model.count, 1)
}

pub fn readme_counter_decrement_test() {
  let #(model, _) = init()
  let #(model, _) = update(model, WidgetClick(id: "dec", scope: []))
  should.equal(model.count, -1)
}

pub fn readme_counter_unknown_event_test() {
  let #(model, _) = init()
  let #(model, cmd) = update(model, WidgetClick(id: "nope", scope: []))
  should.equal(model.count, 0)
  should.equal(cmd, command.None)
}

pub fn readme_counter_view_structure_test() {
  let tree = view(Model(count: 0))

  should.equal(tree.kind, "window")
  should.equal(tree.id, "main")
  should.equal(dict.get(tree.props, "title"), Ok(StringVal("Counter")))

  let assert [column] = tree.children
  should.equal(column.kind, "column")
  should.equal(dict.get(column.props, "spacing"), Ok(IntVal(8)))

  let assert [text_node, row_node] = column.children
  should.equal(text_node.kind, "text")
  should.equal(dict.get(text_node.props, "content"), Ok(StringVal("Count: 0")))

  should.equal(row_node.kind, "row")
  let assert [inc_btn, dec_btn] = row_node.children
  should.equal(inc_btn.id, "inc")
  should.equal(dict.get(inc_btn.props, "label"), Ok(StringVal("+")))
  should.equal(dec_btn.id, "dec")
  should.equal(dict.get(dec_btn.props, "label"), Ok(StringVal("-")))
}

pub fn readme_counter_view_after_increment_test() {
  let tree = view(Model(count: 3))
  let assert [column] = tree.children
  let assert [text_node, _] = column.children
  should.equal(dict.get(text_node.props, "content"), Ok(StringVal("Count: 3")))
}
