//// Undo/redo support for reversible operations.
////
//// Each command has an `apply` function (model -> model) and an `undo`
//// function (model -> model). Push a command to execute it and add it to
//// the undo stack; undo/redo move commands between stacks while updating
//// the model.
////
//// The undo stack is bounded by `max_size` (default 100). When a push
//// exceeds the limit, the oldest entries are dropped. The redo stack
//// is unbounded (it can only shrink or be cleared, never grow past
//// the undo stack size).
////
//// Commands with the same `coalesce_key` that arrive within
//// `coalesce_window_ms` of each other are merged into a single undo
//// entry. The merged entry keeps the original undo function (so one undo
//// reverses all coalesced changes) and composes the apply functions.

import gleam/int
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

const default_max_size = 100

/// Undo/redo state wrapping a model.
pub opaque type UndoStack(model) {
  UndoStack(
    current: model,
    undo_stack: List(UndoEntry(model)),
    redo_stack: List(UndoEntry(model)),
    max_size: Int,
    undo_size: Int,
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

/// Create a new undo stack with initial model. The undo stack is
/// bounded by `max_size` (default 100). When exceeded, the oldest
/// entries are dropped silently.
pub fn new(model: model) -> UndoStack(model) {
  UndoStack(
    current: model,
    undo_stack: [],
    redo_stack: [],
    max_size: default_max_size,
    undo_size: 0,
  )
}

/// Create a new undo stack with a custom maximum size.
/// The max_size must be a positive integer.
pub fn new_with_max_size(model: model, max_size: Int) -> UndoStack(model) {
  case max_size > 0 {
    True ->
      UndoStack(
        current: model,
        undo_stack: [],
        redo_stack: [],
        max_size:,
        undo_size: 0,
      )
    False ->
      panic as {
        "undo max_size must be a positive integer, got "
        <> int.to_string(max_size)
      }
  }
}

/// Push a command: execute it, push to undo stack, clear redo stack.
///
/// If the command carries a `coalesce_key` that matches the top of the
/// undo stack and the time delta is within `coalesce_window_ms`, the
/// entry is merged rather than pushed.
///
/// When the undo stack exceeds `max_size`, the oldest entries are dropped.
pub fn push(
  stack: UndoStack(model),
  cmd: UndoCommand(model),
) -> UndoStack(model) {
  let now = timestamp()
  let new_model = cmd.apply(stack.current)

  case maybe_coalesce(stack, cmd, now) {
    Some(merged_entry) ->
      // Coalesced: replace top entry, size unchanged
      UndoStack(
        ..stack,
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
      let new_stack = [entry, ..stack.undo_stack]
      let new_size = stack.undo_size + 1
      // Enforce max_size by dropping oldest entries
      let #(trimmed_stack, trimmed_size) = case new_size > stack.max_size {
        True -> #(list.take(new_stack, stack.max_size), stack.max_size)
        False -> #(new_stack, new_size)
      }
      UndoStack(
        ..stack,
        current: new_model,
        undo_stack: trimmed_stack,
        redo_stack: [],
        undo_size: trimmed_size,
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
      UndoStack(
        ..stack,
        current: old_model,
        undo_stack: rest,
        redo_stack: [entry, ..stack.redo_stack],
        undo_size: stack.undo_size - 1,
      )
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
        ..stack,
        current: new_model,
        undo_stack: [entry, ..stack.undo_stack],
        redo_stack: rest,
        undo_size: stack.undo_size + 1,
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
