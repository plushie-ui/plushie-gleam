# State Management

As apps grow, model management gets complex. Tracking undo history,
managing list selection, navigating between views, searching and sorting
data. These are recurring patterns that Plushie provides as standalone
helper modules.

Each helper is a pure data structure. No processes, no side effects, no
framework coupling. You store them in your model and update them in
`update`. They compose freely: use one, some, or all.

This chapter introduces each helper with an isolated example, then
applies it to the pad.

## plushie/undo

`plushie/undo` tracks reversible actions with an undo / redo stack. An
`UndoStack(model)` wraps the current value along with the history needed
to step backwards and forwards.

```gleam
import gleam/option.{None}
import plushie/undo

let stack = undo.new("")

let stack =
  undo.push(stack, undo.UndoCommand(
    apply: fn(_) { "hello" },
    undo: fn(_) { "" },
    label: "Type hello",
    coalesce_key: None,
    coalesce_window_ms: None,
  ))

undo.current(stack)   // "hello"
undo.can_undo(stack)  // True

let stack = undo.undo(stack)
undo.current(stack)   // ""
undo.can_redo(stack)  // True

let stack = undo.redo(stack)
undo.current(stack)   // "hello"
```

An `UndoCommand` carries `apply` and `undo` functions that take the
current value and return the new one, plus a `label` used by
`undo.undo_history` and `undo.redo_history` for display.

### Coalescing

Rapid sequential changes like keystrokes can be grouped into a single
undo step. Set `coalesce_key` and `coalesce_window_ms`:

```gleam
import gleam/option.{Some}
import gleam/string
import plushie/undo

undo.push(stack, undo.UndoCommand(
  apply: fn(text) { text <> "a" },
  undo: fn(text) { string.drop_end(text, 1) },
  label: "Typing",
  coalesce_key: Some("typing"),
  coalesce_window_ms: Some(500),
))
```

Commands with the same `coalesce_key` that arrive within the window
merge into one undo entry. One undo reverses the entire burst, and redo
reapplies the merged commands in the original order.

Treat the `UndoStack` as the source of truth for undoable state. The
stack is opaque, so normal Gleam code cannot edit its current value
directly. If you keep a cached field beside the stack for rendering,
update that field from `undo.current` after every `push`, `undo`, and
`redo`; do not edit the cached field independently.

### Applying it: editor undo / redo

Track editor changes with an `UndoStack(String)` that holds the source
text. Add `undo: undo.UndoStack(String)` to the model, initialize it
with `undo.new("")`, and keep the raw `source` field as a cache of
`undo.current(model.undo)`:

```gleam
import gleam/option.{Some}
import plushie/event.{Input, Widget}
import plushie/event/types.{EventTarget}
import plushie/undo

fn update(model: Model, event: Event) -> #(Model, Command(Event)) {
  case event {
    Widget(Input(target: EventTarget(id: "editor", ..), value: new_source)) -> {
      let previous = undo.current(model.undo)
      let stack =
        undo.push(model.undo, undo.UndoCommand(
          apply: fn(_) { new_source },
          undo: fn(_) { previous },
          label: "Edit",
          coalesce_key: Some("typing"),
          coalesce_window_ms: Some(500),
        ))
      #(
        Model(..model, source: undo.current(stack), undo: stack, dirty: True),
        command.none(),
      )
    }
    _ -> #(model, command.none())
  }
}
```

Bind Ctrl+Z and Ctrl+Shift+Z on the top-level `Key` family. The
`command` modifier is true for the Command key on macOS and Ctrl on
other platforms, so one branch handles both:

```gleam
import plushie/event.{Key, KeyEvent, KeyPressed}
import plushie/event/types.{Modifiers}
import plushie/undo

Key(KeyEvent(event_type: KeyPressed, key: "z",
             modifiers: Modifiers(command: True, shift: False, ..), ..)) ->
  case undo.can_undo(model.undo) {
    True -> {
      let s = undo.undo(model.undo)
      #(Model(..model, undo: s, source: undo.current(s)), command.none())
    }
    False -> #(model, command.none())
  }

Key(KeyEvent(event_type: KeyPressed, key: "z",
             modifiers: Modifiers(command: True, shift: True, ..), ..)) ->
  case undo.can_redo(model.undo) {
    True -> {
      let s = undo.redo(model.undo)
      #(Model(..model, undo: s, source: undo.current(s)), command.none())
    }
    False -> #(model, command.none())
  }
```

See the [`plushie/undo` source](../../src/plushie/undo.gleam) for the
full API, including `undo.new_with_max_size`, `undo.undo_history`, and
`undo.redo_history`.

## plushie/data

`plushie/data` provides a query pipeline for filtering, searching,
sorting, and paginating in-memory collections. The pipeline runs in a
fixed order: filter, search, sort, paginate, group.

```gleam
import plushie/data.{Asc, Filter, Page, PageSize, Search, Sort}

let records = [
  Person("Alice", "dev"),
  Person("Bob", "design"),
  Person("Carol", "dev"),
]

let result = data.query(records, [
  Search(fields: [fn(p) { p.name }, fn(p) { p.role }], query: "dev"),
  Sort(direction: Asc, key: fn(p) { p.name }),
  Page(1),
  PageSize(10),
])

result.entries  // [Person("Alice", "dev"), Person("Carol", "dev")]
result.total    // 2
```

Repeated `Filter` and `Search` entries compose as successive narrowing
steps in list order. All options are optional.

| Option | Signature | Description |
|---|---|---|
| `Filter` | `fn(a) -> Bool` | Predicate; repeated entries compose |
| `Search` | `fields: List(fn(a) -> String), query: String` | Case-insensitive substring match; repeated entries compose |
| `Sort` | `direction: SortDirection, key: fn(a) -> String` | Lexicographic sort by string key |
| `SortBy` | `direction: SortDirection, compare: fn(a, a) -> Order` | Custom comparison for numeric or complex sorts |
| `Page` | `Int` | Page number (1-based, default 1) |
| `PageSize` | `Int` | Items per page (default 25) |
| `Group` | `fn(a) -> String` | Group paginated results by key |

Multiple `Sort` / `SortBy` options chain into multi-column tiebreaking.
`SortDirection` is `Asc` or `Desc`.

### Applying it: search experiments

Add a `search_query: String` field to the model, update it on each
keystroke from a search `text_input`, and run the file list through
`data.query` when the query is non-empty:

```gleam
import gleam/string
import plushie/data.{Search}

let files = case model.search_query {
  "" -> model.files
  query ->
    data.query(model.files, [
      Search(fields: [fn(name) { name }], query: query),
    ]).entries
}
```

Match is case-insensitive by construction, so the user does not need to
mirror the file list's casing.

## plushie/selection

`plushie/selection` manages selection state for lists with three modes:

```gleam
import plushie/selection.{Multi}

let sel = selection.new(Multi)

let sel = selection.select(sel, "file_a", False)
let sel = selection.toggle(sel, "file_b")
selection.is_selected(sel, "file_a")  // True
selection.is_selected(sel, "file_b")  // True
selection.selected(sel)               // set.from_list(["file_a", "file_b"])

let sel = selection.clear(sel)
selection.selected(sel)               // set.new()
```

Modes:

- `Single`: at most one item selected. Selecting a new item deselects
  the previous one.
- `Multi`: any number of items. `toggle` adds or removes; `select` with
  `extend: True` adds without clearing.
- `Range`: contiguous selection with an anchor. `range_select` selects
  every item between the anchor and the target using the order list
  passed to `selection.new_with_order`.

`selection.new(Range)` panics because range mode requires a known item
order. Use `selection.new_with_order(Range, ids)` instead.

### Applying it: multi-select experiments

Add `selection: selection.new(Multi)` to the model. Put a checkbox next
to each file entry and match the toggle event, using `scope` to recover
the file ID from the list row:

```gleam
import plushie/event.{Toggle, Widget}
import plushie/event/types.{EventTarget}
import plushie/selection

Widget(Toggle(target: EventTarget(id: "select", scope: [file, ..], ..), ..)) ->
  #(
    Model(..model, selection: selection.toggle(model.selection, file)),
    command.none(),
  )
```

Render the checkbox per row with its current state:

```gleam
import plushie/selection
import plushie/ui

ui.checkbox("select", "", selection.is_selected(model.selection, file), [])
```

A "Delete Selected" button drops the selected entries and clears the
selection afterwards:

```gleam
import gleam/set
import plushie/selection

Widget(Click(target: EventTarget(id: "delete-selected", ..))) -> {
  let ids = selection.selected(model.selection)
  let remaining = list.filter(model.files, fn(f) { !set.contains(ids, f) })
  #(
    Model(..model, files: remaining, selection: selection.clear(model.selection)),
    command.none(),
  )
}
```

Style the sidebar row to reflect both the active file and the selection:
the active file wins visually, with selected (but not active) rows
rendered as secondary.

## plushie/route

`plushie/route` manages a LIFO navigation stack for multi-view apps. The
current path is a string, and each entry carries an optional param dict:

```gleam
import gleam/dict
import plushie/route

let r = route.new("editor")
route.current(r)       // "editor"

let r = route.push_with_params(r, "browser", dict.from_list([#("sort", "name")]))
route.current(r)       // "browser"
route.params(r)        // dict.from_list([#("sort", "name")])
route.can_go_back(r)   // True

let r = route.pop(r)
route.current(r)       // "editor"
```

`route.pop` on a single-entry stack returns it unchanged: the root entry
never pops. There is no forward stack; navigation is back-only. Push a
new path again to move forward.

### Applying it: view switching

Add a browser view to the pad that shows all experiments in a grid with
previews. Store `route: route.new("editor")` in the model. Push the
browser path on a toolbar click, pop on "back":

```gleam
import plushie/event.{Click, Widget}
import plushie/event/types.{EventTarget}
import plushie/route

Widget(Click(target: EventTarget(id: "show-browser", ..))) ->
  #(Model(..model, route: route.push(model.route, "browser")), command.none())

Widget(Click(target: EventTarget(id: "back-to-editor", ..))) ->
  #(Model(..model, route: route.pop(model.route)), command.none())
```

In `view`, dispatch on the current path. Since `route.current` returns a
`String`, wrap the paths you actually use in a helper (or keep the match
literal and let the compiler catch typos via a default arm):

```gleam
import plushie/route

case route.current(model.route) {
  "editor" -> editor_view(model)
  "browser" -> browser_view(model)
  _ -> editor_view(model)
}
```

Use `route.params` inside the browser view to read any params passed on
push (a selected tag, a sort order, etc). The dict is keyed by string,
so keep the set of keys small and documented near the push site.

## Verify it

Test that undo / redo cycles through the editor state. The testing
harness dispatches wire events into the runtime and lets you assert on
the resulting model:

```gleam
import gleeunit/should
import plushie/testing

pub fn undo_redo_test() {
  let session = testing.start(pad.app(), [])

  testing.type_text(session, "editor", "new content")
  let after_edit = testing.model(session).source

  testing.press_key(session, "z", [testing.Command])
  testing.model(session).source |> should.not_equal(after_edit)

  testing.press_key(session, "z", [testing.Command, testing.Shift])
  testing.model(session).source |> should.equal(after_edit)
}
```

This runs against the real renderer binary. Typing coalesces into a
single undo entry, Ctrl+Z reverts it, Ctrl+Shift+Z restores it.

## Try it

Write state management experiments in your pad:

- Build a mini text editor that shows `undo.undo_history(model.undo)`
  as a list beside the editor pane.
- Create a filterable list with `data.query`. Add sort controls that
  toggle between `Asc` and `Desc` using `SortBy`.
- Build a multi-select list with checkboxes. Show the selection count
  via `set.size(selection.selected(model.selection))`. Add "Select All"
  and "Clear" buttons.
- Create a two-path app with `route`: a list path and a detail path.
  Use `route.push_with_params` to pass the selected item ID in the
  param dict, and read it back with `route.params` in the detail view.

In the next chapter, we test the pad and its extracted widgets.

---

Next: [Testing](15-testing.md)
