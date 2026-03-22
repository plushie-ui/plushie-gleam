//// Integration tests for the Notes example.

import gleam/option
import gleeunit/should
import plushie/testing
import plushie/testing/element

import examples/notes

pub fn starts_with_heading_test() {
  let session = testing.start(notes.app())
  let assert option.Some(el) = testing.find(session, "heading")
  should.equal(element.text(el), option.Some("Notes"))
}

pub fn new_note_button_exists_test() {
  let session = testing.start(notes.app())
  should.be_true(option.is_some(testing.find(session, "new_note")))
}

pub fn delete_selected_button_exists_test() {
  let session = testing.start(notes.app())
  should.be_true(option.is_some(testing.find(session, "delete_selected")))
}

pub fn search_input_exists_test() {
  let session = testing.start(notes.app())
  should.be_true(option.is_some(testing.find(session, "search")))
}

pub fn creating_new_note_navigates_to_edit_test() {
  let session = testing.start(notes.app())
  let session = testing.click(session, "new_note")
  // In edit view, back/undo/redo buttons should exist
  should.be_true(option.is_some(testing.find(session, "back")))
  should.be_true(option.is_some(testing.find(session, "undo")))
  should.be_true(option.is_some(testing.find(session, "redo")))
  // Heading should no longer be visible (we're on the edit route)
  should.be_true(option.is_none(testing.find(session, "heading")))
}

pub fn edit_view_has_title_and_body_test() {
  let session = testing.start(notes.app())
  let session = testing.click(session, "new_note")
  should.be_true(option.is_some(testing.find(session, "title")))
  should.be_true(option.is_some(testing.find(session, "body")))
}

pub fn navigating_back_returns_to_list_test() {
  let session = testing.start(notes.app())
  let session = testing.click(session, "new_note")
  let session = testing.click(session, "back")
  // Back on the list view -- heading should be visible again
  let assert option.Some(el) = testing.find(session, "heading")
  should.equal(element.text(el), option.Some("Notes"))
}

pub fn edits_are_saved_when_navigating_back_test() {
  let session = testing.start(notes.app())
  let session = testing.click(session, "new_note")
  let session = testing.type_text(session, "title", "Saved Title")
  let session = testing.click(session, "back")
  // The note should appear in the list with checkbox label "Saved Title"
  let assert option.Some(el) = testing.find(session, "note_select:1")
  let assert option.Some(text) = element.text(el)
  should.equal(text, "Saved Title")
}

pub fn created_note_has_edit_button_test() {
  let session = testing.start(notes.app())
  let session = testing.click(session, "new_note")
  let session = testing.click(session, "back")
  should.be_true(option.is_some(testing.find(session, "note:1")))
}

pub fn selecting_and_deleting_a_note_test() {
  let session = testing.start(notes.app())
  // Create two notes
  let session = testing.click(session, "new_note")
  let session = testing.click(session, "back")
  let session = testing.click(session, "new_note")
  let session = testing.click(session, "back")
  // Both notes should exist
  should.be_true(option.is_some(testing.find(session, "note:1")))
  should.be_true(option.is_some(testing.find(session, "note:2")))
  // Select first note and delete
  let session = testing.toggle(session, "note_select:1")
  let session = testing.click(session, "delete_selected")
  // First note should be gone, second should remain
  should.be_true(option.is_none(testing.find(session, "note:1")))
  should.be_true(option.is_some(testing.find(session, "note:2")))
}

pub fn untitled_note_shows_placeholder_test() {
  let session = testing.start(notes.app())
  let session = testing.click(session, "new_note")
  let session = testing.click(session, "back")
  let assert option.Some(el) = testing.find(session, "note_select:1")
  let assert option.Some(text) = element.text(el)
  should.equal(text, "(untitled)")
}

pub fn search_input_filters_notes_test() {
  let session = testing.start(notes.app())
  // Create a note with a title
  let session = testing.click(session, "new_note")
  let session = testing.type_text(session, "title", "Findable")
  let session = testing.click(session, "back")
  // Create another note
  let session = testing.click(session, "new_note")
  let session = testing.type_text(session, "title", "Other")
  let session = testing.click(session, "back")
  // Search for "Find" -- only the matching note should appear
  let session = testing.type_text(session, "search", "Find")
  should.be_true(option.is_some(testing.find(session, "note:1")))
  should.be_true(option.is_none(testing.find(session, "note:2")))
}
