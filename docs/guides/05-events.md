# Events

Every interaction in a Plushie app produces an event. A button click, a
keystroke in a text input, a checkbox toggle. Each one arrives in your
`update` function as a variant of the `Event` type. Understanding what
events look like and how to match on them is essential for building
anything beyond a static layout.

## Widget events

Most events from user interaction are variants of `plushie/event.Event`.
Here are the common ones:

```gleam
import plushie/event.{
  type Event, WidgetClick, WidgetInput, WidgetToggle,
  WidgetSubmit, WidgetSelect, WidgetSlide,
}

fn update(model: Model, event: Event) -> Model {
  case event {
    // Match by widget ID
    WidgetClick(id: "save", ..) -> save(model)

    // Match with a value
    WidgetInput(id: "search", value: text, ..) ->
      Model(..model, query: text)

    // Match a boolean toggle
    WidgetToggle(id: "dark_mode", value: on, ..) ->
      Model(..model, dark_mode: on)

    // Match a slider
    WidgetSlide(id: "volume", value: level, ..) ->
      Model(..model, volume: level)

    // Catch-all: ignore events you don't care about
    _ -> model
  }
}
```

Always include a catch-all clause at the end of your update function.

## Scope: identifying widgets in lists

When multiple widgets share the same local ID (like a "delete" button in
each row of a list), the `scope` field tells you which container they belong
to. We will use this extensively in [chapter 6](06-lists-and-inputs.md).

```gleam
WidgetClick(id: "delete", scope: [file, ..], ..) ->
  delete_file(model, file)
```

The `scope` list contains ancestor container IDs (nearest parent first)
with the window ID as the last element.

## Other event types

Not all events are widget events. Plushie also delivers:

- `KeyPress`, `KeyRelease` - keyboard events (from subscriptions)
- `TimerTick` - timer ticks (from subscriptions)
- `AsyncResult` - results from background tasks
- `EffectResult` - responses from platform effects (file dialogs, clipboard)
- `WindowOpened`, `WindowClosed`, `WindowResized`, etc. - window lifecycle

Pointer events (mouse, touch, pen) from subscriptions and widgets like
`pointer_area` use the unified pointer event types: `WidgetPress`,
`WidgetRelease`, `WidgetMove`, `WidgetScroll`, `WidgetEnter`,
`WidgetExit`. There are no separate mouse or touch event types. The
`pointer` field in the event data identifies the input device (`:mouse`,
`:touch`, `:pen`).

See the [Events reference](../reference/events.md) for the full taxonomy.

---

Next: [Lists and Inputs](06-lists-and-inputs.md)
