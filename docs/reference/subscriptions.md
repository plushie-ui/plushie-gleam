# Subscriptions

Subscriptions are declarative event sources. Return a list of specs from
your `subscribe` callback; the runtime manages starting and stopping.

See `plushie/subscription` for the full module API.

## Timer subscriptions

```gleam
subscription.every(1000, "auto_save")
```

Timer events carry the tag in the `TimerTick` event.

## Renderer subscriptions

### Keyboard

| Function | Event delivered |
|---|---|
| `on_key_press(tag)` | `KeyPress` |
| `on_key_release(tag)` | `KeyRelease` |
| `on_modifiers_changed(tag)` | `ModifiersChanged` |

### Pointer

| Function | Event delivered |
|---|---|
| `on_pointer_move(tag)` | `WidgetMove`, `WidgetEnter`, `WidgetExit` |
| `on_pointer_button(tag)` | `WidgetPress`, `WidgetRelease` |
| `on_pointer_scroll(tag)` | `WidgetScroll` |
| `on_pointer_touch(tag)` | `WidgetPress`, `WidgetMove`, `WidgetRelease` |

Pointer subscriptions are global. They deliver events with `id` set to
the window ID and `scope` set to `[]`. The data includes `pointer`
(Mouse or Touch) and `modifiers`.

### Window lifecycle

`on_window_event`, `on_window_open`, `on_window_close`,
`on_window_resize`, `on_window_focus`, `on_window_unfocus`,
`on_window_move`.

### Other

`on_ime`, `on_theme_change`, `on_animation_frame`, `on_file_drop`,
`on_event` (catch-all).

## Rate limiting

```gleam
subscription.on_pointer_move()
|> subscription.max_rate(30)
```

Or inline:

```gleam
subscription.on_pointer_move_with("mouse", [subscription.MaxRate(30)])
```

### Three-level hierarchy

1. **Per-widget** - `EventRate` prop on individual widgets
2. **Per-subscription** - `max_rate` on subscription specs
3. **Global** - `DefaultEventRate` in settings

## Window scoping

```gleam
subscription.for_window("settings", [
  subscription.on_key_press(),
])
```

## Conditional subscriptions

```gleam
fn subscribe(model: Model) {
  let subs = [subscription.on_key_press()]

  case model.auto_save && model.dirty {
    True -> [subscription.every(1000, "auto_save"), ..subs]
    False -> subs
  }
}
```

## See also

- `plushie/subscription` - module docs
- [Subscriptions guide](../guides/10-subscriptions.md)
- [Events](events.md)
- [Configuration](configuration.md)
