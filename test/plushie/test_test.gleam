import gleam/int
import gleam/option
import gleeunit/should
import plushie/app
import plushie/command
import plushie/event.{
  type Event, WidgetClick, WidgetInput, WidgetSubmit, WidgetToggle,
}
import plushie/node.{type Node, StringVal}
import plushie/prop/padding
import plushie/testing
import plushie/testing/element
import plushie/ui

// -- Counter app for testing --------------------------------------------------

type CounterModel {
  CounterModel(count: Int)
}

fn counter_init() {
  #(CounterModel(count: 0), command.none())
}

fn counter_update(model: CounterModel, event: Event) {
  case event {
    WidgetClick(id: "inc", ..) -> #(
      CounterModel(count: model.count + 1),
      command.none(),
    )
    WidgetClick(id: "dec", ..) -> #(
      CounterModel(count: model.count - 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn counter_view(model: CounterModel) -> Node {
  ui.column("root", [ui.padding(padding.all(16.0))], [
    ui.text_("label", "Count: " <> int.to_string(model.count)),
    ui.button_("inc", "+"),
    ui.button_("dec", "-"),
  ])
}

fn counter_app() {
  app.simple(counter_init, counter_update, counter_view)
}

// -- Session lifecycle --------------------------------------------------------

pub fn start_creates_initial_state_test() {
  let session = testing.start(counter_app())
  let model = testing.model(session)
  should.equal(model.count, 0)
}

pub fn initial_tree_is_normalized_test() {
  let session = testing.start(counter_app())
  let tree = testing.tree(session)
  should.equal(tree.id, "root")

  let assert [label, inc, dec] = tree.children
  // Children get scoped IDs
  should.equal(label.id, "root/label")
  should.equal(inc.id, "root/inc")
  should.equal(dec.id, "root/dec")
}

// -- Click interaction --------------------------------------------------------

pub fn click_increments_counter_test() {
  let session = testing.start(counter_app())
  let session = testing.click(session, "inc")
  should.equal(testing.model(session).count, 1)
}

pub fn click_decrements_counter_test() {
  let session = testing.start(counter_app())
  let session = testing.click(session, "dec")
  should.equal(testing.model(session).count, -1)
}

pub fn multiple_clicks_accumulate_test() {
  let session = testing.start(counter_app())
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  should.equal(testing.model(session).count, 3)
}

pub fn tree_updates_after_click_test() {
  let session = testing.start(counter_app())
  let session = testing.click(session, "inc")
  let tree = testing.tree(session)
  let assert [label, ..] = tree.children
  let assert Ok(StringVal(content)) =
    node.Node(..label, props: label.props).props
    |> gleam_dict_get("content")
  should.equal(content, "Count: 1")
}

// -- Element queries ----------------------------------------------------------

pub fn find_element_by_id_test() {
  let session = testing.start(counter_app())
  let result = testing.find(session, "label")
  should.be_true(option.is_some(result))
  let assert option.Some(el) = result
  should.equal(element.kind(el), "text")
}

pub fn find_element_not_found_test() {
  let session = testing.start(counter_app())
  let result = testing.find(session, "nonexistent")
  should.be_true(option.is_none(result))
}

pub fn element_text_extraction_test() {
  let session = testing.start(counter_app())
  let assert option.Some(el) = testing.find(session, "label")
  let text = element.text(el)
  should.equal(text, option.Some("Count: 0"))
}

pub fn element_text_after_update_test() {
  let session = testing.start(counter_app())
  let session = testing.click(session, "inc")
  let session = testing.click(session, "inc")
  let assert option.Some(el) = testing.find(session, "label")
  should.equal(element.text(el), option.Some("Count: 2"))
}

pub fn element_children_test() {
  let session = testing.start(counter_app())
  let assert option.Some(root) = testing.find(session, "root")
  let kids = element.children(root)
  should.equal(gleam_list_length(kids), 3)
}

pub fn element_prop_test() {
  let session = testing.start(counter_app())
  let assert option.Some(el) = testing.find(session, "inc")
  let label = element.prop(el, "label")
  should.equal(label, option.Some(StringVal("+")))
}

// -- Send raw event -----------------------------------------------------------

pub fn send_raw_event_test() {
  let session = testing.start(counter_app())
  let session =
    testing.send_event(session, WidgetClick(id: "inc", scope: ["root"]))
  should.equal(testing.model(session).count, 1)
}

// -- State immutability -------------------------------------------------------

pub fn sessions_are_immutable_test() {
  let s0 = testing.start(counter_app())
  let s1 = testing.click(s0, "inc")
  // Original session is unchanged
  should.equal(testing.model(s0).count, 0)
  should.equal(testing.model(s1).count, 1)
}

// -- Todo app (tests text input, toggle, submit) ------------------------------

type TodoModel {
  TodoModel(input: String, items: List(TodoItem))
}

type TodoItem {
  TodoItem(text: String, done: Bool)
}

fn todo_init() {
  #(TodoModel(input: "", items: []), command.none())
}

fn todo_update(model: TodoModel, event: Event) {
  case event {
    WidgetInput(id: "input", value:, ..) -> #(
      TodoModel(..model, input: value),
      command.none(),
    )
    WidgetSubmit(id: "input", ..) -> {
      case model.input {
        "" -> #(model, command.none())
        text -> #(
          TodoModel(
            input: "",
            items: list_append(model.items, [TodoItem(text:, done: False)]),
          ),
          command.none(),
        )
      }
    }
    WidgetToggle(id: "toggle-0", value:, ..) -> {
      let items = case model.items {
        [first, ..rest] -> [TodoItem(..first, done: value), ..rest]
        other -> other
      }
      #(TodoModel(..model, items:), command.none())
    }
    _ -> #(model, command.none())
  }
}

fn todo_view(model: TodoModel) -> Node {
  let item_nodes =
    list_index_map(model.items, fn(item, idx) {
      let id_str = "toggle-" <> int.to_string(idx)
      ui.checkbox(id_str, item.text, item.done, [])
    })

  ui.column("root", [], [ui.text_input("input", model.input, []), ..item_nodes])
}

fn todo_app() {
  app.simple(todo_init, todo_update, todo_view)
}

pub fn type_text_updates_input_test() {
  let session = testing.start(todo_app())
  let session = testing.type_text(session, "input", "Buy milk")
  should.equal(testing.model(session).input, "Buy milk")
}

pub fn submit_adds_todo_item_test() {
  let session = testing.start(todo_app())
  let session = testing.type_text(session, "input", "Buy milk")
  let session = testing.submit(session, "input")
  let model = testing.model(session)
  should.equal(model.input, "")
  should.equal(gleam_list_length(model.items), 1)
  let assert [item] = model.items
  should.equal(item.text, "Buy milk")
  should.equal(item.done, False)
}

pub fn toggle_toggles_item_test() {
  let session = testing.start(todo_app())
  let session = testing.type_text(session, "input", "Buy milk")
  let session = testing.submit(session, "input")
  let session = testing.toggle(session, "toggle-0")
  let assert [item] = testing.model(session).items
  should.be_true(item.done)
}

pub fn toggle_back_untoggles_test() {
  let session = testing.start(todo_app())
  let session = testing.type_text(session, "input", "Buy milk")
  let session = testing.submit(session, "input")
  let session = testing.toggle(session, "toggle-0")
  let session = testing.toggle(session, "toggle-0")
  let assert [item] = testing.model(session).items
  should.be_false(item.done)
}

// -- Command processing -------------------------------------------------------

type CmdModel {
  CmdModel(value: String)
}

fn cmd_init() {
  #(
    CmdModel(value: "init"),
    command.done(dynamic.string("from_init"), fn(_d) {
      WidgetClick(id: "from_init", scope: [])
    }),
  )
}

fn cmd_update(model: CmdModel, event: Event) {
  case event {
    WidgetClick(id: value, ..) -> #(CmdModel(value:), command.none())
    _ -> #(model, command.none())
  }
}

fn cmd_view(model: CmdModel) -> Node {
  ui.text_("label", model.value)
}

fn cmd_app() {
  app.simple(cmd_init, cmd_update, cmd_view)
}

pub fn init_commands_are_processed_test() {
  let session = testing.start(cmd_app())
  should.equal(testing.model(session).value, "from_init")
}

// -- Helpers to avoid import issues -------------------------------------------

import gleam/dict as gleam_dict
import gleam/dynamic
import gleam/list

fn gleam_dict_get(d, k) {
  gleam_dict.get(d, k)
}

fn gleam_list_length(l) {
  list.length(l)
}

fn list_append(a, b) {
  list.append(a, b)
}

fn list_index_map(l, f) {
  list.index_map(l, f)
}
