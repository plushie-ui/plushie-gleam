# Subscriptions

Subscriptions are declarative event sources. Your app returns a
list of subscription specs from its `subscribe` callback and the
runtime starts, stops, and diffs them across update cycles.
Subscriptions are a function of the model: when the model changes,
the active subscriptions change with it.

The `Subscription` type and constructors live in
`plushie/subscription`.

## Timer subscriptions

`subscription.every(interval_ms, tag)` fires on a recurring
interval:

```gleam
import plushie/subscription

fn subscribe(model: Model) -> List(Subscription) {
  case model.auto_save && model.dirty {
    True -> [subscription.every(1000, "auto_save")]
    False -> []
  }
}

// In update:
Timer(TimerEvent(tag: "auto_save", ..)) -> save(model)
```

Timer subscriptions run in the runtime process via Erlang timers.
After each tick, the timer is re-armed for the next interval. The
tag you provide appears in the `TimerEvent` record.

If the interval changes between cycles (e.g. switching from
`every(1000, "tick")` to `every(500, "tick")`), the runtime cancels
the old timer and starts a new one automatically. No manual
cleanup.

## Renderer subscriptions

Renderer subscriptions are forwarded to the renderer binary via
the wire protocol. They take no arguments at the constructor (the
event identity is the variant, not a user tag). Lifecycle is keyed
by `{kind, window_id}`: only one subscription of each kind per
window (or globally when unscoped) is active at a time.

### Keyboard

| Constructor | Event delivered |
|---|---|
| `on_key_press()` | `Key(KeyEvent(event_type: KeyPressed, ...))` |
| `on_key_release()` | `Key(KeyEvent(event_type: KeyReleased, ...))` |
| `on_modifiers_changed()` | `ModifiersChanged(ModifiersEvent(...))` |

`KeyEvent.key` is a `String` (e.g. `"Escape"`, `"Enter"`, `"s"`).
`modifiers` is a `Modifiers` record with `shift`, `ctrl`, `alt`,
`logo`, and `command` boolean fields.

The `command` modifier is platform-aware: Ctrl on Linux / Windows,
Command on macOS. Match on `command: True` for cross-platform
shortcuts.

### Window lifecycle

| Constructor | Event delivered | Scope |
|---|---|---|
| `on_window_event()` | `Window(WindowEvent(...))` | All window events |
| `on_window_open()` | `Window(WindowEvent(event_type: Opened, ...))` | Open only |
| `on_window_close()` | `Window(WindowEvent(event_type: CloseRequested, ...))` | Close only |
| `on_window_resize()` | `Window(WindowEvent(event_type: Resized, ...))` | Resize only |
| `on_window_focus()` | `Window(WindowEvent(event_type: WindowFocused, ...))` | Focus only |
| `on_window_unfocus()` | `Window(WindowEvent(event_type: WindowUnfocused, ...))` | Unfocus only |
| `on_window_move()` | `Window(WindowEvent(event_type: Moved, ...))` | Move only |

`on_window_event` is a superset that delivers every window event
type. **If you subscribe to both `on_window_event` and a specific
variant (e.g. `on_window_resize`), matching events are delivered
twice.** Use one or the other.

### Pointer

| Constructor | Event delivered |
|---|---|
| `on_pointer_move()` | `Widget(Move(..))`, `Widget(Enter(..))`, `Widget(Exit(..))` |
| `on_pointer_button()` | `Widget(Press(..))`, `Widget(Release(..))` |
| `on_pointer_scroll()` | `Widget(Scroll(..))` |
| `on_pointer_touch()` | `Widget(Press(..))`, `Widget(Move(..))`, `Widget(Release(..))` with `pointer: Touch` |

Pointer subscriptions are global. Events arrive as `WidgetEvent`
variants where the `target.id` is the source window's ID and
`target.scope` is empty. For widget-specific pointer handling,
wrap the widget in `ui.pointer_area` instead.

### Other

| Constructor | Event delivered |
|---|---|
| `on_ime()` | `Ime(ImeEvent(...))` |
| `on_theme_change()` | `System(ThemeChanged(theme))` |
| `on_animation_frame()` | `System(AnimationFrame(timestamp))` |
| `on_file_drop()` | `Window(WindowEvent(event_type: FileDropped, ...))` |

`on_animation_frame` delivers vsync ticks for SDK-side animation
via `plushie/animation/tween`. Renderer-side transitions
(`transition`, `spring`, `sequence`) do not need this
subscription; they run independently in the renderer.

### Catch-all

`on_event()` subscribes to **all** renderer events: every widget
event, keyboard event, pointer event, window event, and system
event. Use it for debugging or logging, not as a primary event
source. It delivers a lot of traffic.

## Chaining modifiers

Renderer subscriptions support two chainable modifiers. Both
return a new `Subscription` value:

```gleam
subscription.on_key_press()
subscription.on_pointer_move() |> subscription.set_max_rate(60)
subscription.every(1000, "tick")
```

### Rate limiting

`set_max_rate(sub, rate)` throttles high-frequency renderer
events. The renderer coalesces intermediate events, delivering
only the latest state at each interval.

```gleam
subscription.on_pointer_move() |> subscription.set_max_rate(30)
```

Rate limiting has no effect on timer subscriptions (control the
frequency via the interval argument) and no effect on low-rate
renderer events (key press, window open).

A rate of `0` means "capture but never emit." The subscription is
active (the renderer tracks the state) but no events are delivered.
Useful when you need capture tracking without event processing.

#### Three-level hierarchy

Rate limiting applies at three levels, from most to least specific:

1. **Per-widget** - `EventRate(Int)` opt on individual widgets
   (`pointer_area`, `sensor`, `canvas`, `slider`, `pane_grid`)
2. **Per-subscription** - `subscription.set_max_rate` on a spec
3. **Global** - `default_event_rate` field on
   `app.Settings`

More specific settings override less specific ones. See the
[Configuration reference](configuration.md) for the global
setting.

### Window scoping

Scope a subscription to a specific window in multi-window apps:

```gleam
subscription.on_key_press() |> subscription.set_window("settings")
```

For a batch:

```gleam
subscription.for_window("editor", [
  subscription.on_key_press(),
  subscription.on_pointer_move() |> subscription.set_max_rate(60),
])
```

Without a window scope, events from any window are delivered.
With scoping, only events from the named window arrive.

## Conditional subscriptions

Because `subscribe` is a function of the model, you activate
subscriptions conditionally:

```gleam
fn subscribe(model: Model) -> List(Subscription) {
  let base = [subscription.on_key_press()]

  case model.auto_save && model.dirty {
    True -> [subscription.every(1000, "auto_save"), ..base]
    False -> base
  }
}
```

When `auto_save` becomes false or the dirty flag clears, the
timer disappears from the list and the runtime stops it. When
the conditions are met again, the timer starts. No manual start /
stop logic.

**Performance:** returning the same list every cycle is nearly
free. The runtime generates a sorted key set from the list and
short-circuits if it hasn't changed. Only `max_rate` changes are
checked. When the list does change, add / remove operations are
precise.

## Diffing lifecycle

The runtime calls `subscribe` after every update cycle and diffs
the result against active subscriptions:

1. Compute a key for each spec via `subscription.key`:
   - Timer: `TimerKey(interval_ms, tag)`
   - Renderer: `RendererKey(kind, window_id)`
2. Sort and compare keys against the previous cycle's key set.
3. **Short-circuit**: if the sorted key set is unchanged, only
   check for `max_rate` changes on existing subscriptions.
4. **New keys**: start timers or send subscribe messages to the
   renderer.
5. **Removed keys**: cancel timers or send unsubscribe messages.
6. **Changed `max_rate`**: re-send the subscribe message with
   the new rate.

Subscriptions are idempotent. The same spec list produces no
work. Different lists trigger precise add / remove operations.

## Widget-scoped subscriptions

Custom widgets with a `subscribe` callback get namespaced
subscriptions. Timer tags are automatically wrapped so they never
collide with app-level tags, and the runtime routes matching
events through the widget's `on_event` handler rather than the
app's `update`. The widget sees only its own inner tag.

Multiple instances of the same widget each get independent
subscriptions. See the
[Custom Widgets reference](custom-widgets.md) for the full
mechanism.

## See also

- [Events reference](events.md) - the event shapes delivered by
  subscriptions
- [Configuration reference](configuration.md) - the
  `default_event_rate` setting and related app-wide knobs
- [Custom Widgets reference](custom-widgets.md) - widget-scoped
  subscriptions
- [Commands reference](commands.md) - one-shot timers via
  `command.send_after`
