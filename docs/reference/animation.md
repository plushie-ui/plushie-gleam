# Animation

Plushie's animation system is declarative. You describe what each prop
should be, and the renderer interpolates. Zero wire traffic during
animation, zero subscriptions, zero model state.

For a tutorial introduction, see [guide chapter 9](../guides/09-animation.md).

## Transitions

`plushie/animation/transition`

```gleam
import plushie/animation/transition

container.MaxWidth(transition.new(300, transition.To(200)))
transition.new(300, transition.To(200))
|> transition.easing(transition.EaseOut)
|> transition.delay(100)
|> transition.from(0)
```

| Option | Default | Description |
|---|---|---|
| `To(n)` | required | Target value |
| `Easing(curve)` | `EaseInOut` | Easing curve |
| `Delay(ms)` | `0` | Delay before start |
| `From(n)` | nil | Start value (enter animations only) |
| `OnComplete(tag)` | nil | Emit completion event |

### Looping

`transition.loop` sets `repeat: Forever` and `auto_reverse: True`:

```gleam
container.Opacity(transition.loop(1500, transition.To(1.0), transition.From(0.7)))
```

## Springs

`plushie/animation/spring`

```gleam
import plushie/animation/spring

container.Scale(spring.new(spring.To(1.05), [spring.Preset(spring.Bouncy)]))
spring.new(spring.To(200.0), [spring.Stiffness(200.0), spring.Damping(20.0)])
```

| Preset | Feel |
|---|---|
| `Gentle` | Slow, smooth, no overshoot |
| `Snappy` | Quick, minimal overshoot |
| `Bouncy` | Quick with visible bounce |
| `Stiff` | Very quick, crisp stop |
| `Molasses` | Slow, heavy, deliberate |

## Sequences

`plushie/animation/sequence`

```gleam
import plushie/animation/sequence

container.MaxWidth(sequence.new([
  transition.new(200, transition.To(300)),
  transition.new(300, transition.To(0)),
]))
```

## Animatable props

| Prop | Widgets | Purpose |
|---|---|---|
| `Opacity` | Most widgets | Fade effects |
| `MaxWidth` | column, row, container | Expand/collapse width |
| `MaxHeight` | container | Expand/collapse height |
| `Scale` | Most widgets | Grow/shrink effect |
| `Rotation` | text, image | Rotate in degrees |
| `TranslateX`, `TranslateY` | floating | Slide effects |
| `X`, `Y` | pin | Position animation |
| `Value` | progress_bar | Smooth progress |

Width/height as Length values (`Fill`, `Shrink`, `FillPortion`) cannot be
animated. Use `MaxWidth`/`MaxHeight` for size animation.

## Easing catalogue

31 named curves plus custom cubic bezier:

**Standard**: `Linear`, `EaseIn`, `EaseOut`, `EaseInOut`

**Power curves**: `EaseInQuad` through `EaseInOutQuint`

**Overshoot**: `EaseOutBack`, `EaseOutElastic`, `EaseOutBounce` (and
in/in-out variants)

**Custom**: `CubicBezier(0.25, 0.1, 0.25, 1.0)`

## Exit animations

```gleam
container.Exit([
  container.Opacity(transition.new(200, transition.To(0.0))),
])
```

When the widget leaves the tree, the renderer keeps it visible as a
ghost and plays the exit animations. Other widgets don't collapse into
the space until the exit completes.

## SDK-side animation (Tween)

`plushie/animation/tween`

For canvas animations or values that drive model logic:

```gleam
import plushie/animation/tween

let anim = tween.new(tween.From(0.0), tween.To(1.0), tween.Duration(300))
```

Requires `subscription.on_animation_frame("frame")` for the timestamp
source.

## Accessibility

When the OS reports `prefers-reduced-motion`, the renderer treats all
transition descriptors as instant. Props snap to their target values.
This is automatic.

## See also

- [Guide: Animation](../guides/09-animation.md)
- [Testing reference](testing.md) - `advance_frame` and `skip_transitions`
