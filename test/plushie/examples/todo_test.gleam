//// Integration tests for the Todo example.

import gleam/option
import gleeunit/should
import plushie/node.{StringVal}
import plushie/testing
import plushie/testing/element

import examples/todo_app

pub fn starts_with_empty_todo_list_test() {
  let ctx = testing.start(todo_app.app())
  // The list column should exist but have no children
  let assert option.Some(_) = testing.find(ctx, "list")
  should.be_true(option.is_none(testing.find(ctx, "todo_1")))
}

pub fn input_field_exists_test() {
  let ctx = testing.start(todo_app.app())
  should.be_true(option.is_some(testing.find(ctx, "new_todo")))
}

pub fn filter_buttons_exist_test() {
  let ctx = testing.start(todo_app.app())
  should.be_true(option.is_some(testing.find(ctx, "filter_all")))
  should.be_true(option.is_some(testing.find(ctx, "filter_active")))
  should.be_true(option.is_some(testing.find(ctx, "filter_done")))
}

pub fn submitting_adds_a_todo_test() {
  let ctx = testing.start(todo_app.app())
  let ctx = testing.type_text(ctx, "new_todo", "Buy milk")
  let ctx = testing.submit(ctx, "new_todo")
  // New todo should appear (id: "todo_1" as container)
  should.be_true(option.is_some(testing.find(ctx, "todo_1")))
}

pub fn submitting_clears_input_test() {
  let ctx = testing.start(todo_app.app())
  let ctx = testing.type_text(ctx, "new_todo", "Buy milk")
  let ctx = testing.submit(ctx, "new_todo")
  let assert option.Some(el) = testing.find(ctx, "new_todo")
  should.equal(element.prop(el, "value"), option.Some(StringVal("")))
}

pub fn empty_input_does_not_add_todo_test() {
  let ctx = testing.start(todo_app.app())
  let ctx = testing.submit(ctx, "new_todo")
  should.be_true(option.is_none(testing.find(ctx, "todo_1")))
}
