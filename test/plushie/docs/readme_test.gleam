import gleam/dict
import gleam/int
import gleeunit/should
import plushie/command
import plushie/event.{type Event, Click, EventTarget, Widget}
import plushie/node.{type Node, FloatVal, StringVal}
import plushie/prop/padding
import plushie/ui
import plushie/widget/column
import plushie/widget/row
import plushie/widget/window

// -- Types matching the README counter example --------------------------------

type Model {
  Model(count: Int)
}

fn init() {
  #(Model(count: 0), command.none())
}

fn update(model: Model, event: Event) {
  case event {
    Widget(Click(target: EventTarget(id: "inc", ..))) -> #(
      Model(count: model.count + 1),
      command.none(),
    )
    Widget(Click(target: EventTarget(id: "dec", ..))) -> #(
      Model(count: model.count - 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("Counter")], [
      ui.column(
        "content",
        [column.Padding(padding.all(16.0)), column.Spacing(8.0)],
        [
          ui.text_("count", "Count: " <> int.to_string(model.count)),
          ui.row("buttons", [row.Spacing(8.0)], [
            ui.button_("inc", "+"),
            ui.button_("dec", "-"),
          ]),
        ],
      ),
    ]),
  ]
}

// -- Tests --------------------------------------------------------------------

pub fn readme_counter_init_test() {
  let #(model, cmd) = init()
  should.equal(model.count, 0)
  should.equal(cmd, command.None)
}

pub fn readme_counter_increment_test() {
  let #(model, _) = init()
  let #(model, _) =
    update(
      model,
      Widget(
        Click(target: EventTarget(
          window_id: "main",
          id: "inc",
          scope: [],
          full: "inc",
        )),
      ),
    )
  should.equal(model.count, 1)
}

pub fn readme_counter_decrement_test() {
  let #(model, _) = init()
  let #(model, _) =
    update(
      model,
      Widget(
        Click(target: EventTarget(
          window_id: "main",
          id: "dec",
          scope: [],
          full: "dec",
        )),
      ),
    )
  should.equal(model.count, -1)
}

pub fn readme_counter_unknown_event_test() {
  let #(model, _) = init()
  let #(model, cmd) =
    update(
      model,
      Widget(
        Click(target: EventTarget(
          window_id: "main",
          id: "nope",
          scope: [],
          full: "nope",
        )),
      ),
    )
  should.equal(model.count, 0)
  should.equal(cmd, command.None)
}

pub fn readme_counter_view_structure_test() {
  let assert [tree] = view(Model(count: 0))

  should.equal(tree.kind, "window")
  should.equal(tree.id, "main")
  should.equal(dict.get(tree.props, "title"), Ok(StringVal("Counter")))

  let assert [column] = tree.children
  should.equal(column.kind, "column")
  should.equal(dict.get(column.props, "spacing"), Ok(FloatVal(8.0)))

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
  let assert [tree] = view(Model(count: 3))
  let assert [column] = tree.children
  let assert [text_node, _] = column.children
  should.equal(dict.get(text_node.props, "content"), Ok(StringVal("Count: 3")))
}
