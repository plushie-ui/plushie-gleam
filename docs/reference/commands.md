# Commands and Effects

Commands are data values returned from `init` and `update`. The
runtime executes them after the update cycle completes. They are
how your app triggers side effects: background work, focus changes,
window operations, platform effects, and more.

The `Command(msg)` type lives in `plushie/command`. Platform
effects (file dialogs, clipboard, notifications) live in
`plushie/effect` and return the same `Command(msg)` value.

## Returning commands

Every `init` and `update` callback returns a `#(model, Command(msg))`
tuple. There is no "bare model" return form; use `command.none()`
when no side effect is needed.

```gleam
import plushie/command

fn update(model: Model, event: Event) {
  case event {
    // No side effect.
    _unhandled -> #(model, command.none())

    // Model + single command.
    Widget(Click(target: EventTarget(id: "save", ..))) ->
      #(model, command.focus("editor"))

    // Model + a batch of commands executed in list order.
    Widget(Click(target: EventTarget(id: "export", ..))) ->
      #(model, command.batch([
        effect.file_save("export", [effect.DialogTitle("Export")]),
        effect.notification("notify", "Exporting", "Saving to file...", []),
      ]))
  }
}
```

`command.batch` takes a list and runs each command in order via the
same dispatch path a single command uses. A command list nested
inside a `batch` is valid; `command.none()` inside a batch is a
no-op.

## Command categories

All functions live in `plushie/command` unless noted otherwise.

### Control flow

| Function | Purpose |
|---|---|
| `none()` | No-op command |
| `batch(commands)` | Execute a list of commands sequentially |
| `dispatch(value, mapper)` | Deliver an already-resolved `Dynamic` through `update` via `mapper`. The mapper runs when the event is processed; do not close over the current model |
| `send_after(delay_ms, msg)` | One-shot delayed message. Sending another `send_after` with an identical `msg` cancels the previous timer (deduplication via stable hashing) |
| `exit()` | Shut down the runtime and close all windows |

`send_after` is a one-shot timer (fires once). For recurring
timers, use `subscription.every` instead; see
[Subscriptions reference](subscriptions.md).

### Async

| Function | Purpose |
|---|---|
| `task(work, tag)` | Run `work` on a background process. Result delivered as `Async(AsyncEvent(tag, result))` |
| `stream(work, tag)` | Run `work(emit)` where each `emit(value)` delivers a `Stream(StreamEvent(tag, value))`. The function's return value becomes the final `Async(AsyncEvent)` result |
| `cancel(tag)` | Kill an in-flight task or stream by tag |

Starting a new `task` or `stream` with a tag already in-flight
cancels the previous task. See [Async mechanics](#async-mechanics)
below for lifecycle details.

### Focus

| Function | Purpose |
|---|---|
| `focus(widget_id)` | Set focus on a widget or canvas element by scoped ID |
| `focus_next()` | Move focus to the next focusable widget |
| `focus_previous()` | Move focus to the previous focusable widget |
| `focus_next_within(scope)` | Move focus to the next focusable widget within a subtree |
| `focus_previous_within(scope)` | Move focus to the previous focusable widget within a subtree |

### Text

| Function | Purpose |
|---|---|
| `select_all(widget_id)` | Select all text in a text input / editor |
| `move_cursor_to_front(widget_id)` | Move cursor to start |
| `move_cursor_to_end(widget_id)` | Move cursor to end |
| `move_cursor_to(widget_id, position)` | Move cursor to a character position |
| `select_range(widget_id, start_pos, end_pos)` | Select a character range |

### Scroll

| Function | Purpose |
|---|---|
| `scroll_to(widget_id, x, y)` | Scroll to absolute position |
| `snap_to(widget_id, x, y)` | Snap scroll to a position (instant) |
| `snap_to_end(widget_id)` | Snap scroll to the end |
| `scroll_by(widget_id, x, y)` | Scroll by a relative offset |

### Window operations

| Function | Purpose |
|---|---|
| `close_window(window_id)` | Close a window |
| `resize_window(window_id, width, height)` | Set window size |
| `move_window(window_id, x, y)` | Set window position |
| `maximize_window(window_id)` | Maximize the window |
| `minimize_window(window_id)` | Minimize the window |
| `set_window_mode(window_id, mode)` | Set `"windowed"`, `"fullscreen"`, or `"hidden"` |
| `toggle_maximize(window_id)` | Toggle maximized state |
| `toggle_decorations(window_id)` | Toggle window decorations |
| `focus_window(window_id)` | Bring window to front |
| `set_window_level(window_id, level)` | Set `"normal"`, `"always_on_top"`, `"always_on_bottom"` |
| `drag_window(window_id)` | Begin window drag |
| `drag_resize_window(window_id, direction)` | Begin drag-resize from an edge / corner |
| `request_attention(window_id, urgency)` | Flash the taskbar / dock icon |
| `screenshot(window_id, tag)` | Capture a window screenshot |
| `set_resizable(window_id, resizable)` | Allow / deny user resize |
| `set_min_size(window_id, width, height)` | Minimum window size |
| `set_max_size(window_id, width, height)` | Maximum window size |
| `set_resize_increments(window_id, width, height)` | Snap resize to a grid |
| `enable_mouse_passthrough(window_id)` | Pass clicks through to windows below |
| `disable_mouse_passthrough(window_id)` | Restore normal click handling |
| `show_system_menu(window_id)` | Show the native window controls menu |
| `set_icon(window_id, rgba, width, height)` | Set window icon from RGBA pixels |

Screenshot results arrive as `System(ScreenshotData(tag, hash, width, height, pixels))`
where `pixels` is a `BitArray` of raw RGBA bytes.

### Window queries

| Function | Purpose |
|---|---|
| `window_size(window_id, tag)` | Query window dimensions |
| `window_position(window_id, tag)` | Query window position |
| `is_maximized(window_id, tag)` | Query maximized state |
| `is_minimized(window_id, tag)` | Query minimized state |
| `window_mode(window_id, tag)` | Query fullscreen / windowed mode |
| `scale_factor(window_id, tag)` | Query DPI scale factor |
| `raw_window_id(window_id, tag)` | Query the platform window handle |
| `monitor_size(window_id, tag)` | Query monitor dimensions for the display hosting the window |

Results arrive as `System(SystemInfo(tag, value))`. The `tag`
matches the string you provided; `value` is a `Dynamic` payload you
decode with `gleam/dynamic` decoders at the call site.

### System

| Function | Purpose |
|---|---|
| `system_theme(tag)` | Query OS light / dark preference |
| `system_info(tag)` | Query system info (OS, CPU, memory, graphics) |
| `allow_automatic_tabbing(enabled)` | macOS automatic tab management |
| `announce(text)` | Screen reader announcement (polite) |
| `announce_with(text, politeness)` | Announce with explicit politeness (`Polite` or `Assertive`) |
| `announce_assertive(text)` | Shortcut for `announce_with(text, Assertive)` |

`announce` triggers a live-region assertion for assistive
technology. The text is immediately spoken by the screen reader
without requiring a visible widget. `Polite` is correct for most
toast-style feedback; reserve `Assertive` for urgent context that
must interrupt whatever the user is currently hearing.

### Images

| Function | Purpose |
|---|---|
| `create_image(handle, data)` | Register an image from encoded bytes (PNG, JPEG, ...) |
| `create_image_rgba(handle, width, height, pixels)` | Register from raw RGBA |
| `update_image(handle, data)` | Update an existing handle with encoded bytes |
| `update_image_rgba(handle, width, height, pixels)` | Update an existing handle with raw RGBA |
| `delete_image(handle)` | Delete a registered image |
| `clear_images()` | Delete all registered images |
| `list_images(tag)` | List registered handles; result arrives as `System(ImageList(tag, handles))` |

See the [Built-in Widgets reference](built-in-widgets.md#display)
`image` entry for how handles are referenced in views.

### Other

| Function | Purpose |
|---|---|
| `load_font(family, data)` | Load a font at runtime from TrueType / OpenType binary |
| `tree_hash(tag)` | Query a SHA-256 hash of the renderer's current tree |
| `find_focused(tag)` | Query which widget currently has focus |
| `advance_frame(timestamp)` | Manually tick the renderer (test / headless mode) |
| `native_command(node_id, op, payload)` | Send a typed command to a native widget, bypassing the tree diff cycle |
| `widget_batch(commands)` | Send a batch of native widget commands processed atomically |
| `pane_split(pane_grid_id, pane_id, axis, new_pane_id)` | Split a pane in a pane grid |
| `pane_close(pane_grid_id, pane_id)` | Close a pane |
| `pane_swap(pane_grid_id, pane_a, pane_b)` | Swap two panes |
| `pane_maximize(pane_grid_id, pane_id)` | Maximize one pane |
| `pane_restore(pane_grid_id)` | Restore all panes from maximized state |

## Platform effects

All functions live in `plushie/effect`. Each takes a `String`
**tag** as its first argument and returns a `Command(msg)`. Results
arrive as `Effect(EffectEvent(tag, result))`, where `result` is an
`EffectResult` variant (see the [Events reference](events.md)).

### File dialogs

| Function | Purpose |
|---|---|
| `file_open(tag, opts)` | Single file picker |
| `file_open_multiple(tag, opts)` | Multi-file picker |
| `file_save(tag, opts)` | Save dialog |
| `directory_select(tag, opts)` | Single directory picker |
| `directory_select_multiple(tag, opts)` | Multi-directory picker |

`FileDialogOpt` variants: `DialogTitle(String)`, `DefaultPath(String)`,
`Filters(List(#(String, String)))` where each filter tuple is
`#(label, pattern)` (e.g. `#("Gleam", "*.gleam")`).

```gleam
import plushie/effect

#(model, effect.file_open("import", [
  effect.DialogTitle("Import"),
  effect.Filters([#("Gleam", "*.gleam")]),
]))

// In update:
Effect(EffectEvent(tag: "import", result: FileOpened(path))) ->
  load_file(model, path)
Effect(EffectEvent(tag: "import", result: EffectCancelled)) ->
  #(model, command.none())
```

### Clipboard

| Function | Purpose |
|---|---|
| `clipboard_read(tag)` | Read plain text |
| `clipboard_write(tag, text)` | Write plain text |
| `clipboard_read_html(tag)` | Read HTML content |
| `clipboard_write_html(tag, html, alt)` | Write HTML with optional plain-text fallback |
| `clipboard_clear(tag)` | Clear the clipboard |
| `clipboard_read_primary(tag)` | Read the primary selection (X11) |
| `clipboard_write_primary(tag, text)` | Write the primary selection (X11) |

### Notifications

```gleam
effect.notification("saved", "Exported", "File saved to " <> path, [])
```

`NotificationOpt` variants: `NotifIcon(String)` (icon path),
`NotifTimeout(Int)` (auto-dismiss ms), `Urgency(NotifUrgency)`
(`Low`, `Normal`, `Critical`), `Sound(String)` (sound theme name,
e.g. `"message-new-instant"`).

## Async mechanics

- **One task per tag.** Calling `command.task` or `command.stream`
  with a tag that is already in-flight cancels the previous task.
  Use unique tags for concurrent work.

- **Nonce-based stale rejection.** Each task gets a monotonic
  nonce at creation. Results from cancelled tasks carry a stale
  nonce and are silently discarded by the runtime before reaching
  `update`.

- **Crashes become errors.** If the task process crashes, the
  result is delivered as `Error(reason)` where `reason` is a
  `Dynamic` payload describing the failure.

- **Renderer restarts.** In-flight async tasks run in the host
  process, not the renderer, so they survive a renderer restart.
  Results may be semantically stale if the work depended on
  renderer state.

### Streaming

```gleam
command.stream(
  fn(emit) {
    list.each(fetch_chunks(), fn(chunk) {
      emit(dynamic.from(#(chunk.index, chunk.data)))
    })
    dynamic.from("done")
  },
  "import",
)
```

Each `emit(value)` delivers `Stream(StreamEvent(tag: "import",
value: ...))`. The function's return value becomes
`Async(AsyncEvent(tag: "import", result: Ok(...)))`. If the stream
function raises, the final event is `Async(AsyncEvent(tag, result:
Error(...)))`.

## Effect lifecycle

- **Tag-based matching.** Every effect takes a string tag. The tag
  appears in `EffectEvent.tag` for direct pattern matching.

- **One effect per tag.** Starting a new effect with a tag that
  has a pending request discards the previous one.

- **Default timeouts.** File dialogs 120 s, clipboard and
  notification 5 s, unknown kinds 30 s. See
  `effect.default_timeout(kind)` for the exact values.

- **Timeout delivery.** `result: EffectTimeout`.

- **Cancellation.** When the user dismisses a dialog, the result
  is `EffectCancelled`, not an error.

- **Effect stubs.** `testing.register_effect_stub("file_open", ...)`
  intercepts effects by kind in tests. See the
  [Testing reference](testing.md).

## DIY patterns

The runtime is an OTP actor. You can bypass the command system and
send messages to it directly using `plushie.dispatch_event` or
`process.send` to the runtime's subject.

This is useful for integrating with existing supervision trees -
hooking in a `gleam/otp` actor, a `gleam_erlang` subscription, or
native Erlang processes. Events injected this way arrive in the
same `update` callback as renderer events.

The trade-off: you lose tag-based cancellation and the stale-result
rejection that `task` / `stream` provide. For anything more
structured than "deliver this message once," prefer
`command.task` with a tag.

## See also

- [Subscriptions reference](subscriptions.md) - recurring timers,
  keyboard, mouse, window, and custom subscriptions
- [Events reference](events.md) - the `AsyncEvent`,
  `StreamEvent`, `EffectEvent`, and `SystemEvent` shapes returned
  by commands
- [App Lifecycle reference](app-lifecycle.md) - init / update /
  view semantics and the command dispatch loop
- [Testing reference](testing.md) - effect stubs and command
  processing under the test harness
