//// Integration tests for the Catalog example.

import gleam/option
import gleeunit/should
import plushie/testing
import plushie/testing/element

import examples/catalog

pub fn title_renders_test() {
  let session = testing.start(catalog.app())
  let assert option.Some(el) = testing.find(session, "catalog_title")
  should.equal(element.text(el), option.Some("Plushie Widget Catalog"))
}

pub fn tab_buttons_exist_test() {
  let session = testing.start(catalog.app())
  should.be_true(option.is_some(testing.find(session, "tab_layout")))
  should.be_true(option.is_some(testing.find(session, "tab_input")))
  should.be_true(option.is_some(testing.find(session, "tab_display")))
  should.be_true(option.is_some(testing.find(session, "tab_composite")))
}

pub fn starts_on_layout_tab_test() {
  let session = testing.start(catalog.app())
  let assert option.Some(el) = testing.find(session, "layout_heading")
  should.equal(element.text(el), option.Some("Layout Widgets"))
}

pub fn switching_to_input_tab_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_input")
  let assert option.Some(el) = testing.find(session, "input_heading")
  should.equal(element.text(el), option.Some("Input Widgets"))
}

pub fn switching_to_display_tab_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_display")
  let assert option.Some(el) = testing.find(session, "display_heading")
  should.equal(element.text(el), option.Some("Display Widgets"))
}

pub fn switching_to_composite_tab_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_composite")
  let assert option.Some(el) = testing.find(session, "composite_heading")
  should.equal(element.text(el), option.Some("Interactive & Composite Widgets"))
}

pub fn input_tab_has_text_input_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_input")
  should.be_true(option.is_some(testing.find(session, "demo_input")))
}

pub fn input_tab_has_checkbox_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_input")
  should.be_true(option.is_some(testing.find(session, "demo_check")))
}

pub fn input_tab_has_toggler_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_input")
  should.be_true(option.is_some(testing.find(session, "demo_toggler")))
}

pub fn input_tab_has_slider_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_input")
  should.be_true(option.is_some(testing.find(session, "demo_slider")))
}

pub fn composite_tab_counter_button_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_composite")
  should.be_true(option.is_some(testing.find(session, "counter_btn")))
  let session = testing.click(session, "counter_btn")
  let assert option.Some(el) = testing.find(session, "click_text")
  should.equal(element.text(el), option.Some("Clicked 1 times"))
}

pub fn composite_tab_has_demo_tabs_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_composite")
  should.be_true(option.is_some(testing.find(session, "demo_tabs")))
  should.be_true(option.is_some(testing.find(session, "tab_one")))
  should.be_true(option.is_some(testing.find(session, "tab_two")))
}

pub fn composite_tab_modal_starts_hidden_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_composite")
  should.be_true(option.is_some(testing.find(session, "show_modal")))
  should.be_true(option.is_none(testing.find(session, "demo_modal")))
}

pub fn showing_and_hiding_modal_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_composite")
  let session = testing.click(session, "show_modal")
  should.be_true(option.is_some(testing.find(session, "demo_modal")))
  let session = testing.click(session, "hide_modal")
  should.be_true(option.is_none(testing.find(session, "demo_modal")))
}

pub fn collapsing_and_expanding_panel_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_composite")
  // Panel starts expanded
  should.be_true(option.is_some(testing.find(session, "panel_content")))
  // Collapse it
  let session = testing.click(session, "demo_panel")
  should.be_true(option.is_none(testing.find(session, "panel_content")))
  // Expand it again
  let session = testing.click(session, "demo_panel")
  should.be_true(option.is_some(testing.find(session, "panel_content")))
}

pub fn layout_tab_has_containers_test() {
  let session = testing.start(catalog.app())
  should.be_true(option.is_some(testing.find(session, "demo_container")))
  should.be_true(option.is_some(testing.find(session, "demo_scrollable")))
}

pub fn display_tab_has_canvas_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_display")
  should.be_true(option.is_some(testing.find(session, "demo_canvas")))
}

pub fn display_tab_has_markdown_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_display")
  should.be_true(option.is_some(testing.find(session, "demo_markdown")))
}

pub fn composite_tab_has_table_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_composite")
  should.be_true(option.is_some(testing.find(session, "demo_table")))
}

pub fn composite_tab_has_pane_grid_test() {
  let session = testing.start(catalog.app())
  let session = testing.click(session, "tab_composite")
  should.be_true(option.is_some(testing.find(session, "demo_panes")))
}
