//// Selection state management for list and table widgets.
////
//// Supports single, multi, and range selection modes.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}

/// Selection mode.
pub type SelectionMode {
  Single
  Multi
  Range
}

/// Selection state tracking selected items.
pub opaque type Selection {
  Selection(
    mode: SelectionMode,
    selected: Set(String),
    anchor: Option(String),
    order: List(String),
  )
}

/// Create a new empty selection.
pub fn new(mode: SelectionMode) -> Selection {
  Selection(mode:, selected: set.new(), anchor: None, order: [])
}

/// Create with a known item order (for range selection).
pub fn new_with_order(mode: SelectionMode, order: List(String)) -> Selection {
  Selection(mode:, selected: set.new(), anchor: None, order:)
}

/// Select an item. In Single mode, replaces previous. In Multi mode
/// with extend=True, adds to selection.
pub fn select(sel: Selection, id: String, extend: Bool) -> Selection {
  case sel.mode {
    Single -> Selection(..sel, selected: set.from_list([id]), anchor: Some(id))
    Multi ->
      case extend {
        True ->
          Selection(
            ..sel,
            selected: set.insert(sel.selected, id),
            anchor: Some(id),
          )
        False ->
          Selection(..sel, selected: set.from_list([id]), anchor: Some(id))
      }
    Range -> Selection(..sel, selected: set.from_list([id]), anchor: Some(id))
  }
}

/// Toggle an item's selection state. In Single mode, toggling off
/// also clears the anchor (consistent with clearing selection).
pub fn toggle(sel: Selection, id: String) -> Selection {
  case set.contains(sel.selected, id) {
    True -> {
      let new_selected = set.delete(sel.selected, id)
      let new_anchor = case sel.mode {
        Single -> None
        _ -> sel.anchor
      }
      Selection(..sel, selected: new_selected, anchor: new_anchor)
    }
    False ->
      Selection(..sel, selected: set.insert(sel.selected, id), anchor: Some(id))
  }
}

/// Deselect an item.
pub fn deselect(sel: Selection, id: String) -> Selection {
  Selection(..sel, selected: set.delete(sel.selected, id))
}

/// Clear all selections.
pub fn clear(sel: Selection) -> Selection {
  Selection(..sel, selected: set.new(), anchor: None)
}

/// Select a range from the anchor to the given item (Range mode).
/// Uses the order list to determine which items fall in the range.
pub fn range_select(sel: Selection, id: String) -> Selection {
  case sel.anchor {
    None -> select(sel, id, False)
    Some(anchor) -> {
      let range_items = items_between(sel.order, anchor, id)
      Selection(..sel, selected: set.from_list(range_items))
    }
  }
}

/// Get the set of selected IDs.
pub fn selected(sel: Selection) -> Set(String) {
  sel.selected
}

/// Check if an item is selected.
pub fn is_selected(sel: Selection, id: String) -> Bool {
  set.contains(sel.selected, id)
}

/// Get the selection mode.
pub fn mode(sel: Selection) -> SelectionMode {
  sel.mode
}

fn items_between(order: List(String), from: String, to: String) -> List(String) {
  let indexed = list.index_map(order, fn(item, idx) { #(item, idx) })
  let from_idx = list.find(indexed, fn(pair) { pair.0 == from })
  let to_idx = list.find(indexed, fn(pair) { pair.0 == to })
  case from_idx, to_idx {
    Ok(#(_, fi)), Ok(#(_, ti)) -> {
      let #(low, high) = case fi <= ti {
        True -> #(fi, ti)
        False -> #(ti, fi)
      }
      indexed
      |> list.filter(fn(pair) { pair.1 >= low && pair.1 <= high })
      |> list.map(fn(pair) { pair.0 })
    }
    _, _ -> [to]
  }
}
