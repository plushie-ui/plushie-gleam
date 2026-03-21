# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-03-21

Initial release of the Gleam SDK for toddy.

### Added

- **Elm architecture** -- `init`, `update`, `view`, optional
  `subscribe` callbacks via the `App` type and `app.simple`
  constructor.
- **38 built-in widget types** -- layout (column, row, container,
  scrollable, stack, grid, pane_grid), display (text, rich_text,
  markdown, image, svg, progress_bar, qr_code, rule, canvas),
  input (button, text_input, text_editor, checkbox, radio, toggler,
  slider, vertical_slider, pick_list, combo_box, table), and
  wrappers (tooltip, mouse_area, sensor, overlay, responsive, themer,
  keyed_column, space, floating, pin, window).
- **22 built-in themes** -- light, dark, dracula, nord, solarized,
  gruvbox, catppuccin, tokyo night, kanagawa, moonfly, nightfly,
  oxocarbon, ferra. Custom palettes and per-widget style overrides
  via `toddy/prop/style_map`.
- **Multi-window** -- declare window nodes in the widget tree; the
  framework manages open/close/update automatically.
- **Platform effects** -- native file dialogs, clipboard (text, HTML,
  primary selection), OS notifications.
- **Accessibility** -- screen reader support via accesskit on all
  platforms. A11y builder (`toddy/prop/a11y`) on all widgets.
- **Commands** -- async work, streaming, timers, widget ops (focus,
  scroll, select), window management, image management, platform
  effects, extension commands.
- **Subscriptions** -- timers, keyboard, mouse, touch, IME, window
  lifecycle, animation frames, system theme changes.
- **Typed event union** -- `Event` type with constructors for
  Widget, Key, Mouse, Touch, Ime, Window, Canvas, MouseArea, Pane,
  Sensor, Effect, System, Timer, Async, Stream, Modifiers events.
- **Scoped widget IDs** -- containers namespace children's IDs
  automatically. Pattern match on local ID or scope chain.
- **Extension system** -- pure Gleam composite widgets or Rust-backed
  native widgets via `ExtensionDef` data-driven definitions.
- **Two-layer builder API** -- `toddy/ui` convenience functions with
  `Attr` lists, and `toddy/widget/*` typed opaque builders with
  chainable setters.
- **CLI entry points** -- `toddy/cli/gui` for local desktop apps,
  `toddy/cli/stdio` for exec/remote rendering mode.
- **Bridge restart** -- automatic renderer restart with exponential
  backoff on crash (model state preserved).
- **Event coalescing** -- high-frequency events (mouse moves, sensor
  resizes) are deferred and coalesced per source.
- **Precompiled binaries** -- `bin/toddy_download` fetches
  platform-specific binaries.
- **Build from source** -- `bin/toddy_build` compiles the toddy
  binary with optional extension workspace generation.
- **State helpers** -- `toddy/undo` (undo/redo), `toddy/selection`
  (single/multi/range), `toddy/route` (navigation), `toddy/data`
  (query pipeline), `toddy/animation` (easing functions).
- **Canvas drawing** -- shape primitives (rect, circle, arc, path,
  text, image) with layers, gradients, opacity, interactive shapes,
  and caching.
- **Wire protocol** -- MessagePack (default) and JSONL formats,
  version 1.
