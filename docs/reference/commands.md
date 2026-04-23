# Commands and Effects

Commands are pure data returned from `update` and `init`. The runtime
executes them after the update cycle completes.

## Returning commands

```gleam
// Bare model (no commands)
fn update(model, _event) { model }

// Model + single command
fn update(model, event) {
  case event {
    WidgetClick(id: "save", ..) -> #(model, command.focus("editor"))
    _ -> model
  }
}

// Model + command list
#(model, command.batch([
  effect.file_save("export", [effect.Title("Export")]),
  command.focus("editor"),
]))
```

## Command categories

All functions in `plushie/command` unless noted.

### Control flow

| Function | Purpose |
|---|---|
| `none` | No-op command |
| `batch` | Execute a list of commands sequentially |
| `exit` | Shut down the app |

### Async

| Function | Purpose |
|---|---|
| `async(fn, tag)` | Run in background, result as `AsyncResult` |
| `stream(fn, tag)` | Run with emit callback, values as `StreamValue` |
| `cancel(tag)` | Kill in-flight async/stream by tag |
| `send_after(ms, event)` | One-shot delayed event |

### Focus

| Function | Purpose |
|---|---|
| `focus(path)` | Set focus by scoped ID path |
| `focus_next` | Move focus forward |
| `focus_previous` | Move focus backward |

### Text

`select_all`, `move_cursor_to_front`, `move_cursor_to_end`,
`move_cursor_to`, `select_range`.

### Scroll

`scroll_to`, `snap_to`, `snap_to_end`, `scroll_by`.

### Window operations

`close_window`, `resize_window`, `move_window`, `maximize_window`,
`minimize_window`, `toggle_maximize`, `focus_window`, `screenshot`.

### Window-qualified selectors

Commands that target widgets support the `window_id#path` syntax:

```gleam
command.focus("main#form/save")
command.scroll_to("settings#list", 0.0)
```

## Platform effects

All functions in `plushie/effect`. Each takes a string tag as its first
argument. Results arrive as `EffectResult` events.

### File dialogs

| Function | Purpose |
|---|---|
| `file_open(tag, opts)` | Single file picker |
| `file_open_multiple(tag, opts)` | Multi-file picker |
| `file_save(tag, opts)` | Save dialog |
| `directory_select(tag, opts)` | Directory picker |

```gleam
#(model, effect.file_open("import", [
  effect.Title("Import"),
  effect.Filters([#("Gleam", "*.gleam")]),
]))
```

### Clipboard

`clipboard_read(tag)`, `clipboard_write(tag, text)`,
`clipboard_read_html(tag)`, `clipboard_write_html(tag, html, alt_text)`,
`clipboard_clear(tag)`, `clipboard_read_primary(tag)` (Linux),
`clipboard_write_primary(tag, text)` (Linux).

The primary clipboard functions target the X11 primary selection in
practice. Treat `clipboard_read_primary(tag)` and
`clipboard_write_primary(tag, text)` as Linux-only operations. On
unsupported platforms, the renderer responds with `EffectUnsupported`.

### Notifications

```gleam
effect.notification("saved", "Exported", "File saved", [])
```

## Async mechanics

One task per tag. Starting a new async with the same tag kills the
previous one. Results are nonce-checked; stale results are silently
discarded.

## See also

- `plushie/command` - full module
- `plushie/effect` - platform effect functions
- [Async and Effects guide](../guides/11-async-and-effects.md)
- [Testing reference](testing.md) - effect stubs
