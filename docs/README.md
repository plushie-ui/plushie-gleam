# Documentation

## Guides

Sequential chapters that build on each other. Start here if you're
new to Plushie.

1. [Introduction](guides/01-introduction.md) - what Plushie is and how it works
2. [Getting Started](guides/02-getting-started.md) - installation, binary setup, first run
3. [Your First App](guides/03-your-first-app.md) - building the Plushie Pad layout
4. [The Development Loop](guides/04-the-development-loop.md) - hot reload, runtime Erlang compilation, inspecting a running app
5. [Events](guides/05-events.md) - widget events, keyboard, pointer, pattern matching
6. [Lists and Inputs](guides/06-lists-and-inputs.md) - dynamic lists, text inputs, forms, scoped IDs
7. [Layout](guides/07-layout.md) - rows, columns, containers, sizing, alignment
8. [Styling](guides/08-styling.md) - themes, colors, fonts, per-widget style overrides
9. [Animation and Transitions](guides/09-animation.md) - transitions, springs, tweens, easing
10. [Subscriptions](guides/10-subscriptions.md) - timers, global key events, window events
11. [Async and Effects](guides/11-async-and-effects.md) - async tasks, streams, platform effects
12. [Canvas](guides/12-canvas.md) - shapes, layers, transforms, interactive elements
13. [Custom Widgets](guides/13-custom-widgets.md) - composing widgets, canvas widgets, native Rust widgets
14. [State Management](guides/14-state-management.md) - routing, undo/redo, selection, data pipelines
15. [Testing](guides/15-testing.md) - test framework, backends, selectors, screenshots
16. [Shared State](guides/16-shared-state.md) - multi-renderer apps over stdio or sockets
17. [WASM Deployment](guides/17-wasm-deployment.md) - compiling a Plushie app for the browser

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
