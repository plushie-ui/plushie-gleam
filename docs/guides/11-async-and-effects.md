# Async and Effects

## Async commands

`command.async` runs a function in a separate process and delivers the
result as an event:

```gleam
import plushie/command

let cmd = command.task(fn() { Ok(fetch_data()) }, "data_loaded")
#(Model(..model, status: Loading), cmd)
```

The result arrives as an `AsyncResult` event:

```gleam
AsyncResult(tag: "data_loaded", result: Ok(data), ..) ->
  Model(..model, status: Done, data: data)
AsyncResult(tag: "data_loaded", result: Error(reason), ..) ->
  Model(..model, status: Failed, error: Some(reason))
```

## Platform effects

Effects are asynchronous requests to the renderer for platform operations.
Every effect takes a string tag as its first argument:

```gleam
import plushie/effect

let cmd = effect.file_open("import", [
  effect.Title("Import File"),
  effect.Filters([#("Gleam", "*.gleam")]),
])
#(model, cmd)
```

The result arrives as an `EffectResult` event:

```gleam
EffectResult(tag: "import", result: Ok(data), ..) -> {
  let path = data.path
  // ... load the file
}
EffectResult(tag: "import", result: Cancelled, ..) -> model
```

Available effects:

- `effect.file_open` / `effect.file_open_multiple` - file selection
- `effect.file_save` - save dialog
- `effect.directory_select` / `effect.directory_select_multiple`
- `effect.clipboard_read` / `effect.clipboard_write`
- `effect.notification` - desktop notifications

## Multi-window

Return multiple windows from `view`:

```gleam
fn view(model: Model) {
  let windows = [
    ui.window("main", "My App", [main_content(model)]),
  ]

  case model.detached {
    True -> [
      ui.window_with("detail", "Detail", [
        window.ExitOnCloseRequest(False),
      ], [detail_content(model)]),
      ..windows
    ]
    False -> windows
  }
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
