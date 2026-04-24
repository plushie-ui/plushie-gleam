# Animation and Transitions

Your widgets are styled. Now make them move. Elements that slide,
fade, and spring give the user feedback that the interface is
reacting to their actions.

Plushie's animation system is built around a key insight: the
renderer is closer to the screen than your Gleam code. By
declaring animation *intent* in `view` and letting the renderer
handle interpolation, you get smooth 60fps animation with zero
wire traffic during the animation.

Plushie offers two layers. **Renderer-side descriptors**
(transitions, springs, sequences) encode intent into a prop and
let the renderer interpolate locally. The SDK sends one message
to start and one when it completes. **SDK-side tweens** run in
the app model, driven by `subscription.on_animation_frame`, for
cases where the animating value must live in your state. Prefer
descriptors for anything visual.

## Animating a widget prop

Widgets that support animation expose `<prop>_animated` setters
alongside their typed ones. The animated setter takes a
pre-encoded `PropValue` from `transition.encode`, `spring.encode`,
or `sequence.encode`:

```gleam
import plushie/animation/transition
import plushie/widget/container

container.new("panel")
|> container.max_width_animated(
  transition.new(to: 400.0, duration: 300)
  |> transition.encode(),
)
|> container.build()
```

When the target on the next render differs, the renderer
interrupts the running animation and redirects to the new target.

## Transitions

`plushie/animation/transition`

A transition animates a numeric prop from its current value to a
target over a fixed duration.

```gleam
import plushie/animation/easing.{EaseOut}
import plushie/animation/transition

// Basic fade out over 300 ms.
transition.new(to: 0.0, duration: 300)

// Easing and delay.
transition.new(to: 0.0, duration: 300)
|> transition.easing(EaseOut)
|> transition.delay(100)

// Enter animation: fade in from transparent.
transition.new(to: 1.0, duration: 200)
|> transition.from(0.0)
```

`transition.from` applies only on first appearance, so widgets
that enter the tree later get their own entrance animation while
existing widgets keep their current value.

## Looping

`transition.loop` cycles between two values:

```gleam
// Pulse forever (auto-reverse).
transition.loop(to: 0.4, from: 1.0, duration: 800)
```

`loop` is a shortcut for `new` plus `from` plus
`repeat(Forever)` plus `auto_reverse(True)`. For continuous
forward motion (a spinner rotation), call `repeat` yourself and
leave `auto_reverse` off.

## Springs

`plushie/animation/spring`

Springs use a damped harmonic oscillator instead of a timed
curve. They have no fixed duration; they settle naturally based
on stiffness, damping, and mass. Interruption preserves velocity,
so springs feel responsive when the target changes rapidly (drag,
hover, scroll).

```gleam
import plushie/animation/spring

spring.new(to: 1.05, stiffness: 200.0, damping: 20.0)

spring.gentle(1.0)
spring.bouncy(1.05) |> spring.from(0.0)
spring.snappy(1.0)
```

| Preset | Feel |
|---|---|
| `gentle` | Slow, smooth, no overshoot |
| `snappy` | Quick, minimal overshoot |
| `bouncy` | Quick with visible overshoot |
| `stiff` | Very quick, crisp stop |
| `molasses` | Slow, heavy, deliberate |

## Sequences

`plushie/animation/sequence`

Chain transitions and springs that run one after another on the
same prop. Each step's starting value defaults to the previous
step's final value.

```gleam
import plushie/animation/sequence
import plushie/animation/spring
import plushie/animation/transition

sequence.new()
|> sequence.then_transition(
  transition.new(to: 1.0, duration: 200) |> transition.from(0.0),
)
|> sequence.then_spring(spring.bouncy(0.7))
|> sequence.then_transition(transition.new(to: 0.0, duration: 300))
|> sequence.on_complete("fade_cycle_done")
```

Only the sequence-level `on_complete` tag fires. Step-level tags
inside a sequence are ignored.

## Easing

`plushie/animation/easing`

The `Easing` type covers the standard CSS named curves plus
`CubicBezier(x1, y1, x2, y2)` for custom control points:

```gleam
import plushie/animation/easing.{CubicBezier, EaseOutBack}
import plushie/animation/transition

transition.new(to: 300.0, duration: 400)
|> transition.easing(EaseOutBack)

transition.new(to: 1.0, duration: 400)
|> transition.easing(CubicBezier(0.25, 0.1, 0.25, 1.0))
```

The [animation reference](../reference/animation.md) lists every
named curve.

## Completion events

Any descriptor with `on_complete(tag)` fires
`Widget(TransitionComplete(target, tag, prop))` when the renderer
finishes. Match on the tag in `update`:

```gleam
import plushie/event.{TransitionComplete, Widget}
import plushie/event/types.{EventTarget}

case event {
  Widget(TransitionComplete(
    target: EventTarget(id: "preview", ..),
    tag: "preview_faded_in",
    prop: _,
  )) -> #(Model(..model, preview_ready: True), command.none())
  _ -> #(model, command.none())
}
```

At most one completion event fires per animation start.
Interrupted animations do not fire; only the animation that
replaced them can fire a tag of its own.

## Applying it: animating the pad

The pad has a preview pane that updates on successful compilation
and an error banner that appears at the top on failure. Fade the
preview in and slide the banner down so state transitions feel
tangible instead of jarring.

The preview pane renders a snapshot through an `image` widget.
Fade it with a transition tied to the compile result:

```gleam
import plushie/animation/easing.{EaseOut}
import plushie/animation/transition
import plushie/widget/image

let opacity = case model.compile_status {
  Ok(_) -> 1.0
  Error(_) -> 0.0
}

image.new("preview", model.preview_source)
|> image.opacity_animated(
  transition.new(to: opacity, duration: 250)
  |> transition.easing(EaseOut)
  |> transition.on_complete("preview_faded_in")
  |> transition.encode(),
)
|> image.build()
```

When `compile_status` flips to `Ok`, the renderer interpolates
opacity from 0.0 to 1.0 over 250 ms and fires
`Widget(TransitionComplete)` with tag `"preview_faded_in"` when
the fade finishes, a good place to mark the preview interactive.

Slide the error banner in with a spring. The banner sits inside
a `pin` so it can be positioned absolutely by its `y` coordinate:

```gleam
import plushie/animation/spring
import plushie/widget/pin

let banner_y = case model.compile_error {
  Some(_) -> 0.0
  None -> -40.0
}

pin.new("error_banner")
|> pin.y_animated(
  spring.bouncy(banner_y)
  |> spring.from(-40.0)
  |> spring.encode(),
)
|> pin.build()
```

The banner rests above the visible area (`-40.0`) and springs
down to `0.0` when `compile_error` becomes `Some`. Because the
spring preserves velocity on interruption, rapid error toggles
redirect smoothly instead of snapping.

## SDK-side tweens

`plushie/animation/tween`

Tweens are the escape hatch for values that must live in your
model: a running clock as a progress counter, a physics
simulation feeding canvas coordinates, or a state machine where
every frame might trigger a command.

```gleam
import plushie/animation/easing.{EaseInOutCubic}
import plushie/animation/tween

let anim =
  tween.new(0.0, 1.0, 500, EaseInOutCubic)
  |> tween.start(now_ms)
```

Drive it by subscribing to the animation-frame tick and calling
`advance` in `update`:

```gleam
import gleam/option
import plushie/command
import plushie/event.{AnimationFrame, System}
import plushie/subscription

fn subscribe(model: Model) -> List(subscription.Subscription) {
  case model.anim {
    option.Some(a) if !tween.is_finished(a) ->
      [subscription.on_animation_frame()]
    _ -> []
  }
}

fn update(model: Model, event: event.Event) {
  case event {
    System(AnimationFrame(ts)) -> {
      let anim =
        option.map(model.anim, fn(a) { tween.advance(a, ts) })
      #(Model(..model, anim: anim), command.none())
    }
    _ -> #(model, command.none())
  }
}
```

Drop the subscription when the tween finishes to stop consuming
frames. If the value drives something the renderer can
interpolate on its own, prefer a transition or spring; the tween
path round-trips every frame through the app.

## Verify it

Animations resolve to their target values in mock mode, so tests
assert on the settled state without waiting for frames:

```gleam
import plushie/testing

testing.start(pad.app())
|> testing.click("save")
|> testing.assert_text("preview/greeting", "Hello, Plushie!")
```

## Try it

- Swap the preview fade easing: `Linear`, `EaseOutBack`, or a
  custom `CubicBezier`.
- Replace the banner spring with `spring.snappy` and compare the
  feel during rapid toggles.
- Chain the banner entrance with a short pulse via
  `sequence.then_spring`.

---

Next: [Subscriptions](10-subscriptions.md)
