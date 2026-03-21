import gleam/option.{None, Some}
import gleeunit/should
import plushie/undo.{type UndoCommand, UndoCommand}

fn increment_cmd() -> UndoCommand(Int) {
  UndoCommand(
    apply: fn(n) { n + 1 },
    undo: fn(n) { n - 1 },
    label: "increment",
    coalesce_key: None,
    coalesce_window_ms: None,
  )
}

fn add_cmd(amount: Int) -> UndoCommand(Int) {
  UndoCommand(
    apply: fn(n) { n + amount },
    undo: fn(n) { n - amount },
    label: "add",
    coalesce_key: None,
    coalesce_window_ms: None,
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
  should.equal(undo.undo_history(stack), ["add", "increment"])
}

pub fn redo_history_labels_test() {
  let stack =
    undo.new(0)
    |> undo.apply(increment_cmd())
    |> undo.apply(add_cmd(5))
    |> undo.undo()
    |> undo.undo()
  should.equal(undo.redo_history(stack), ["increment", "add"])
}

// -- Coalescing tests --------------------------------------------------------

pub fn coalesce_merges_within_window_test() {
  // Two commands with the same coalesce key within the window merge
  let cmd1 =
    UndoCommand(
      apply: fn(n) { n + 1 },
      undo: fn(n) { n - 1 },
      label: "type",
      coalesce_key: Some("typing"),
      coalesce_window_ms: Some(5000),
    )
  let cmd2 =
    UndoCommand(
      apply: fn(n) { n + 10 },
      undo: fn(n) { n - 10 },
      label: "type",
      coalesce_key: Some("typing"),
      coalesce_window_ms: Some(5000),
    )
  let stack =
    undo.new(0)
    |> undo.apply(cmd1)
    |> undo.apply(cmd2)
  // Should have been merged: 0 + 1 + 10 = 11
  should.equal(undo.current(stack), 11)
  // Only one entry on the undo stack (merged)
  should.equal(undo.undo_history(stack), ["type"])
  // Undo should reverse both: 11 -> undo cmd2 (11-10=1) -> undo cmd1 (1-1=0)
  let stack = undo.undo(stack)
  should.equal(undo.current(stack), 0)
}

pub fn coalesce_different_keys_no_merge_test() {
  let cmd1 =
    UndoCommand(
      apply: fn(n) { n + 1 },
      undo: fn(n) { n - 1 },
      label: "a",
      coalesce_key: Some("key-a"),
      coalesce_window_ms: Some(5000),
    )
  let cmd2 =
    UndoCommand(
      apply: fn(n) { n + 10 },
      undo: fn(n) { n - 10 },
      label: "b",
      coalesce_key: Some("key-b"),
      coalesce_window_ms: Some(5000),
    )
  let stack =
    undo.new(0)
    |> undo.apply(cmd1)
    |> undo.apply(cmd2)
  // Different keys: no merge, two entries
  should.equal(undo.undo_history(stack), ["b", "a"])
}

pub fn coalesce_none_key_no_merge_test() {
  // Commands without coalesce_key should never merge
  let stack =
    undo.new(0)
    |> undo.apply(increment_cmd())
    |> undo.apply(increment_cmd())
  should.equal(undo.current(stack), 2)
  // Two separate entries
  should.equal(undo.undo_history(stack), ["increment", "increment"])
}
