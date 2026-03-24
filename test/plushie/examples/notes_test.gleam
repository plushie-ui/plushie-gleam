//// Integration tests for the Notes example.

import gleam/option
import gleeunit/should
import plushie/testing
import plushie/testing/element

import examples/notes

pub fn starts_with_heading_test() {
  let ctx = testing.start(notes.app())
  let assert option.Some(el) = testing.find(ctx, "heading")
  should.equal(element.text(el), option.Some("Notes"))
}

pub fn new_note_button_exists_test() {
  let ctx = testing.start(notes.app())
  should.be_true(option.is_some(testing.find(ctx, "new_note")))
}

pub fn delete_selected_button_exists_test() {
  let ctx = testing.start(notes.app())
  should.be_true(option.is_some(testing.find(ctx, "delete_selected")))
}

pub fn search_input_exists_test() {
  let ctx = testing.start(notes.app())
  should.be_true(option.is_some(testing.find(ctx, "search")))
}

pub fn creating_new_note_navigates_to_edit_test() {
  let ctx = testing.start(notes.app())
  let ctx = testing.click(ctx, "new_note")
  // In edit view, back/undo/redo buttons should exist
  should.be_true(option.is_some(testing.find(ctx, "back")))
  should.be_true(option.is_some(testing.find(ctx, "undo")))
  should.be_true(option.is_some(testing.find(ctx, "redo")))
  // Heading should no longer be visible (we're on the edit route)
  should.be_true(option.is_none(testing.find(ctx, "heading")))
}

pub fn edit_view_has_title_and_body_test() {
  let ctx = testing.start(notes.app())
  let ctx = testing.click(ctx, "new_note")
  should.be_true(option.is_some(testing.find(ctx, "title")))
  should.be_true(option.is_some(testing.find(ctx, "body")))
}

pub fn navigating_back_returns_to_list_test() {
  let ctx = testing.start(notes.app())
  let ctx = testing.click(ctx, "new_note")
  let ctx = testing.click(ctx, "back")
  // Back on the list view -- heading should be visible again
  let assert option.Some(el) = testing.find(ctx, "heading")
  should.equal(element.text(el), option.Some("Notes"))
}

pub fn edits_are_saved_when_navigating_back_test() {
  let ctx = testing.start(notes.app())
  let ctx = testing.click(ctx, "new_note")
  let ctx = testing.type_text(ctx, "title", "Saved Title")
  let ctx = testing.click(ctx, "back")
  // The note should appear in the list with checkbox label "Saved Title"
  let assert option.Some(el) = testing.find(ctx, "note_select:1")
  let assert option.Some(text) = element.text(el)
  should.equal(text, "Saved Title")
}

pub fn created_note_has_edit_button_test() {
  let ctx = testing.start(notes.app())
  let ctx = testing.click(ctx, "new_note")
  let ctx = testing.click(ctx, "back")
  should.be_true(option.is_some(testing.find(ctx, "note:1")))
}

pub fn selecting_and_deleting_a_note_test() {
  let ctx = testing.start(notes.app())
  // Create two notes
  let ctx = testing.click(ctx, "new_note")
  let ctx = testing.click(ctx, "back")
  let ctx = testing.click(ctx, "new_note")
  let ctx = testing.click(ctx, "back")
  // Both notes should exist
  should.be_true(option.is_some(testing.find(ctx, "note:1")))
  should.be_true(option.is_some(testing.find(ctx, "note:2")))
  // Select first note and delete
  let ctx = testing.toggle(ctx, "note_select:1")
  let ctx = testing.click(ctx, "delete_selected")
  // First note should be gone, second should remain
  should.be_true(option.is_none(testing.find(ctx, "note:1")))
  should.be_true(option.is_some(testing.find(ctx, "note:2")))
}

pub fn untitled_note_shows_placeholder_test() {
  let ctx = testing.start(notes.app())
  let ctx = testing.click(ctx, "new_note")
  let ctx = testing.click(ctx, "back")
  let assert option.Some(el) = testing.find(ctx, "note_select:1")
  let assert option.Some(text) = element.text(el)
  should.equal(text, "(untitled)")
}

pub fn search_input_filters_notes_test() {
  let ctx = testing.start(notes.app())
  // Create a note with a title
  let ctx = testing.click(ctx, "new_note")
  let ctx = testing.type_text(ctx, "title", "Findable")
  let ctx = testing.click(ctx, "back")
  // Create another note
  let ctx = testing.click(ctx, "new_note")
  let ctx = testing.type_text(ctx, "title", "Other")
  let ctx = testing.click(ctx, "back")
  // Search for "Find" -- only the matching note should appear
  let ctx = testing.type_text(ctx, "search", "Find")
  should.be_true(option.is_some(testing.find(ctx, "note:1")))
  should.be_true(option.is_none(testing.find(ctx, "note:2")))
}
