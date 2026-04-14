import gleeunit/should
import plushie/event.{Click, EventTarget, Input, Toggle, Widget}

// -- Scope splitting from wire -----------------------------------------------

pub fn scoped_ids_wire_split_test() {
  // Wire ID "sidebar/form/save" splits into id: "save", scope: ["form", "sidebar"]
  let event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: [
          "form",
          "sidebar",
        ],
        full: "save",
      )),
    )
  let assert Widget(Click(target:)) = event
  target.id |> should.equal("save")
  target.scope |> should.equal(["form", "sidebar"])
}

// -- Match on local ID only --------------------------------------------------

pub fn scoped_ids_match_local_id_test() {
  let event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: [
          "form",
          "sidebar",
        ],
        full: "save",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(id: "save", ..))) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Match on ID + immediate parent ------------------------------------------

pub fn scoped_ids_match_immediate_parent_test() {
  let event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: [
          "form",
          "sidebar",
        ],
        full: "save",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(
      window_id: "main",
      id: "save",
      scope: ["form", ..],
      ..,
    ))) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Bind parent for dynamic lists -------------------------------------------

pub fn scoped_ids_dynamic_list_bind_parent_test() {
  let event =
    Widget(Toggle(
      target: EventTarget(
        window_id: "main",
        id: "done",
        scope: [
          "item_42",
          "todo_list",
        ],
        full: "done",
      ),
      value: True,
    ))
  case event {
    Widget(Toggle(target: EventTarget(id: "done", scope: [item_id, ..], ..), ..)) ->
      item_id |> should.equal("item_42")
    _ -> should.fail()
  }
}

pub fn scoped_ids_dynamic_list_delete_test() {
  let event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "delete",
        scope: [
          "item_7",
          "todo_list",
        ],
        full: "delete",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(
      window_id: "main",
      id: "delete",
      scope: [item_id, ..],
      ..,
    ))) -> item_id |> should.equal("item_7")
    _ -> should.fail()
  }
}

// -- Depth-agnostic matching -------------------------------------------------

pub fn scoped_ids_depth_agnostic_test() {
  let event =
    Widget(Input(
      target: EventTarget(
        window_id: "main",
        id: "query",
        scope: [
          "search",
          "sidebar",
          "root",
        ],
        full: "query",
      ),
      value: "hi",
    ))
  case event {
    Widget(Input(
      target: EventTarget(id: "query", scope: ["search", ..], ..),
      ..,
    )) -> should.be_true(True)
    _ -> should.fail()
  }
}

// -- Exact depth matching ----------------------------------------------------

pub fn scoped_ids_exact_depth_test() {
  let event =
    Widget(Input(
      target: EventTarget(
        window_id: "main",
        id: "query",
        scope: ["search"],
        full: "query",
      ),
      value: "hi",
    ))
  case event {
    Widget(Input(
      target: EventTarget(
        window_id: "main",
        id: "query",
        scope: ["search"],
        full: "query",
      ),
      ..,
    )) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn scoped_ids_exact_depth_mismatch_test() {
  // Two scope levels should NOT match the exact single-scope pattern
  let event =
    Widget(Input(
      target: EventTarget(
        window_id: "main",
        id: "query",
        scope: [
          "search",
          "panel",
        ],
        full: "query",
      ),
      value: "hi",
    ))
  case event {
    Widget(Input(
      target: EventTarget(
        window_id: "main",
        id: "query",
        scope: ["search"],
        full: "query",
      ),
      ..,
    )) -> should.fail()
    _ -> should.be_true(True)
  }
}

// -- No scope matching -------------------------------------------------------

pub fn scoped_ids_no_scope_test() {
  let event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: [],
        full: "save",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(
      window_id: "main",
      id: "save",
      scope: [],
      full: "save",
    ))) -> should.be_true(True)
    _ -> should.fail()
  }
}

pub fn scoped_ids_no_scope_mismatch_test() {
  // Scoped event should NOT match the empty-scope pattern
  let event =
    Widget(
      Click(target: EventTarget(
        window_id: "main",
        id: "save",
        scope: ["form"],
        full: "save",
      )),
    )
  case event {
    Widget(Click(target: EventTarget(
      window_id: "main",
      id: "save",
      scope: [],
      full: "save",
    ))) -> should.fail()
    _ -> should.be_true(True)
  }
}
