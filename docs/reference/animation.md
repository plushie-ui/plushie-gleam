# Animation

Plushie supports two layers of animation. **Renderer-side
descriptors** (transitions, springs, sequences) declare animation
intent on a prop and let the renderer interpolate locally; the
SDK sends one wire message to start the animation and one when it
completes. **SDK-side tweens** run in the app model, driven by
`subscription.on_animation_frame`, and are useful when your model
needs frame-by-frame control.

Prefer renderer-side descriptors for anything visual. Reach for
tweens only when the animating value must live in your model.

## Animating a widget prop

Widgets that support animation expose `<prop>_animated` setters
alongside their normal typed setters. Pass a pre-encoded descriptor
from `transition.encode`, `spring.encode`, or `sequence.encode`:

```gleam
import plushie/animation/transition
import plushie/widget/button

button.new("save", "Save")
|> button.width_animated(
  transition.new(to: 200.0, duration: 300)
  |> transition.encode(),
)
|> button.build()
```

Under the hood, the `_animated` setter writes a `PropValue` (the
encoded descriptor) directly into the node's animated props map.
The renderer sees the descriptor on the wire, starts the
animation, and interpolates the prop's value locally without
further traffic. On completion, if the descriptor sets an
`on_complete` tag, the renderer emits
`Widget(TransitionComplete(target, tag, prop))`.

## Transition

`plushie/animation/transition`

Time-based animation toward a target value.

```gleam
import plushie/animation/easing.{EaseOut}
import plushie/animation/transition

// Basic fade out over 300 ms:
transition.new(to: 0.0, duration: 300)

// With easing and delay:
transition.new(to: 0.0, duration: 300)
|> transition.easing(EaseOut)
|> transition.delay(100)

// Fade in from transparent:
transition.new(to: 1.0, duration: 200)
|> transition.from(0.0)

// Infinite bouncing pulse between 1.0 and 0.4:
transition.loop(to: 0.4, from: 1.0, duration: 800)
```

### Constructors

| Function | Purpose |
|---|---|
| `transition.new(to:, duration:)` | Target value and duration in milliseconds |
| `transition.loop(to:, from:, duration:)` | Shortcut for `new` + `from` + `repeat(Forever)` + `auto_reverse(True)` |

### Modifiers

| Function | Purpose |
|---|---|
| `transition.easing(t, Easing)` | Set the easing curve (default `EaseInOut`) |
| `transition.delay(t, Int)` | Milliseconds to wait before starting |
| `transition.from(t, Float)` | Explicit starting value (defaults to the prop's current value) |
| `transition.repeat(t, Repeat)` | `Times(n)` or `Forever` |
| `transition.auto_reverse(t, Bool)` | Play in reverse on alternate cycles |
| `transition.on_complete(t, String)` | Emit `Widget(TransitionComplete)` with this tag when the animation finishes |

`Repeat` variants: `Times(Int)`, `Forever`.

`transition.encode(t)` produces the wire-ready `PropValue`
consumed by `_animated` setters.

## Spring

`plushie/animation/spring`

Physics-based animation using a damped harmonic oscillator.
Springs have no fixed duration; they settle naturally based on
stiffness, damping, mass, and initial velocity. Because
interruption preserves velocity, springs are the right choice
for interactive values whose target changes frequently (drag,
scroll, hover).

```gleam
import plushie/animation/spring

// Explicit stiffness and damping:
spring.new(to: 1.05, stiffness: 200.0, damping: 20.0)

// Named presets:
spring.gentle(1.0)
spring.bouncy(1.05) |> spring.from(0.0)
spring.stiff(1.0)
spring.snappy(1.0)
spring.molasses(1.0)
```

### Presets

| Preset | Stiffness | Damping | Character |
|---|---|---|---|
| `gentle(to)` | 120 | 14 | Slow, smooth, no overshoot |
| `bouncy(to)` | 300 | 10 | Quick with visible overshoot |
| `stiff(to)` | 400 | 30 | Very quick, crisp stop |
| `snappy(to)` | 200 | 20 | Quick, minimal overshoot |
| `molasses(to)` | 60 | 12 | Slow, heavy, deliberate |

### Modifiers

| Function | Purpose |
|---|---|
| `spring.mass(s, Float)` | Override mass (default 1.0) |
| `spring.velocity(s, Float)` | Initial velocity |
| `spring.from(s, Float)` | Explicit starting value |
| `spring.on_complete(s, String)` | Emit `Widget(TransitionComplete)` when the spring settles |

`spring.encode(s)` produces the wire-ready `PropValue`.

## Sequence

`plushie/animation/sequence`

Chains multiple transitions and springs that run one after the
other on the same prop. Each step's starting value defaults to
the previous step's final value.

```gleam
import plushie/animation/sequence
import plushie/animation/spring
import plushie/animation/transition

// Fade in, pulse, fade out:
sequence.new()
|> sequence.then_transition(
  transition.new(to: 1.0, duration: 200) |> transition.from(0.0),
)
|> sequence.then_spring(spring.bouncy(0.7))
|> sequence.then_transition(transition.new(to: 0.0, duration: 300))
|> sequence.on_complete("fade_cycle_done")
```

### Modifiers

| Function | Purpose |
|---|---|
| `sequence.then_transition(seq, Transition)` | Append a transition step |
| `sequence.then_spring(seq, Spring)` | Append a spring step |
| `sequence.on_complete(seq, String)` | Tag fired when the whole sequence finishes |

Only the sequence-level `on_complete` fires; individual step
completion tags inside a sequence are ignored.

`sequence.encode(s)` produces the wire-ready `PropValue`.

## Easing

`plushie/animation/easing`

The `Easing` type covers every standard CSS easing curve plus a
`CubicBezier(x1, y1, x2, y2)` variant for custom control points.

### Named curves

| Variant | Wire name |
|---|---|
| `Linear` | `linear` |
| `EaseIn`, `EaseOut`, `EaseInOut` | `ease_in`, `ease_out`, `ease_in_out` (sine-based aliases) |
| `EaseInQuad`, `EaseOutQuad`, `EaseInOutQuad` | quadratic |
| `EaseInCubic`, `EaseOutCubic`, `EaseInOutCubic` | cubic |
| `EaseInQuart`, `EaseOutQuart`, `EaseInOutQuart` | quartic |
| `EaseInQuint`, `EaseOutQuint`, `EaseInOutQuint` | quintic |
| `EaseInSine`, `EaseOutSine`, `EaseInOutSine` | sine |
| `EaseInExpo`, `EaseOutExpo`, `EaseInOutExpo` | exponential |
| `EaseInCirc`, `EaseOutCirc`, `EaseInOutCirc` | circular |
| `EaseInBack`, `EaseOutBack`, `EaseInOutBack` | back (overshoot) |
| `EaseInElastic`, `EaseOutElastic`, `EaseInOutElastic` | elastic |
| `EaseInBounce`, `EaseOutBounce`, `EaseInOutBounce` | bounce |

### Custom cubic bezier

```gleam
import plushie/animation/easing.{CubicBezier}

transition.new(to: 1.0, duration: 400)
|> transition.easing(CubicBezier(0.25, 0.1, 0.25, 1.0))
```

Control points match the CSS `cubic-bezier()` convention. `x1`
and `x2` must lie in `[0.0, 1.0]`; `easing.valid(c)` returns
`False` for out-of-range X values. `easing.apply(c, t)` evaluates
the curve at `t in [0.0, 1.0]` for SDK-side tweens that need to
inspect interpolation values directly.

`easing.encode(easing)` produces the wire-ready `PropValue`:
named variants encode as a `StringVal`; `CubicBezier` encodes as a
tagged dict.

## Animatable props

Not every prop animates. A widget exposes an `_animated` setter
only for props whose values can be interpolated by the renderer.
Common animatable props include width, height, opacity, rotation,
translate_x / translate_y, scale, border_radius, and
font size. Consult each widget's module in `plushie/widget/*`
for its exact set; the function naming is consistent
(`button.width_animated`, `image.opacity_animated`, etc.).

When a prop carries an animation descriptor, setting the same
prop on the next render replaces the active animation. The
renderer interrupts cleanly:

- A **transition** snapshots its current value and restarts from
  there toward the new target.
- A **spring** carries its current velocity into the new spring,
  preserving momentum. This is why springs feel responsive under
  rapid input.

Remove the animation by writing the prop with its non-animated
setter on a subsequent render. The renderer jumps to the
non-animated value.

## Completion events

Any descriptor with `on_complete(tag)` set emits
`Widget(TransitionComplete(target, tag, prop))` when the renderer
finishes interpolation. Match on the tag in `update` to trigger
follow-up logic:

```gleam
case event {
  Widget(TransitionComplete(
    target: EventTarget(id: "modal", ..),
    tag: "fade_in_done",
    prop: _,
  )) -> Model(..model, modal_ready: True)
  _ -> model
}
```

The renderer guarantees at most one completion event per
animation start. Interrupted animations do not fire completion;
only the animation that replaced them can fire (if it too has an
`on_complete`).

## SDK-side tweens

`plushie/animation/tween`

Frame-based interpolation that lives in your model rather than
the renderer. Use when the animating value drives logic the
renderer can't reach, or when you need fine-grained control over
individual frames.

### Creating and advancing

```gleam
import plushie/animation/easing.{EaseInOutCubic}
import plushie/animation/tween

// Create, not yet started:
let anim = tween.new(0.0, 1.0, 500, EaseInOutCubic)

// Start on the next animation-frame tick:
let anim = tween.start(anim, now_ms)

// Advance each frame:
let anim = tween.advance(anim, now_ms)
tween.value(anim)        // current interpolated value
tween.is_finished(anim)  // True once complete
```

### Constructors and modifiers

| Function | Purpose |
|---|---|
| `tween.new(from, to, duration_ms, Easing)` | Create a one-shot tween, not yet started |
| `tween.looping(from, to, duration_ms, Easing)` | Create a looping tween with auto-reverse |
| `tween.set_repeat(anim, Repeat)` | Change repeat mode: `Once`, `Times(n)`, `Forever` |
| `tween.set_auto_reverse(anim, Bool)` | Play in reverse on alternate cycles |
| `tween.start(anim, now)` | Mark the start timestamp |
| `tween.advance(anim, now)` | Update `value` and `finished` fields |
| `tween.value(anim)` | Current interpolated value |
| `tween.is_finished(anim)` | `True` once the animation completes |
| `tween.lerp(from, to, t)` | Linear interpolation helper |

`Repeat` variants: `Once`, `Times(Int)`, `Forever`.

### Driving a tween

Subscribe to the animation frame tick and call `advance` in
`update`:

```gleam
import plushie/subscription

fn subscribe(model: Model) -> List(Subscription) {
  case model.anim {
    Some(a) if !tween.is_finished(a) ->
      [subscription.on_animation_frame()]
    _ -> []
  }
}

fn update(model, event) {
  case event {
    System(AnimationFrame(ts)) -> {
      let new_anim = option.map(model.anim, tween.advance(_, ts))
      #(Model(..model, anim: new_anim), command.none())
    }
    _ -> #(model, command.none())
  }
}
```

Drop the subscription when the tween finishes to stop consuming
frames.

## Renderer vs SDK side

| Concern | Renderer-side (transition / spring / sequence) | SDK-side (tween) |
|---|---|---|
| Wire traffic | Start message, completion event | Frame-driven via subscription |
| Interpolation location | Renderer | App model |
| Supports physics | Yes (spring) | No (sample-based only) |
| Interruption | Automatic, velocity-preserving | Manual |
| Access to value mid-animation | Only through events | Every frame |
| Use when | Animating a widget prop visually | Animating a model value that drives logic |

## See also

- [Built-in Widgets reference](built-in-widgets.md) - which
  widgets expose `_animated` setters
- [Events reference](events.md) - the
  `Widget(TransitionComplete)` and `System(AnimationFrame)`
  variants
- [Subscriptions reference](subscriptions.md) -
  `on_animation_frame` subscription
- [Canvas reference](canvas.md) - animating canvas shapes
