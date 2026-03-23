# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.5.0] - 2026-03-23

### Added

- **Socket transport** -- `plushie/connect` replaces `plushie/stdio`
  for connecting to an already-running renderer via Unix socket or
  TCP. `plushie/socket_adapter` bridges gen_tcp to the iostream
  transport protocol. Token authentication is included in the
  settings wire message when provided.
- **WASM download/build support** -- `gleam run -m plushie/download`
  and `gleam run -m plushie/build` support `--wasm` flag for
  downloading or building the WASM renderer alongside or instead
  of the native binary.
- **`--bin-file` and `--wasm-dir` flags for `plushie/build`** --
  override the default binary destination or WASM output directory,
  matching the flags already available in `plushie/download`.
- **Canvas `FocusRingRadius`** -- new `InteractiveOpt` variant for
  setting a custom border radius on interactive group focus rings.
- **Canvas `role` and `arrow_mode` props** on the Canvas widget for
  accessibility (e.g., `role: "radiogroup"` on star ratings).
- **`Diagnostic` event variant** -- renderer diagnostic messages
  (warnings, errors) are now decoded as `Diagnostic(level,
  element_id, code, message)` events.
- **Demo project links in docs** -- extensions, commands,
  getting-started, and running docs now link to the plushie-demos
  repository.

### Changed

- **Binary location** -- downloaded and built binaries now install
  to `build/plushie/bin/` instead of `priv/bin/`. A `bin/plushie`
  symlink is created pointing to the installed artifact. The old
  `priv/bin/` location is still checked as a fallback for backward
  compatibility.
- **Renderer binary renamed** -- all references updated from
  `plushie` to `plushie-renderer`. Download URLs now point to
  `plushie-ui/plushie-renderer` releases. Rust crate references
  updated from `plushie-core` to `plushie-ext`.
- **Binary version** -- targets plushie-renderer 0.5.0.
- **Canvas group redesign** -- groups now auto-wrap non-group shapes
  in `interactive()` calls. Shape interactive options updated.

### Fixed

- **Star rating `focus_style`** -- corrected from flat
  `{stroke: color}` to nested `{stroke: {color, width}}` matching
  the renderer's `parse_canvas_stroke` format.
- **Theme toggle focus ring** -- added padding for outset focus ring,
  group offset, `FocusRingRadius` for pill shape, and `toggled`
  a11y field for screen readers.
- **Rate Plushie page theme** -- wrapped page in `themer` with
  custom interpolated palette so built-in widgets animate with the
  theme transition. Added `width: Fill` to card column.

## [0.4.0] - 2026-03-22

Initial public release.

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
- **Two-layer builder API** -- `plushie/ui` convenience functions with
  `Attr` lists, and `plushie/widget/*` typed opaque builders with
  chainable setters.
- **22 built-in themes** -- light, dark, dracula, nord, solarized,
  gruvbox, catppuccin, tokyo night, kanagawa, moonfly, nightfly,
  oxocarbon, ferra. Custom palettes and per-widget style overrides
  via `plushie/prop/style_map`.
- **Multi-window** -- declare window nodes in the widget tree; the
  framework manages open/close/update automatically.
- **Platform effects** -- native file dialogs, clipboard (text, HTML,
  primary selection), OS notifications.
- **Accessibility** -- screen reader support via accesskit on all
  platforms. A11y builder (`plushie/prop/a11y`) on all widgets.
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
- **Three-backend test framework** -- mocked (fast, no display),
  headless (real rendering via tiny-skia, screenshots), windowed
  (real GPU windows). Same API across all three. Session pooling
  for parallel test execution.
- **`.plushie` script format** -- declarative test scripts with
  parser, runner, and CLI entry points (`plushie/script`,
  `plushie/replay`).
- **Extension system** -- pure Gleam composite widgets or Rust-backed
  native widgets via `ExtensionDef` data-driven definitions.
- **CLI entry points** -- `plushie/gui` for local desktop apps,
  `plushie/stdio` for exec/remote rendering mode.
- **Bridge restart** -- automatic renderer restart with exponential
  backoff on crash (model state preserved).
- **Event coalescing** -- high-frequency events (mouse moves, sensor
  resizes) are deferred and coalesced per source.
- **Precompiled binaries** -- `bin/plushie_download` fetches
  platform-specific binaries.
- **Build from source** -- `bin/plushie_build` compiles the plushie
  binary with optional extension workspace generation.
- **State helpers** -- `plushie/undo` (undo/redo), `plushie/selection`
  (single/multi/range), `plushie/route` (navigation), `plushie/data`
  (query pipeline), `plushie/animation` (easing functions).
- **Canvas drawing** -- shape primitives (rect, circle, arc, path,
  text, image) with layers, gradients, opacity, interactive shapes,
  and caching.
- **Wire protocol** -- MessagePack (default) and JSONL formats,
  version 1.
- **8 example apps** -- Counter, Todo, Notes, Clock, Shortcuts,
  AsyncFetch, ColorPicker, Catalog.
