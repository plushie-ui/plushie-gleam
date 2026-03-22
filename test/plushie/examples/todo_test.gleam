//// Integration tests for the Todo example.

import gleam/option
import gleeunit/should
import plushie/node.{StringVal}
import plushie/testing
import plushie/testing/element

import examples/todo_app

pub fn starts_with_empty_todo_list_test() {
  let session = testing.start(todo_app.app())
  // The list column should exist but have no children
  let assert option.Some(_) = testing.find(session, "list")
  should.be_true(option.is_none(testing.find(session, "todo_1")))
}

pub fn input_field_exists_test() {
  let session = testing.start(todo_app.app())
  should.be_true(option.is_some(testing.find(session, "new_todo")))
}

pub fn filter_buttons_exist_test() {
  let session = testing.start(todo_app.app())
  should.be_true(option.is_some(testing.find(session, "filter_all")))
  should.be_true(option.is_some(testing.find(session, "filter_active")))
  should.be_true(option.is_some(testing.find(session, "filter_done")))
}

pub fn submitting_adds_a_todo_test() {
  let session = testing.start(todo_app.app())
  let session = testing.type_text(session, "new_todo", "Buy milk")
  let session = testing.submit(session, "new_todo")
  // New todo should appear (id: "todo_1" as container)
  should.be_true(option.is_some(testing.find(session, "todo_1")))
}

pub fn submitting_clears_input_test() {
  let session = testing.start(todo_app.app())
  let session = testing.type_text(session, "new_todo", "Buy milk")
  let session = testing.submit(session, "new_todo")
  let assert option.Some(el) = testing.find(session, "new_todo")
  should.equal(element.prop(el, "value"), option.Some(StringVal("")))
}

pub fn empty_input_does_not_add_todo_test() {
  let session = testing.start(todo_app.app())
  let session = testing.submit(session, "new_todo")
  should.be_true(option.is_none(testing.find(session, "todo_1")))
}
