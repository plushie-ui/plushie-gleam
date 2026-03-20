import gleeunit/should
import toddy/undo.{type UndoCommand, UndoCommand}

fn increment_cmd() -> UndoCommand(Int) {
  UndoCommand(apply: fn(n) { n + 1 }, undo: fn(n) { n - 1 }, label: "increment")
}

fn add_cmd(amount: Int) -> UndoCommand(Int) {
  UndoCommand(
    apply: fn(n) { n + amount },
    undo: fn(n) { n - amount },
    label: "add " <> int.to_string(amount),
  )
}

pub fn new_creates_stack_with_initial_model_test() {
  let stack = undo.new(0)
  should.equal(undo.current(stack), 0)
  should.equal(undo.can_undo(stack), False)
  should.equal(undo.can_redo(stack), False)
}

pub fn apply_executes_command_test() {
  let stack =
    undo.new(0)
    |> undo.apply(increment_cmd())
  should.equal(undo.current(stack), 1)
  should.equal(undo.can_undo(stack), True)
}

pub fn undo_reverses_last_command_test() {
  let stack =
    undo.new(0)
    |> undo.apply(increment_cmd())
    |> undo.undo()
  should.equal(undo.current(stack), 0)
  should.equal(undo.can_undo(stack), False)
  should.equal(undo.can_redo(stack), True)
}

pub fn redo_reapplies_undone_command_test() {
  let stack =
    undo.new(0)
    |> undo.apply(increment_cmd())
    |> undo.undo()
    |> undo.redo()
  should.equal(undo.current(stack), 1)
  should.equal(undo.can_undo(stack), True)
  should.equal(undo.can_redo(stack), False)
}

pub fn apply_clears_redo_stack_test() {
  let stack =
    undo.new(0)
    |> undo.apply(increment_cmd())
    |> undo.undo()
    |> undo.apply(add_cmd(10))
  should.equal(undo.current(stack), 10)
  should.equal(undo.can_redo(stack), False)
}

pub fn undo_empty_is_noop_test() {
  let stack = undo.new(42)
  let undone = undo.undo(stack)
  should.equal(undo.current(undone), 42)
}

pub fn redo_empty_is_noop_test() {
  let stack = undo.new(42)
  let redone = undo.redo(stack)
  should.equal(undo.current(redone), 42)
}

pub fn multiple_undo_redo_test() {
  let stack =
    undo.new(0)
    |> undo.apply(increment_cmd())
    |> undo.apply(increment_cmd())
    |> undo.apply(increment_cmd())
  should.equal(undo.current(stack), 3)
  let stack = undo.undo(stack)
  should.equal(undo.current(stack), 2)
  let stack = undo.undo(stack)
  should.equal(undo.current(stack), 1)
  let stack = undo.redo(stack)
  should.equal(undo.current(stack), 2)
}

pub fn undo_history_labels_test() {
  let stack =
    undo.new(0)
    |> undo.apply(increment_cmd())
    |> undo.apply(add_cmd(5))
  should.equal(undo.undo_history(stack), ["add 5", "increment"])
}

pub fn redo_history_labels_test() {
  let stack =
    undo.new(0)
    |> undo.apply(increment_cmd())
    |> undo.apply(add_cmd(5))
    |> undo.undo()
    |> undo.undo()
  should.equal(undo.redo_history(stack), ["increment", "add 5"])
}

import gleam/int
