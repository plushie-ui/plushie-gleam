# Subscriptions

Subscriptions are declarative event sources. You implement the optional
`subscribe` callback, which receives the current model and returns a list
of subscription specs:

```gleam
import plushie/subscription

fn subscribe(model: Model) -> List(subscription.Subscription) {
  [subscription.on_key_press("keys")]
}
```

The runtime calls `subscribe` after every update cycle and diffs the
returned list against the active subscriptions.

## Keyboard subscriptions

```gleam
import plushie/event.{KeyPress}

fn update(model: Model, event: Event) -> Model {
  case event {
    KeyPress(key: "s", modifiers: modifiers, ..) if modifiers.command ->
      save(model)
    KeyPress(key: "Escape", ..) ->
      Model(..model, error: option.None)
    _ -> model
  }
}
```

The `command` modifier is platform-aware: Ctrl on Linux/Windows, Cmd on
macOS.

## Timer subscriptions

```gleam
subscription.every(1000, "tick")
```

Delivers a `TimerTick` event every 1000 milliseconds:

```gleam
TimerTick(tag: "tick", ..) -> Model(..model, time: now())
```

## Pointer subscriptions

- `on_pointer_move("mouse")` - cursor movement
- `on_pointer_button("buttons")` - button press/release
- `on_pointer_scroll("scroll")` - scroll wheel
- `on_pointer_touch("touch")` - touchscreen

These deliver `WidgetPress`, `WidgetRelease`, `WidgetMove`, and
`WidgetScroll` events with `pointer` (Mouse or Touch) and `modifiers`
in the data.

## Conditional subscriptions

Because `subscribe` is a function of the model, you can activate
subscriptions conditionally:

```gleam
fn subscribe(model: Model) -> List(subscription.Subscription) {
  let subs = [subscription.on_key_press("keys")]

  case model.auto_save && model.dirty {
    True -> [subscription.every(1000, "auto_save"), ..subs]
    False -> subs
  }
}
```

## Rate limiting

```gleam
subscription.on_pointer_move("mouse")
|> subscription.max_rate(30)
```

This caps delivery to 30 events per second. See the
[Subscriptions reference](../reference/subscriptions.md) for details.

---

Next: [Async and Effects](11-async-and-effects.md)
