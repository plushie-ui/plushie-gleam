import gleeunit/should
import plushie/event.{WidgetClick, WidgetInput, WidgetToggle}

// -- Scope splitting from wire -----------------------------------------------

pub fn scoped_ids_wire_split_test() {
  // Wire ID "sidebar/form/save" splits into id: "save", scope: ["form", "sidebar"]
  let event =
    WidgetClick(window_id: "main", id: "save", scope: ["form", "sidebar"])
  event.id |> should.equal("save")
  event.scope |> should.equal(["form", "sidebar"])
}

// -- Match on local ID only --------------------------------------------------

pub fn scoped_ids_match_local_id_test() {
  let event =
    WidgetClick(window_id: "main", id: "save", scope: ["form", "sidebar"])
  case event {
    WidgetClick(window_id: "main", id: "save", ..) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Match on ID + immediate parent ------------------------------------------

pub fn scoped_ids_match_immediate_parent_test() {
  let event =
    WidgetClick(window_id: "main", id: "save", scope: ["form", "sidebar"])
  case event {
    WidgetClick(window_id: "main", id: "save", scope: ["form", ..]) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

// -- Bind parent for dynamic lists -------------------------------------------

pub fn scoped_ids_dynamic_list_bind_parent_test() {
  let event =
    WidgetToggle(
      window_id: "main",
      id: "done",
      scope: ["item_42", "todo_list"],
      value: True,
    )
  case event {
    WidgetToggle(window_id: "main", id: "done", scope: [item_id, ..], ..) ->
      item_id |> should.equal("item_42")
    _ -> should.fail()
  }
}

pub fn scoped_ids_dynamic_list_delete_test() {
  let event =
    WidgetClick(window_id: "main", id: "delete", scope: ["item_7", "todo_list"])
  case event {
    WidgetClick(window_id: "main", id: "delete", scope: [item_id, ..]) ->
      item_id |> should.equal("item_7")
    _ -> should.fail()
  }
}

// -- Depth-agnostic matching -------------------------------------------------

pub fn scoped_ids_depth_agnostic_test() {
  let event =
    WidgetInput(
      window_id: "main",
      id: "query",
      scope: ["search", "sidebar", "root"],
      value: "hi",
    )
  case event {
    WidgetInput(window_id: "main", id: "query", scope: ["search", ..], ..) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

// -- Exact depth matching ----------------------------------------------------

pub fn scoped_ids_exact_depth_test() {
  let event =
    WidgetInput(window_id: "main", id: "query", scope: ["search"], value: "hi")
  case event {
    WidgetInput(window_id: "main", id: "query", scope: ["search"], ..) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn scoped_ids_exact_depth_mismatch_test() {
  // Two scope levels should NOT match the exact single-scope pattern
  let event =
    WidgetInput(
      window_id: "main",
      id: "query",
      scope: ["search", "panel"],
      value: "hi",
    )
  case event {
    WidgetInput(window_id: "main", id: "query", scope: ["search"], ..) ->
      should.fail()
    _ -> should.be_true(True)
  }
}

// -- No scope matching -------------------------------------------------------

pub fn scoped_ids_no_scope_test() {
  let event = WidgetClick(window_id: "main", id: "save", scope: [])
  case event {
    WidgetClick(window_id: "main", id: "save", scope: []) ->
      should.be_true(True)
    _ -> should.fail()
  }
}

pub fn scoped_ids_no_scope_mismatch_test() {
  // Scoped event should NOT match the empty-scope pattern
  let event = WidgetClick(window_id: "main", id: "save", scope: ["form"])
  case event {
    WidgetClick(window_id: "main", id: "save", scope: []) -> should.fail()
    _ -> should.be_true(True)
  }
}
