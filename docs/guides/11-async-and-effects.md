# Async and Effects

So far every side effect in the pad has been synchronous. Real apps
need more than that: fetching data from servers, opening native file
dialogs, writing to the clipboard, showing desktop notifications. None
of that is synchronous, and none of it should block the Elm loop.

In this chapter we add async commands for background work, streaming
commands for progress updates, and platform effects for file dialogs,
clipboard, and notifications. By the end the pad has Import, Export,
and Copy buttons in the toolbar and a progress bar driven by a streamed
download.

## Async commands

`command.task` runs a function on a background process and delivers the
return value as an event:

```gleam
import gleam/dynamic
import gleam/erlang/process
import plushie/command

fn fetch_experiments() -> dynamic.Dynamic {
  process.sleep(500)
  dynamic.string("counter, clock, notes, todo")
}

Widget(Click(target: EventTarget(id: "fetch", ..))) -> #(
  Model(..model, status: Loading),
  command.task(fetch_experiments, "fetch"),
)
```

The second argument, `"fetch"`, is a **tag** that identifies this task.
The result arrives as `Async(AsyncEvent(tag, result))` with the same tag:

```gleam
import gleam/dynamic/decode
import plushie/event.{Async, AsyncEvent}

Async(AsyncEvent(tag: "fetch", result: Ok(value))) -> {
  let experiments = case decode.run(value, decode.string) {
    Ok(s) -> s
    Error(_) -> ""
  }
  #(Model(..model, status: Loaded, experiments:), command.none())
}

Async(AsyncEvent(tag: "fetch", result: Error(reason))) -> #(
  Model(..model, status: Failed(string.inspect(reason))),
  command.none(),
)
```

A few things to know about async:

- **One task per tag.** Starting a new task with a tag that is already
  in flight cancels the previous one. This prevents stale results from
  a superseded request.
- **Results are nonce-checked.** If a task is cancelled and its result
  arrives late, the runtime discards it before it reaches `update`.
- **Crashes become errors.** A panic in the work function arrives as
  `Error(reason)` where `reason` is a `Dynamic` describing the failure.
- **Work returns `Dynamic`.** The payload crosses a process boundary,
  so lift typed values with `gleam/dynamic` and decode them back with
  `gleam/dynamic/decode` on arrival.

## Streaming and progress

For long-running work that produces intermediate results, use
`command.stream`. The work function receives an `emit` callback. Each
call delivers a `Stream(StreamEvent(tag, value))` event. The function's
return value becomes the final `Async(AsyncEvent(tag, result))`:

```gleam
import gleam/dynamic
import plushie/command

fn download(emit: fn(dynamic.Dynamic) -> Nil) -> dynamic.Dynamic {
  list.range(0, 10)
  |> list.each(fn(i) {
    process.sleep(100)
    emit(dynamic.int(i * 10))
  })
  dynamic.string("done")
}

// Kick off the stream:
command.stream(download, "download")
```

Handle the intermediate and final events side by side:

```gleam
import plushie/event.{Async, AsyncEvent, Stream, StreamEvent}

Stream(StreamEvent(tag: "download", value:)) -> {
  let progress = case decode.run(value, decode.int) {
    Ok(n) -> n
    Error(_) -> model.progress
  }
  #(Model(..model, progress:), command.none())
}

Async(AsyncEvent(tag: "download", result: Ok(_))) ->
  #(Model(..model, progress: 100, status: Done), command.none())

Async(AsyncEvent(tag: "download", result: Error(_))) ->
  #(Model(..model, status: Failed("download failed")), command.none())
```

Bind `progress` to a `progress_bar` in the view and the bar fills as the
stream emits:

```gleam
import plushie/ui
import plushie/widget/progress_bar

ui.progress_bar("dl", 0.0, 100.0, int.to_float(model.progress), [])
```

## Cancellation

To cancel a running async or stream before it finishes, use
`command.cancel`:

```gleam
#(model, command.cancel("download"))
```

Cancellation is tag-based, not reference-based. There is no task handle
to pass around. Starting a new task with the same tag also cancels the
previous one, which is usually what you want for search-as-you-type and
similar patterns.

## Platform effects

Effects are asynchronous requests to the renderer for native platform
operations: file dialogs, clipboard access, and desktop notifications.
Unlike async commands (which run Gleam code), effects are handled by the
renderer binary and translated into OS-level calls.

All effect functions live in `plushie/effect`. Each takes a string
**tag** as its first argument. The tag identifies the effect in the
result event, so there is no need to store request IDs in your model.

### File dialogs

```gleam
import plushie/effect

#(model, effect.file_open("import", [
  effect.DialogTitle("Import Experiment"),
  effect.Filters([#("Erlang", "*.erl")]),
]))
```

The result arrives as `Effect(EffectEvent(tag, result))`. The `result`
field is an `EffectResult` variant you pattern-match on:

```gleam
import plushie/event.{
  Effect, EffectCancelled, EffectError, EffectEvent, FileOpened,
}

Effect(EffectEvent(tag: "import", result: FileOpened(path))) ->
  load_experiment(model, path)

Effect(EffectEvent(tag: "import", result: EffectCancelled)) ->
  #(model, command.none())

Effect(EffectEvent(tag: "import", result: EffectError(message))) ->
  #(Model(..model, error: message), command.none())
```

`EffectCancelled` is distinct from `EffectError`. A user dismissing a
dialog is expected behaviour, not a failure.

Available file dialogs: `file_open`, `file_open_multiple`, `file_save`,
`directory_select`, `directory_select_multiple`. Each takes a tag and a
`List(FileDialogOpt)`. See the [Commands reference](../reference/commands.md)
for the full list.

### Clipboard

```gleam
// Copy text to the clipboard.
effect.clipboard_write("copy", model.source)

// Read text from the clipboard.
effect.clipboard_read("paste")
```

Write completion arrives as `result: ClipboardWritten`. Reads arrive as
`result: ClipboardText(text)`:

```gleam
import plushie/event.{ClipboardText, ClipboardWritten}

Effect(EffectEvent(tag: "copy", result: ClipboardWritten)) ->
  #(Model(..model, status: "Copied"), command.none())

Effect(EffectEvent(tag: "paste", result: ClipboardText(text))) ->
  #(Model(..model, source: text), command.none())
```

Related: `clipboard_read_html`, `clipboard_write_html`,
`clipboard_clear`. On Linux, `clipboard_read_primary` and
`clipboard_write_primary` access the middle-click selection buffer.

### Notifications

```gleam
effect.notification("saved", "Exported", "File saved to " <> path, [])
```

Options are `NotifIcon(path)`, `NotifTimeout(ms)`,
`Urgency(Low | Normal | Critical)`, and `Sound(theme)`. Completion
arrives as `result: NotificationShown`.

### Default timeouts

Effects have built-in timeouts: 120 seconds for file dialogs (the user
may browse for a while), 5 seconds for clipboard and notifications, and
30 seconds for anything else. If the renderer does not respond in time,
the result is `EffectTimeout`.

## Applying it: Import, Export, Copy

Add three buttons to the pad's toolbar:

```gleam
import plushie/ui
import plushie/widget/row

ui.row("toolbar", [row.Spacing(8.0), row.Padding(padding.xy(8.0, 4.0))], [
  ui.button_("save", "Save"),
  ui.button_("import", "Import"),
  ui.button_("export", "Export"),
  ui.button_("copy", "Copy"),
])
```

Wire the clicks in `update`. Each effect gets a distinct tag so matching
the result is a direct pattern match:

```gleam
Widget(Click(target: EventTarget(id: "import", ..))) -> #(
  model,
  effect.file_open("import", [
    effect.DialogTitle("Import Experiment"),
    effect.Filters([#("Erlang", "*.erl")]),
  ]),
)

Widget(Click(target: EventTarget(id: "export", ..))) -> #(
  model,
  effect.file_save("export", [
    effect.DialogTitle("Export Experiment"),
    effect.Filters([#("Erlang", "*.erl")]),
  ]),
)

Widget(Click(target: EventTarget(id: "copy", ..))) -> #(
  model,
  effect.clipboard_write("copy", model.source),
)
```

Handle the results. The pad reads the file on import, writes the
editor contents on export, and posts a notification after a successful
save:

```gleam
Effect(EffectEvent(tag: "import", result: FileOpened(path))) -> {
  let source = read_source(path)
  #(Model(..model, source:), command.none())
}

Effect(EffectEvent(tag: "export", result: FileSaved(path))) -> {
  write_source(path, model.source)
  #(
    model,
    effect.notification("saved", "Exported", "Saved to " <> path, []),
  )
}

Effect(EffectEvent(tag: tag, result: EffectCancelled))
  if tag == "import" || tag == "export"
-> #(model, command.none())
```

`read_source` and `write_source` are whatever you have on hand for
file I/O (a `simplifile` dependency, a small Erlang FFI wrapper). The
pad just passes the path through.

## Batching

A single `update` clause can return more than one command by wrapping
them in `command.batch`:

```gleam
#(model, command.batch([
  effect.clipboard_write("copy", model.source),
  effect.notification("copied", "Copied", "Source on clipboard", []),
  command.focus("editor"),
]))
```

Commands in a batch execute in list order. `command.none()` inside a
batch is a no-op, which is handy when a branch conditionally contributes
a command.

## Concurrent tags

Tags share a namespace per task kind. Two async tasks with the same tag
cancel each other, but an async task and a stream with the same tag also
cancel each other, and so do two in-flight effects with the same tag.

For concurrent work, use unique tags:

```gleam
command.batch([
  command.task(fetch_users, "fetch-users"),
  command.task(fetch_posts, "fetch-posts"),
])
```

Both tasks run in parallel. Results arrive independently as separate
`Async` events.

## Renderer restart survival

Async tasks run in the host BEAM process, not inside the renderer
binary. When the renderer restarts (for example after a crash), in-flight
tasks keep running and their results arrive as usual. The app's model
is preserved across the restart too.

Effects behave differently. Because effects are serviced by the
renderer, a restart cancels them: the result arrives as
`RendererRestarted`. Treat it like `EffectCancelled` in most cases; the
user can retry once the renderer is back.

## DIY patterns

The runtime is an OTP actor. You can bypass the command system and send
messages to it directly with `plushie.dispatch_event`, or by sending to
the runtime's subject from a linked `gleam/otp` actor:

```gleam
plushie.dispatch_event(runtime, my_event)
```

This is useful for integrating with existing supervision trees. Events
injected this way arrive in the same `update` callback as renderer
events.

The trade-off: you lose tag-based cancellation and the stale-result
rejection that `task` and `stream` provide. For anything more
structured than "deliver this message once," prefer `command.task` with
a tag.

## Try it

Write experiments in the pad to exercise these concepts:

- Build a button that triggers `command.task` with a slow operation
  (`process.sleep(2000)`). Show a loading indicator while it runs, then
  display the result.
- Try `command.stream` to drive a progress bar. Emit values from zero
  to a hundred with a short sleep between each.
- Combine `effect.clipboard_write` with `effect.notification` using
  `command.batch` to give the user immediate visible feedback.
- Wire up `command.cancel("download")` to a Cancel button and watch the
  progress bar stop updating mid-stream.

---

Next: [Canvas](12-canvas.md)
