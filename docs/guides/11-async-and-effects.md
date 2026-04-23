# Async and Effects

## Async commands

`command.task` runs a function in a separate process and delivers the
result as an event:

```gleam
import plushie/command

let cmd = command.task(fn() { fetch_data() }, "data_loaded")
#(Model(..model, status: Loading), cmd)
```

The result arrives as an `Async(AsyncEvent(...))` event:

```gleam
import plushie/command
import plushie/event.{Async, AsyncEvent}

Async(AsyncEvent(tag: "data_loaded", result: Ok(data))) ->
  #(Model(..model, status: Done, data: data), command.none())
Async(AsyncEvent(tag: "data_loaded", result: Error(_))) ->
  #(Model(..model, status: Failed), command.none())
```

## Platform effects

Effects are asynchronous requests to the renderer for platform operations.
Every effect takes a string tag as its first argument:

```gleam
import plushie/effect

let cmd = effect.file_open("import", [
  effect.DialogTitle("Import File"),
  effect.Filters([#("Gleam", "*.gleam")]),
])
#(model, cmd)
```

The result arrives as an `Effect(EffectEvent(...))` event:

```gleam
import plushie/command
import plushie/event.{Effect, EffectCancelled, EffectEvent, FileOpened}

Effect(EffectEvent(tag: "import", result: FileOpened(path: path))) -> {
  let _selected_path = path
  #(model, command.none())
}
Effect(EffectEvent(tag: "import", result: EffectCancelled)) ->
  #(model, command.none())
```

Available effects:

- `effect.file_open` / `effect.file_open_multiple` - file selection
- `effect.file_save` - save dialog
- `effect.directory_select` / `effect.directory_select_multiple`
- `effect.clipboard_read` / `effect.clipboard_write`
- `effect.notification` - desktop notifications

## Multi-window

Return a root node whose direct children are windows:

```gleam
import gleam/option.{Some}
import plushie/node
import plushie/ui
import plushie/widget/window

fn view(model: Model) {
  Some(
    node.empty_container()
    |> node.with_children(
      case model.detached {
        True -> [
          ui.window("main", [window.Title("My App")], [main_content(model)]),
          ui.window("detail", [
            window.Title("Detail"),
            window.ExitOnCloseRequest(False),
          ], [detail_content(model)]),
        ]
        False -> [
          ui.window("main", [window.Title("My App")], [main_content(model)]),
        ]
      },
    )
  )
}
```

Window IDs must be stable strings. `ExitOnCloseRequest(False)` on
secondary windows means closing them only removes the window.

## Batching

Combine multiple commands from a single update:

```gleam
#(model, command.batch([
  effect.clipboard_write("copy", model.source),
  command.focus("editor"),
]))
```

See the [Commands reference](../reference/commands.md) for the full API.

---

Next: [Canvas](12-canvas.md)
