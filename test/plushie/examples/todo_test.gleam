//// Integration tests for the Todo example.
////
//// Note: "todo" is a reserved keyword in Gleam, so the example is
//// compiled under the name examples/todo_example for test import.

import gleam/option
import gleeunit/should
import plushie/node.{StringVal}
import plushie/testing
import plushie/testing/element

import examples/todo_example

pub fn starts_with_empty_todo_list_test() {
  let session = testing.start(todo_example.app())
  let assert option.Some(el) = testing.find(session, "count")
  should.equal(element.text(el), option.Some("0 items"))
}

pub fn input_field_exists_test() {
  let session = testing.start(todo_example.app())
  should.be_true(option.is_some(testing.find(session, "new-todo")))
}

pub fn add_button_exists_test() {
  let session = testing.start(todo_example.app())
  should.be_true(option.is_some(testing.find(session, "add")))
}

pub fn submitting_adds_a_todo_test() {
  let session = testing.start(todo_example.app())
  let session = testing.type_text(session, "new-todo", "Buy milk")
  let session = testing.submit(session, "new-todo")
  let assert option.Some(el) = testing.find(session, "count")
  should.equal(element.text(el), option.Some("1 items"))
  let assert option.Some(item) = testing.find(session, "todo-0")
  should.equal(element.text(item), option.Some("1. Buy milk"))
}

pub fn submitting_clears_input_test() {
  let session = testing.start(todo_example.app())
  let session = testing.type_text(session, "new-todo", "Buy milk")
  let session = testing.submit(session, "new-todo")
  let assert option.Some(el) = testing.find(session, "new-todo")
  should.equal(element.prop(el, "value"), option.Some(StringVal("")))
}

pub fn multiple_todos_test() {
  let session = testing.start(todo_example.app())
  let session = testing.type_text(session, "new-todo", "First")
  let session = testing.submit(session, "new-todo")
  let session = testing.type_text(session, "new-todo", "Second")
  let session = testing.submit(session, "new-todo")
  let assert option.Some(el) = testing.find(session, "count")
  should.equal(element.text(el), option.Some("2 items"))
  let assert option.Some(item0) = testing.find(session, "todo-0")
  should.equal(element.text(item0), option.Some("1. First"))
  let assert option.Some(item1) = testing.find(session, "todo-1")
  should.equal(element.text(item1), option.Some("2. Second"))
}

pub fn clear_all_removes_todos_test() {
  let session = testing.start(todo_example.app())
  let session = testing.type_text(session, "new-todo", "First")
  let session = testing.submit(session, "new-todo")
  let session = testing.type_text(session, "new-todo", "Second")
  let session = testing.submit(session, "new-todo")
  let session = testing.click(session, "clear")
  let assert option.Some(el) = testing.find(session, "count")
  should.equal(element.text(el), option.Some("0 items"))
  should.be_true(option.is_none(testing.find(session, "todo-0")))
}

pub fn empty_input_does_not_add_todo_test() {
  let session = testing.start(todo_example.app())
  let session = testing.submit(session, "new-todo")
  let assert option.Some(el) = testing.find(session, "count")
  should.equal(element.text(el), option.Some("0 items"))
}
