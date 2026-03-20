//// Undo/redo support for reversible operations.
////
//// Each command has an `apply` function (model -> model) and an `undo`
//// function (model -> model). Apply a command to push it onto the undo
//// stack; undo/redo move commands between stacks while updating the model.

import gleam/list

/// A reversible command.
pub type UndoCommand(model) {
  UndoCommand(
    apply: fn(model) -> model,
    undo: fn(model) -> model,
    label: String,
  )
}

/// Undo/redo state wrapping a model.
pub opaque type UndoStack(model) {
  UndoStack(
    current: model,
    undo_stack: List(UndoEntry(model)),
    redo_stack: List(UndoEntry(model)),
  )
}

type UndoEntry(model) {
  UndoEntry(
    undo_fn: fn(model) -> model,
    redo_fn: fn(model) -> model,
    label: String,
  )
}

/// Create a new undo stack with initial model.
pub fn new(model: model) -> UndoStack(model) {
  UndoStack(current: model, undo_stack: [], redo_stack: [])
}

/// Apply a command: execute it, push to undo stack, clear redo stack.
pub fn apply(
  stack: UndoStack(model),
  cmd: UndoCommand(model),
) -> UndoStack(model) {
  let new_model = cmd.apply(stack.current)
  let entry = UndoEntry(undo_fn: cmd.undo, redo_fn: cmd.apply, label: cmd.label)
  UndoStack(
    current: new_model,
    undo_stack: [entry, ..stack.undo_stack],
    redo_stack: [],
  )
}

/// Undo the last command. Returns unchanged if nothing to undo.
pub fn undo(stack: UndoStack(model)) -> UndoStack(model) {
  case stack.undo_stack {
    [] -> stack
    [entry, ..rest] -> {
      let old_model = entry.undo_fn(stack.current)
      UndoStack(current: old_model, undo_stack: rest, redo_stack: [
        entry,
        ..stack.redo_stack
      ])
    }
  }
}

/// Redo the last undone command. Returns unchanged if nothing to redo.
pub fn redo(stack: UndoStack(model)) -> UndoStack(model) {
  case stack.redo_stack {
    [] -> stack
    [entry, ..rest] -> {
      let new_model = entry.redo_fn(stack.current)
      UndoStack(
        current: new_model,
        undo_stack: [entry, ..stack.undo_stack],
        redo_stack: rest,
      )
    }
  }
}

/// Get the current model.
pub fn current(stack: UndoStack(model)) -> model {
  stack.current
}

/// Check if undo is available.
pub fn can_undo(stack: UndoStack(model)) -> Bool {
  !list.is_empty(stack.undo_stack)
}

/// Check if redo is available.
pub fn can_redo(stack: UndoStack(model)) -> Bool {
  !list.is_empty(stack.redo_stack)
}

/// Get undo history labels (most recent first).
pub fn undo_history(stack: UndoStack(model)) -> List(String) {
  list.map(stack.undo_stack, fn(e) { e.label })
}

/// Get redo history labels (most recent first).
pub fn redo_history(stack: UndoStack(model)) -> List(String) {
  list.map(stack.redo_stack, fn(e) { e.label })
}
