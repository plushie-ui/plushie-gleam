# Subscriptions

So far every event in the pad has come from direct widget interaction: a
button click, a text input keystroke. But some events come from outside the
widget tree: keyboard shortcuts, timers, window events, pointer movement.
These are delivered through **subscriptions**.

## What are subscriptions?

Subscriptions are declarative event sources. You add an optional `subscribe`
callback to your app that receives the current model and returns a list of
subscription specs:

```gleam
import plushie/subscription.{type Subscription}

fn subscribe(model: Model) -> List(Subscription) {
  [subscription.on_key_press()]
}
```

Wire the callback in when you build the `App`:

```gleam
pub fn app() -> App(Model, Event) {
  app.simple(init, update, view)
  |> app.with_subscribe(subscribe)
}
```

The runtime calls `subscribe` after every update cycle and diffs the
returned list against the active subscriptions. New specs start new event
sources, removed specs stop them. You never start or stop subscriptions
manually. You describe what you want, and the runtime manages the
lifecycle.

This is the same declarative approach as `view`: the list is a function of
the model. When the model changes, the active subscriptions change with it.

## Keyboard subscriptions

`subscription.on_key_press()` subscribes to keyboard events. It delivers
`Key(KeyEvent(...))` values to `update`:

```gleam
import plushie/event.{Key, KeyEvent, KeyPressed}
import plushie/subscription

fn subscribe(_model: Model) -> List(Subscription) {
  [subscription.on_key_press()]
}

fn update(model: Model, evt: Event) -> #(Model, Command(Event)) {
  case evt {
    Key(KeyEvent(event_type: KeyPressed, key: "s", modifiers: m, ..))
      if m.command -> #(save(model), command.none())

    Key(KeyEvent(event_type: KeyPressed, key: "Escape", ..)) -> #(
      Model(..model, error: None),
      command.none(),
    )

    _ -> #(model, command.none())
  }
}
```

The `KeyEvent` record carries:

- `event_type`: `KeyPressed` or `KeyReleased`.
- `key`: the logical key as a `String`. Named keys use labels like
  `"Escape"`, `"Enter"`, `"Tab"`, `"ArrowUp"`. Characters are single-letter
  strings like `"s"` or `"1"`.
- `modifiers`: a `Modifiers` record with `shift`, `ctrl`, `alt`, `logo`, and
  `command` boolean fields.

The `command` field is platform-aware: `True` when Ctrl is held on Linux or
Windows, and when Cmd is held on macOS. Matching on `m.command` gives you
cross-platform shortcuts with no platform checks.

Use `subscription.on_key_release()` if you need key-up events.

`subscription.on_modifiers_changed()` tracks modifier state changes without
a regular key press. It delivers `ModifiersChanged(ModifiersEvent(...))`:

```gleam
import plushie/event.{ModifiersChanged, ModifiersEvent}

fn subscribe(_model: Model) -> List(Subscription) {
  [
    subscription.on_key_press(),
    subscription.on_modifiers_changed(),
  ]
}

// In update:
ModifiersChanged(ModifiersEvent(modifiers: m, ..)) if m.shift ->
  #(Model(..model, shift_held: True), command.none())
```

Useful for UI that changes appearance based on held modifiers (e.g.,
showing alternate labels when Shift is held).

### Applying it: pad keyboard shortcuts

The pad already uses Ctrl+S, Ctrl+Z, Ctrl+Shift+Z, and Escape. The
subscription is a single `on_key_press` and the `update` branches match
each shortcut by key and modifier:

```gleam
fn subscribe(_model: Model) -> List(Subscription) {
  [subscription.on_key_press()]
}

// In update, after the widget-event branches:

// Ctrl+Z for undo.
Key(KeyEvent(event_type: KeyPressed, key: "z", modifiers: m, ..))
  if m.command && !m.shift
-> #(do_undo(model), command.none())

// Ctrl+Shift+Z for redo.
Key(KeyEvent(event_type: KeyPressed, key: "z", modifiers: m, ..))
  if m.command && m.shift
-> #(do_redo(model), command.none())

// Ctrl+S for save.
Key(KeyEvent(event_type: KeyPressed, key: "s", modifiers: m, ..))
  if m.command
-> #(save_and_render(model), command.none())

// Escape clears the error banner.
Key(KeyEvent(event_type: KeyPressed, key: "Escape", ..)) -> #(
  Model(..model, error: None),
  command.none(),
)
```

Order matters. Ctrl+Shift+Z must be matched before plain Ctrl+Z, or the
shift modifier would be ignored. Each branch uses a pattern guard on
`modifiers` to express the shortcut combination.

## Timer subscriptions

`subscription.every(interval_ms, tag)` fires on a recurring interval:

```gleam
subscription.every(1000, "tick")
```

This delivers a `Timer(TimerEvent(...))` every 1000 milliseconds:

```gleam
import plushie/event.{Timer, TimerEvent}

case evt {
  Timer(TimerEvent(tag: "tick", ..)) ->
    #(Model(..model, ticks: model.ticks + 1), command.none())
  _ -> #(model, command.none())
}
```

The `tag` on `TimerEvent` matches the tag you gave the subscription. Use it
to tell timers apart when multiple are active. Renderer subscriptions like
`on_key_press` take no tag because their identity is the variant itself.
Timer subscriptions are different: the tag is part of the subscription's
identity and is required.

### Conditional subscriptions

Because `subscribe` is a function of the model, you activate subscriptions
conditionally:

```gleam
fn subscribe(model: Model) -> List(Subscription) {
  let base = [subscription.on_key_press()]

  case model.auto_save && model.dirty {
    True -> [subscription.every(1000, "auto_save"), ..base]
    False -> base
  }
}
```

When `auto_save` is false or the content has not changed, the timer is not
in the list, so the runtime stops it. When the conditions are met, the
timer starts. No manual start / stop logic.

### Applying it: wire up auto-save

In an earlier chapter we added the auto-save checkbox but did not wire it
up. Now we can. We need a `dirty` flag that tracks whether the source has
changed since the last save.

In `update`, flip `dirty` on every editor change:

```gleam
Widget(Input(target: EventTarget(id: "editor", ..), value: s)) -> {
  let next_undo = undo.push_with_coalesce(model.undo_stack, s, "typing", 500)
  #(
    Model(..model, source: s, dirty: True, undo_stack: next_undo),
    command.none(),
  )
}
```

In `subscribe`, turn on the auto-save timer only when auto-save is enabled
and the content is dirty:

```gleam
fn subscribe(model: Model) -> List(Subscription) {
  let base = [subscription.on_key_press()]
  case model.auto_save && model.dirty {
    True -> [subscription.every(1000, "auto_save"), ..base]
    False -> base
  }
}
```

Handle the timer by saving and clearing the dirty flag:

```gleam
Timer(TimerEvent(tag: "auto_save", ..)) -> #(
  save_and_render(model),
  command.none(),
)
```

`save_and_render` already returns a model with `dirty: False`. Once the
flag is cleared, the subscription disappears from the list and the timer
stops, until the next edit.

## Other subscriptions

Plushie provides subscriptions for event sources beyond keyboard and
timers:

- **Pointer**: `on_pointer_move`, `on_pointer_button`, `on_pointer_scroll`,
  `on_pointer_touch`. These deliver pointer `WidgetEvent` variants
  (`Press`, `Release`, `Move`, `Scroll`) where the `target.id` is the
  source window's ID and `target.scope` is empty. For widget-specific
  pointer handling, wrap the widget in `ui.pointer_area` instead.
- **Window lifecycle**: `on_window_open`, `on_window_close`,
  `on_window_resize`, `on_window_focus`, `on_window_unfocus`,
  `on_window_move`, and `on_window_event` (a superset that delivers every
  window event type). Subscribing to both the superset and a specific
  variant delivers matching events twice, so pick one.
- **IME**: `on_ime` for input method editor events.
- **System**: `on_theme_change`, `on_animation_frame`, `on_file_drop`.
  Renderer-side transitions run independently and do not require
  `on_animation_frame` or a timer subscription.
- **Catch-all**: `on_event` for any renderer event. Useful for debugging
  or logging, not a primary event source; it delivers a lot of traffic.

See the [Subscriptions reference](../reference/subscriptions.md) for the
full catalog and the event shapes each constructor delivers.

## Rate limiting

High-frequency events like pointer movement can call `update` hundreds of
times per second when you only need the position at 30fps. This is
especially wasteful over networked connections where each update generates
wire traffic. `subscription.set_max_rate` throttles delivery:

```gleam
subscription.on_pointer_move() |> subscription.set_max_rate(30)
```

This caps delivery to 30 events per second. The renderer coalesces
intermediate events, delivering only the latest state at each interval.

Rate limiting applies at three levels, from most to least specific:

1. **Per-widget**: `EventRate` opt on individual widgets (`pointer_area`,
   `sensor`, `canvas`, `slider`, `pane_grid`).
2. **Per-subscription**: `set_max_rate` on a subscription spec.
3. **Global**: `default_event_rate` field on `app.Settings`.

More specific settings override less specific ones. See the
[Subscriptions reference](../reference/subscriptions.md) for details.

## Window-scoped subscriptions

In multi-window apps, scope subscriptions to a specific window with
`subscription.set_window` or batch them with `subscription.for_window`:

```gleam
subscription.for_window("settings", [
  subscription.on_key_press(),
  subscription.on_pointer_move() |> subscription.set_max_rate(60),
])
```

This delivers key and pointer events only from the `"settings"` window.
Without a scope, events from any window arrive.

## Try it

Write a subscription experiment in your pad:

- Build a clock: subscribe to `subscription.every(1000, "tick")` and
  display the current time. Watch the display update every second.
- Subscribe to `subscription.on_key_press()` and log key names into a list.
  Press modifier keys and see how `modifiers` changes.
- Try a conditional subscription: subscribe to a timer only when a checkbox
  is checked. Toggle the checkbox and observe the timer starting and
  stopping.

In the next chapter we will add file dialogs, clipboard integration, and
async work to the pad.

---

Next: [Async and Effects](11-async-and-effects.md)
