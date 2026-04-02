# Lists and Inputs

This chapter covers dynamic list rendering, scoped IDs, `text_input`,
`checkbox`, and the `focus` command.

## Dynamic lists with keyed_column

To display a dynamic list of items, use `keyed_column`. It matches
children to their previous state by ID instead of position, preserving
widget state (focus, scroll position) across list changes:

```gleam
import plushie/ui
import gleam/list

ui.keyed_column_("", {
  list.map(model.files, fn(file) {
    ui.container(file, [], [
      ui.row_("", [
        ui.button_("select", file),
        ui.button_("delete", "x"),
      ]),
    ])
  })
})
```

Use `keyed_column` for any list that changes at runtime. Use `column` for
static layouts where the children are fixed.

## Scoped IDs

Each file in the list needs controls, at least a delete button. But if
every delete button has `id: "delete"`, how does `update` know which file
to delete?

This is what **scoped IDs** solve. When you wrap widgets in a named
`container`, the container's ID becomes part of the scope chain. Events from
widgets inside carry that scope:

```gleam
WidgetClick(id: "delete", scope: [file, ..], ..) ->
  delete_file(model, file)
```

For a full treatment of scoping rules, see the
[Scoped IDs reference](../reference/scoped-ids.md).

## Text input

`text_input` is a single-line input widget:

```gleam
ui.text_input("new-name", model.new_name, [
  text_input.Placeholder("name.gleam"),
  text_input.OnSubmit(True),
])
```

The `WidgetInput` event delivers the current text as `value`. The
`WidgetSubmit` event fires when Enter is pressed (when `OnSubmit(True)`
is set).

## Checkbox

`checkbox` is a boolean toggle widget:

```gleam
ui.checkbox("auto-save", model.auto_save, [])
```

It emits a `WidgetToggle` event with the new boolean value.

## Commands: focus

Sometimes `update` needs to trigger a side effect. Instead of returning a
bare model, you return a `#(model, command)` tuple:

```gleam
import plushie/command

#(model, command.focus("editor"))
```

`command.focus` sets keyboard focus on a widget by its scoped path.
Commands are pure data. The runtime executes them after `update` returns.
See the [Commands reference](../reference/commands.md) for the full list.

---

Next: [Layout](07-layout.md)
