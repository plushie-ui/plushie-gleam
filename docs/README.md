# Documentation

## Guides

Sequential chapters that build on each other. The guides are
pending a rewrite.

## Reference

Lookup material organized by topic. Each page is self-contained.

- [Accessibility](reference/accessibility.md) - the `A11y` prop,
  role vocabulary, accessible name computation, keyboard
  navigation, announcements, and accessibility diagnostics
- [Animation](reference/animation.md) - transitions, springs,
  sequences, easing curves, animatable props, and SDK-side
  tweens
- [App Lifecycle](reference/app-lifecycle.md) - `App(model, msg)`,
  the init / update / view cycle, startup sequence, panic
  recovery, bridge restart, runtime state queries
- [Built-in Widgets](reference/built-in-widgets.md) - every
  widget with props, events, and examples; common prop types
  (Font, Shaping, Wrapping, ContentFit, FilterMethod, Position,
  Direction, Anchor)
- [Canvas](reference/canvas.md) - shapes, paths, transforms,
  groups, gradients, and interactive canvas elements
- [CLI Commands](reference/cli-commands.md) - `plushie/build`,
  `plushie/download`, `plushie/gui`, `plushie/stdio`,
  `plushie/connect`, `plushie/inspect`, `plushie/script`,
  `plushie/replay`, and the preflight script
- [Commands and Effects](reference/commands.md) - control flow,
  async, focus, scroll, window ops, system queries, image
  management, platform effects
- [Composition Patterns](reference/composition-patterns.md) -
  reusable components, overlays, context menus, multi-window,
  memoisation
- [Configuration](reference/configuration.md) - environment
  variables, `gleam.toml` `[plushie]`, `app.Settings`,
  `StartOpts`, the `gui` / `stdio` / `connect` wrappers, and
  transport modes
- [Custom Widgets](reference/custom-widgets.md) - composite
  widgets in pure Gleam, `WidgetDef` and `EventAction`, native
  widgets (Rust-backed), and the trade-offs between them
- [Erlang Interop](reference/erlang-interop.md) - module and
  value mapping, calling the SDK from Erlang, helper-module
  pattern, starting the runtime from Erlang
- [Events](reference/events.md) - every `Event` variant with
  fields, the `WidgetEvent` taxonomy, modifier semantics, a
  pattern-matching cookbook, and the event pipeline
- [Scoped IDs](reference/scoped-ids.md) - ID scoping rules,
  scope matching, command paths
- [Subscriptions](reference/subscriptions.md) - timers,
  keyboard, window, pointer, IME, theme, animation frame,
  rate limiting, window scoping
- [Testing](reference/testing.md) - test harness, backends,
  selectors, assertions, effect stubs, snapshots, screenshots,
  the session pool, widget harness
- [Themes and Styling](reference/themes-and-styling.md) -
  `Color`, `Theme`, `StyleMap`, `Border`, `Shadow`, `Gradient`,
  subtree theming
- [Versioning](reference/versioning.md) - SDK version,
  `plushie_rust_version`, wire protocol version, upgrade
  guidance
- [Windows and Layout](reference/windows-and-layout.md) -
  window props, `Length` / `Padding` / `Alignment`, every
  layout container, composition patterns
- [Wire Protocol](reference/wire-protocol.md) - MessagePack
  and JSONL framing, handshake, snapshots vs patches,
  session multiplexing, transport modes, bridge restart

## Other resources

- [Examples](https://github.com/plushie-ui/plushie-gleam/tree/main/examples) -
  example apps bundled with the repo
