//// Undo/redo support for reversible operations.
////
//// Each command has an `apply` function (model -> model) and an `undo`
//// function (model -> model). Apply a command to push it onto the undo
//// stack; undo/redo move commands between stacks while updating the model.
////
//// Commands with the same `coalesce_key` that arrive within
//// `coalesce_window_ms` of each other are merged into a single undo
//// entry. The merged entry keeps the original undo function (so one undo
//// reverses all coalesced changes) and composes the apply functions.

import gleam/list
import gleam/option.{type Option, None, Some}
import plushie/platform

/// A reversible command.
pub type UndoCommand(model) {
  UndoCommand(
    apply: fn(model) -> model,
    undo: fn(model) -> model,
    label: String,
    coalesce_key: Option(String),
    coalesce_window_ms: Option(Int),
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
    apply_fn: fn(model) -> model,
    undo_fn: fn(model) -> model,
    label: String,
    coalesce_key: Option(String),
    timestamp: Int,
  )
}

/// Create a new undo stack with initial model.
pub fn new(model: model) -> UndoStack(model) {
  UndoStack(current: model, undo_stack: [], redo_stack: [])
}

/// Apply a command: execute it, push to undo stack, clear redo stack.
///
/// If the command carries a `coalesce_key` that matches the top of the
/// undo stack and the time delta is within `coalesce_window_ms`, the
/// entry is merged rather than pushed.
pub fn apply(
  stack: UndoStack(model),
  cmd: UndoCommand(model),
) -> UndoStack(model) {
  let now = timestamp()
  let new_model = cmd.apply(stack.current)

  case maybe_coalesce(stack, cmd, now) {
    Some(merged_entry) ->
      UndoStack(
        current: new_model,
        undo_stack: [merged_entry, ..list.drop(stack.undo_stack, 1)],
        redo_stack: [],
      )
    None -> {
      let entry =
        UndoEntry(
          apply_fn: cmd.apply,
          undo_fn: cmd.undo,
          label: cmd.label,
          coalesce_key: cmd.coalesce_key,
          timestamp: now,
        )
      UndoStack(
        current: new_model,
        undo_stack: [entry, ..stack.undo_stack],
        redo_stack: [],
      )
    }
  }
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
      let new_model = entry.apply_fn(stack.current)
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

// -- Private -----------------------------------------------------------------

/// Check if the new command can be coalesced with the top of the undo stack.
/// Returns Some(merged_entry) if coalescing applies, None otherwise.
fn maybe_coalesce(
  stack: UndoStack(model),
  cmd: UndoCommand(model),
  now: Int,
) -> Option(UndoEntry(model)) {
  case stack.undo_stack {
    [] -> None
    [top, ..] -> {
      let window = case cmd.coalesce_window_ms {
        Some(w) -> w
        None -> 0
      }
      case cmd.coalesce_key, top.coalesce_key {
        Some(key), Some(top_key)
          if key == top_key && now - top.timestamp <= window
        -> {
          // Compose apply: old apply then new apply
          let old_apply = top.apply_fn
          let new_apply = cmd.apply
          // Keep the ORIGINAL undo (so one undo reverses all coalesced changes)
          // and compose undo in reverse for correctness
          let old_undo = top.undo_fn
          let new_undo = cmd.undo
          Some(UndoEntry(
            apply_fn: fn(model) { new_apply(old_apply(model)) },
            undo_fn: fn(model) { old_undo(new_undo(model)) },
            label: top.label,
            coalesce_key: Some(key),
            timestamp: now,
          ))
        }
        _, _ -> None
      }
    }
  }
}

fn timestamp() -> Int {
  platform.monotonic_time_ms()
}
