# Scoped IDs

Named containers automatically scope their children's IDs, producing
unique hierarchical paths without manual prefixing. This is how you
distinguish "the delete button in file A" from "the delete button in
file B": the container's ID becomes part of the path. Scope resolution
runs during `plushie/tree` normalization, before the diff against the
previous tree.

## Scoping rules

| Node kind | Creates scope? | Notes |
|---|---|---|
| Named container (explicit ID) | Yes | ID pushed onto the scope chain |
| Auto-ID container (empty ID) | No | Transparent, no scope effect |
| Window node (`kind: "window"`) | Yes | Uses `#` separator instead of `/` |

User-provided IDs must not be empty, must not contain `/` or `#`, and
must not exceed 1024 bytes. The slash is reserved for the scope
separator. The `#` is reserved for window-qualified paths
(e.g. `"main#form/email"`). `plushie/tree.normalize` panics on any
violation, because invalid IDs are a programming error, not a
runtime condition.

## ID resolution

During normalization, the scope chain builds canonical wire IDs.
Window nodes use `#` as the separator to their children; containers
within a window use `/`:

```
main (window)               ->  "main"
  sidebar (container)       ->  "main#sidebar"
    form (container)        ->  "main#sidebar/form"
      email (text_input)    ->  "main#sidebar/form/email"
      save (button)         ->  "main#sidebar/form/save"
```

The `#` only appears once, at the window boundary. Deeper nesting
uses `/`. The canonical wire format is `window#scope/path/id`.

Resolution is recursive. The normalizer enforces a maximum tree
depth of 256 levels (and warns at 200) to prevent runaway recursion.

### Auto-ID containers are transparent

Layout widgets (`column`, `row`, `stack`, `grid`, etc.) are typically
created without an explicit ID. The normalizer assigns each one an
`auto:<kind>:<index>` ID based on its sibling position, and these
auto-IDs do not create scope boundaries:

```gleam
import plushie/ui

ui.container("form", [], [
  ui.column("", [], [
    ui.text_input("email", model.email, []),
    ui.button("save", "Save", []),
  ]),
])
```

The text input is scoped as `"form/email"`, not
`"form/auto:column:0/email"`. Intermediate layout widgets exist for
visual arrangement, not semantic grouping. Only widgets you give an
explicit ID create scope boundaries.

## Duplicate ID detection

Normalization walks each level of siblings and panics if any two
share the same ID:

```
plushie: duplicate sibling IDs detected during normalize: ["save"]
```

Detection is sibling-scoped: the same local ID can exist safely in
different scopes because the scope prefix makes the full wire ID
unique.

```gleam
ui.container("form-a", [], [ui.button("save", "Save", [])])
ui.container("form-b", [], [ui.button("save", "Save", [])])
// "form-a/save" and "form-b/save" do not collide
```

## Dynamic IDs

IDs can be any string, including values read from the model. This is
the canonical pattern for list items:

```gleam
import gleam/list
import plushie/ui

list.map(model.files, fn(file) {
  ui.container(file, [], [
    ui.button("select", file, []),
    ui.button("delete", "x", []),
  ])
})
```

Each file becomes a scope. The delete button for `"hello.gleam"` has
the wire ID `"hello.gleam/delete"`. Extract the filename from the
scope chain in `update`:

```gleam
case event {
  Widget(Click(target: EventTarget(id: "delete", scope: [file, ..], ..))) ->
    delete_file(model, file)
  _ -> model
}
```

Dynamic IDs follow the same rules as static IDs: no `/`, no `#`, not
empty, within the byte cap, unique among siblings.

## Event target fields

When the renderer emits a widget event, the wire ID is the canonical
`window#scope/path/id` string. `plushie/event.make_target` splits it
into an `EventTarget` record:

```gleam
pub type EventTarget {
  EventTarget(window_id: String, id: String, scope: List(String), full: String)
}
```

- `id` is the local ID (the last segment).
- `scope` is the ancestor chain in reverse, nearest parent first,
  window ID last.
- `window_id` is the source window.
- `full` is the raw `window#scope/path/id` string as it arrived on
  the wire.

For a widget emitted as `"main#sidebar/form/save"`, the target looks
like:

```gleam
EventTarget(
  window_id: "main",
  id: "save",
  scope: ["form", "sidebar", "main"],
  full: "main#sidebar/form/save",
)
```

The scope is reversed so you can pattern match on the immediate
parent with `[parent, ..]` without caring about deeper ancestry.
The window ID is always the last element, so `[.., window_id]` at
the tail always reflects the originating window. Because `scope`
already carries the window, `window_id` is redundant for matching
but convenient for direct access.

### Pattern matching examples

```gleam
case event {
  // Local ID only, any scope
  Widget(Click(target: EventTarget(id: "save", ..))) -> save(model)

  // Immediate parent match
  Widget(Click(target: EventTarget(id: "save", scope: ["form", ..], ..))) ->
    save_form(model)

  // Bind a dynamic parent (list items)
  Widget(Toggle(
    target: EventTarget(id: "done", scope: [item_id, ..], ..),
    value: on,
  )) -> toggle_item(model, item_id, on)

  // Match by window
  Widget(Click(target: EventTarget(id: "save", window_id: "settings", ..))) ->
    save_settings(model)

  // Top-level widget (only the window in scope)
  Widget(Click(target: EventTarget(id: "save", scope: [wid]))) ->
    save_top_level(model, wid)

  _ -> model
}
```

Only `WidgetEvent` and `ImeEvent` carry per-target scope. Global
events (`KeyEvent`, `ModifiersEvent`, `WindowEvent`, `TimerEvent`,
`AsyncEvent`, `StreamEvent`, `EffectEvent`, `SystemEvent`) are not
scoped to a widget; they either carry a bare `window_id` field or
none at all.

## Canvas element scoping

Canvas elements participate in the same scoping mechanism. The
canvas widget's ID creates a scope, layers create sub-scopes, and
interactive element IDs are scoped under them:

```
main (window)                    ->  "main"
  canvas "drawing"               ->  "main#drawing"
    layer "shapes"               ->  "main#drawing/shapes"
      interactive "handle"       ->  "main#drawing/shapes/handle"
```

Canvas element events are regular `WidgetEvent` values. The
element's scoped wire ID populates `EventTarget.full`:

```gleam
Widget(Press(
  target: EventTarget(
    id: "handle",
    scope: ["shapes", "drawing", "main"],
    window_id: "main",
    ..,
  ),
  ..,
))
```

## Command paths

Commands that address a widget accept the forward-slash scoped
format:

```gleam
import plushie/command

command.focus("form/email")
command.scroll_to("sidebar/list", 0.0, 0.0)
```

In multi-window apps, prefix with `window_id#` to target a widget in
a specific window:

```gleam
command.focus("settings#email")
command.scroll_to("main#sidebar/list", 0.0, 0.0)
```

The `#` separates the window ID from the widget path. Without a
window qualifier, the command targets whatever window contains the
widget. See the [Commands reference](commands.md) for the full
command surface.

## Multi-window scoping

Each window creates a separate namespace. The window ID is the last
element of every event's `scope` list and the value of `window_id`.
A widget in window `"main"` with wire ID `"main#form/save"` is
distinct from the widget at `"settings#form/save"` in window
`"settings"`, and events from one window never trigger a handler
matched on the other:

```gleam
case event {
  Widget(Click(target: EventTarget(id: "save", window_id: "settings", ..))) ->
    save_settings(model)
  _ -> model
}
```

## Test selectors

The test helpers in `plushie/testing` accept the same scoped format,
optionally prefixed with `#`:

```gleam
import plushie/testing

testing.find(ctx, "#save")                     // local ID, any scope
testing.find(ctx, "sidebar/form/save")         // full scoped path
testing.click(ctx, "main#save")                // widget in window "main"
testing.assert_text(ctx, "settings#form/email", "")
```

The leading `#` is optional for plain IDs. When an ID matches in
more than one window, disambiguate by qualifying it with the window
ID: `"main#save"` rather than `"save"`. The test backend resolves
selectors against the normalized tree.

## Accessibility cross-references

A11y props (`labelled_by`, `described_by`, `error_message`,
`active_descendant`, and each element of `radio_group`) reference
widget IDs. Bare IDs are resolved relative to the current scope
during normalization. IDs already containing `/` or `#` pass through
unchanged:

```gleam
import plushie/prop/a11y
import plushie/ui
import plushie/widget/text_input

ui.container("form", [], [
  ui.text("email-label", "Email", []),
  ui.text_input("email", model.email, [
    text_input.A11y(a11y.new() |> a11y.labelled_by("email-label")),
  ]),
])
```

The `labelled_by` value `"email-label"` resolves to `"form/email-label"`
during normalization. If the rewritten reference does not match any
declared widget ID, the normalizer logs a warning but does not panic.

## See also

- [Events reference](events.md): `EventTarget` fields and the full
  `WidgetEvent` variant list
- [Commands reference](commands.md): `focus`, `scroll_to`, and other
  commands that address widgets by scoped path
- [Built-in Widgets reference](built-in-widgets.md): `container`,
  `window`, and other scope-creating widgets
- [Subscriptions reference](subscriptions.md): how pointer and
  keyboard subscriptions surface `window_id` for global events
