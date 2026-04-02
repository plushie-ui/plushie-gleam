# Animation and Transitions

Plushie's animation system is built around a key insight: the renderer is
closer to the screen than your Gleam code. By declaring animation *intent*
in `view` and letting the renderer handle interpolation, you get smooth
60fps animation with zero wire traffic.

## Transitions

A transition animates a numeric prop from its current value to a target:

```gleam
import plushie/animation/transition

ui.container("panel", [
  container.MaxWidth(transition.new(300, transition.To(200))),
], [...])
```

When the target changes, the renderer smoothly interpolates. Options include
`Easing`, `Delay`, `From` (enter animation), and `OnComplete`.

## Springs

Springs use physics simulation instead of timed curves:

```gleam
import plushie/animation/spring

container.Scale(spring.new(spring.To(1.05), [spring.Preset(spring.Bouncy)]))
```

Springs handle interruption gracefully. If the target changes mid-animation,
the spring preserves velocity and smoothly redirects.

## Sequences

Chain animations that play one after another:

```gleam
import plushie/animation/sequence

container.MaxWidth(sequence.new([
  transition.new(200, transition.To(300)),
  transition.new(300, transition.To(0)),
]))
```

## SDK-side animation (Tween)

For canvas animations or values that drive model logic, use
`plushie/animation/tween`:

```gleam
import plushie/animation/tween

let anim = tween.new(tween.From(0.0), tween.To(1.0), tween.Duration(300))
```

This requires a subscription for frame events and manual advancement in
`update`. For most property animations, renderer-side transitions are
simpler and more performant.

See the [Animation reference](../reference/animation.md) for the full
easing catalogue and animatable props.

---

Next: [Subscriptions](10-subscriptions.md)
