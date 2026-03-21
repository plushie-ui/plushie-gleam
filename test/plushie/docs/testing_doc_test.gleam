import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleeunit/should
import plushie/app
import plushie/command
import plushie/event.{type Event, WidgetClick, WidgetInput, WidgetSubmit}
import plushie/node.{type Node, StringVal}
import plushie/testing as t
import plushie/testing/element
import plushie/tree
import plushie/ui

// ============================================================================
// A simple counter app used for testing the framework examples
// ============================================================================

type CounterModel {
  CounterModel(count: Int)
}

fn counter_init() {
  #(CounterModel(count: 0), command.none())
}

fn counter_update(model: CounterModel, event: Event) {
  case event {
    WidgetClick(id: "increment", ..) -> #(
      CounterModel(count: model.count + 1),
      command.none(),
    )
    WidgetClick(id: "decrement", ..) -> #(
      CounterModel(count: model.count - 1),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn counter_view(model: CounterModel) -> Node {
  ui.window("main", [ui.title("Counter")], [
    ui.column("content", [ui.spacing(8)], [
      ui.text("count", int.to_string(model.count), []),
      ui.button_("increment", "+"),
      ui.button_("decrement", "-"),
    ]),
  ])
}

fn counter_app() {
  app.simple(counter_init, counter_update, counter_view)
}

// ============================================================================
// A simple todo app for more complex testing
// ============================================================================

type Todo {
  Todo(text: String, done: Bool)
}

type TodoModel {
  TodoModel(todos: List(Todo), input: String)
}

fn todo_init() {
  #(TodoModel(todos: [], input: ""), command.none())
}

fn todo_update(model: TodoModel, event: Event) {
  case event {
    WidgetInput(id: "todo_input", value: val, ..) -> #(
      TodoModel(..model, input: val),
      command.none(),
    )
    WidgetSubmit(id: "todo_input", value: val, ..) -> #(
      TodoModel(
        todos: list.append(model.todos, [Todo(text: val, done: False)]),
        input: "",
      ),
      command.Focus(widget_id: "todo_input"),
    )
    WidgetClick(id: "add_todo", ..) -> #(
      TodoModel(
        todos: list.append(model.todos, [
          Todo(text: model.input, done: False),
        ]),
        input: "",
      ),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn todo_view(model: TodoModel) -> Node {
  ui.window("main", [], [
    ui.column("layout", [ui.spacing(8)], [
      ui.text_input("todo_input", model.input, []),
      ui.button_("add_todo", "Add"),
      ui.text("todo_count", int.to_string(list.length(model.todos)), []),
    ]),
  ])
}

fn todo_app() {
  app.simple(todo_init, todo_update, todo_view)
}

// ============================================================================
// Unit testing: Testing update (from "Testing update" section)
// ============================================================================

pub fn testing_doc_adding_a_todo_appends_and_clears_input_test() {
  let model = TodoModel(todos: [], input: "Buy milk")
  let #(model, _cmd) =
    todo_update(model, WidgetClick(id: "add_todo", scope: []))
  should.equal(model.todos, [Todo(text: "Buy milk", done: False)])
  should.equal(model.input, "")
}

// ============================================================================
// Testing commands from update (from "Testing commands" section)
// ============================================================================

pub fn testing_doc_submitting_todo_returns_focus_command_test() {
  let model = TodoModel(todos: [], input: "Buy milk")
  let #(model, cmd) =
    todo_update(
      model,
      WidgetSubmit(id: "todo_input", scope: [], value: "Buy milk"),
    )
  should.equal(list.length(model.todos), 1)
  let assert command.Focus(widget_id: "todo_input") = cmd
}

// ============================================================================
// Testing view (from "Testing view" section)
// ============================================================================

pub fn testing_doc_view_shows_todo_count_test() {
  let model = TodoModel(todos: [Todo(text: "Buy milk", done: False)], input: "")
  let view_tree = todo_view(model)
  let assert option.Some(counter) = tree.find(view_tree, "todo_count")
  let assert Ok(StringVal(content)) = dict.get(counter.props, "content")
  should.equal(content, "1")
}

// ============================================================================
// Testing init (from "Testing init" section)
// ============================================================================

pub fn testing_doc_init_returns_valid_initial_state_test() {
  let #(model, _cmd) = todo_init()
  should.be_true(list.is_empty(model.todos))
  should.equal(model.input, "")
}

// ============================================================================
// Tree query helpers (from "Tree query helpers" section)
// ============================================================================

pub fn testing_doc_tree_find_test() {
  let view_tree = counter_view(CounterModel(count: 0))
  should.be_true(option.is_some(tree.find(view_tree, "increment")))
  should.be_true(tree.exists(view_tree, "increment"))
  should.be_true(tree.exists(view_tree, "count"))
}

pub fn testing_doc_tree_ids_test() {
  let view_tree = counter_view(CounterModel(count: 0))
  let all_ids = tree.ids(view_tree)
  should.be_true(list.contains(all_ids, "increment"))
  should.be_true(list.contains(all_ids, "decrement"))
  should.be_true(list.contains(all_ids, "count"))
}

pub fn testing_doc_tree_find_all_test() {
  let view_tree = counter_view(CounterModel(count: 0))
  let buttons = tree.find_all(view_tree, fn(node) { node.kind == "button" })
  should.equal(list.length(buttons), 2)
}

// ============================================================================
// Test framework: start, click, find, element (from "The test framework")
// ============================================================================

// Note: the test framework normalizes the tree, so IDs are scoped.
// counter_app: window("main") -> column("content") -> children
// Scoped IDs: "content/increment", "content/decrement", "content/count"
// todo_app: window("main") -> column("layout") -> children
// Scoped IDs: "layout/todo_input", "layout/add_todo", "layout/todo_count"

pub fn testing_doc_clicking_increment_updates_counter_test() {
  let session = t.start(counter_app())
  let session = t.click(session, "content/increment")

  let assert option.Some(el) = t.find(session, "content/count")
  let assert option.Some(text) = element.text(el)
  should.equal(text, "1")
}

// ============================================================================
// Element handles (from "Element handles" section)
// ============================================================================

pub fn testing_doc_element_id_and_kind_test() {
  let session = t.start(counter_app())
  let assert option.Some(el) = t.find(session, "content/increment")
  should.equal(element.id(el), "content/increment")
  should.equal(element.kind(el), "button")
}

pub fn testing_doc_element_text_test() {
  let session = t.start(counter_app())
  let assert option.Some(el) = t.find(session, "content/count")
  let assert option.Some(txt) = element.text(el)
  should.equal(txt, "0")
}

pub fn testing_doc_element_children_test() {
  let session = t.start(counter_app())
  let root_tree = t.tree(session)
  let el = element.from_node(root_tree)
  let kids = element.children(el)
  should.be_true(kids != [])
}

// ============================================================================
// Assertions (from "Assertions" section)
// ============================================================================

pub fn testing_doc_text_content_assertion_test() {
  let session = t.start(counter_app())
  let session = t.click(session, "content/increment")
  let session = t.click(session, "content/increment")

  let assert option.Some(el) = t.find(session, "content/count")
  let assert option.Some(txt) = element.text(el)
  should.equal(txt, "2")
}

pub fn testing_doc_existence_assertion_test() {
  let session = t.start(counter_app())
  should.be_true(option.is_some(t.find(session, "content/increment")))
  should.be_true(option.is_none(t.find(session, "admin-panel")))
}

pub fn testing_doc_model_assertion_test() {
  let session = t.start(counter_app())
  let session = t.click(session, "content/increment")
  should.equal(t.model(session).count, 1)
}

pub fn testing_doc_element_kind_assertion_test() {
  let session = t.start(counter_app())
  let assert option.Some(el) = t.find(session, "content/count")
  should.equal(element.kind(el), "text")
}

// ============================================================================
// Interaction functions (from "Interaction functions" section)
// ============================================================================

pub fn testing_doc_type_text_and_submit_test() {
  let session = t.start(todo_app())
  let session = t.type_text(session, "layout/todo_input", "Buy milk")
  should.equal(t.model(session).input, "Buy milk")

  let session = t.submit(session, "layout/todo_input")
  should.equal(list.length(t.model(session).todos), 1)
  should.equal(t.model(session).input, "")
}

pub fn testing_doc_click_interaction_test() {
  let session = t.start(counter_app())
  let session = t.click(session, "content/increment")
  let session = t.click(session, "content/increment")
  let session = t.click(session, "content/decrement")
  should.equal(t.model(session).count, 1)
}

// ============================================================================
// Element not found (from "Debugging and error messages" section)
// ============================================================================

pub fn testing_doc_find_nonexistent_returns_none_test() {
  let session = t.start(counter_app())
  should.be_true(option.is_none(t.find(session, "nonexistent")))
}

// ============================================================================
// Full model equality
// ============================================================================

pub fn testing_doc_full_model_equality_test() {
  let session = t.start(counter_app())
  let session = t.click(session, "content/increment")
  let session = t.click(session, "content/increment")
  let session = t.click(session, "content/increment")
  should.equal(t.model(session), CounterModel(count: 3))
}
