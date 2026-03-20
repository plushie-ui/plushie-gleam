import gleam/set
import gleeunit/should
import toddy/selection.{Multi, Range, Single}

pub fn new_creates_empty_selection_test() {
  let sel = selection.new(Single)
  should.equal(set.size(selection.selected(sel)), 0)
  should.equal(selection.mode(sel), Single)
}

pub fn single_select_replaces_previous_test() {
  let sel =
    selection.new(Single)
    |> selection.select("a", False)
    |> selection.select("b", False)
  should.equal(selection.is_selected(sel, "a"), False)
  should.equal(selection.is_selected(sel, "b"), True)
}

pub fn single_select_ignores_extend_test() {
  let sel =
    selection.new(Single)
    |> selection.select("a", False)
    |> selection.select("b", True)
  // Single mode always replaces, extend flag is irrelevant
  should.equal(selection.is_selected(sel, "a"), False)
  should.equal(selection.is_selected(sel, "b"), True)
}

pub fn multi_select_extends_test() {
  let sel =
    selection.new(Multi)
    |> selection.select("a", False)
    |> selection.select("b", True)
  should.equal(selection.is_selected(sel, "a"), True)
  should.equal(selection.is_selected(sel, "b"), True)
}

pub fn multi_select_without_extend_replaces_test() {
  let sel =
    selection.new(Multi)
    |> selection.select("a", False)
    |> selection.select("b", False)
  should.equal(selection.is_selected(sel, "a"), False)
  should.equal(selection.is_selected(sel, "b"), True)
}

pub fn toggle_adds_and_removes_test() {
  let sel =
    selection.new(Multi)
    |> selection.toggle("a")
  should.equal(selection.is_selected(sel, "a"), True)
  let sel = selection.toggle(sel, "a")
  should.equal(selection.is_selected(sel, "a"), False)
}

pub fn deselect_removes_item_test() {
  let sel =
    selection.new(Multi)
    |> selection.select("a", False)
    |> selection.deselect("a")
  should.equal(selection.is_selected(sel, "a"), False)
}

pub fn clear_removes_all_test() {
  let sel =
    selection.new(Multi)
    |> selection.select("a", False)
    |> selection.select("b", True)
    |> selection.clear()
  should.equal(set.size(selection.selected(sel)), 0)
}

pub fn range_select_selects_between_anchor_and_target_test() {
  let order = ["a", "b", "c", "d", "e"]
  let sel =
    selection.new_with_order(Range, order)
    |> selection.select("b", False)
    |> selection.range_select("d")
  should.equal(selection.is_selected(sel, "a"), False)
  should.equal(selection.is_selected(sel, "b"), True)
  should.equal(selection.is_selected(sel, "c"), True)
  should.equal(selection.is_selected(sel, "d"), True)
  should.equal(selection.is_selected(sel, "e"), False)
}

pub fn range_select_reverse_direction_test() {
  let order = ["a", "b", "c", "d", "e"]
  let sel =
    selection.new_with_order(Range, order)
    |> selection.select("d", False)
    |> selection.range_select("b")
  should.equal(selection.is_selected(sel, "b"), True)
  should.equal(selection.is_selected(sel, "c"), True)
  should.equal(selection.is_selected(sel, "d"), True)
}

pub fn range_select_no_anchor_selects_single_test() {
  let order = ["a", "b", "c"]
  let sel =
    selection.new_with_order(Range, order)
    |> selection.range_select("b")
  should.equal(selection.is_selected(sel, "b"), True)
  should.equal(set.size(selection.selected(sel)), 1)
}
