# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.6.0] - 2026-05-09

### Breaking changes

- **`view(model)` now returns `List(Node)` instead of `Option(Node)`.**
  Return `[window(...)]` for a single window, `[win_a, win_b]` for
  multiple peer windows, or `[]` for an empty tree. Wrapping in
  `Some(...)` is no longer needed or accepted. On the JS/WASM target a
  warning is logged when the list contains more than one window, since
  WASM has no OS-level multi-window support.
- **Scoped widget events use `target: EventTarget` instead of three
  separate fields.** All 35 scoped event constructors that previously
  carried `id: String`, `scope: String`, `window_id: String` now carry
  a single `target: EventTarget` record. Pattern-match on
  `event.target.id`, `event.target.scope`, and `event.target.window_id`
  (or use `event.extract_target`).
- **`App.with_subscriptions` renamed to `App.with_subscribe`.**
- **`command.async` renamed to `command.task`.**
- **`command.done` renamed to `command.dispatch`.**
- **`command.native_commands` renamed to `command.widget_batch`.**
- **`command.request_user_attention` renamed to
  `command.request_attention`.**
- **Query commands drop the `get_` prefix:** `get_window_size` ->
  `window_size`, `get_window_position` -> `window_position`,
  `get_mode` -> `window_mode`, `get_scale_factor` -> `scale_factor`,
  `get_system_theme` -> `system_theme`, `get_system_info` ->
  `system_info`.
- **`mouse_area` widget renamed to `pointer_area`.** The widget
  captures all pointer input (mouse, touch, pen), not just mouse.
  Wire kind changes from `"mouse_area"` to `"pointer_area"`.
- **Pointer subscriptions renamed:** `on_mouse_move` ->
  `on_pointer_move`, `on_mouse_button` -> `on_pointer_button`,
  `on_mouse_scroll` -> `on_pointer_scroll`, `on_touch` ->
  `on_pointer_touch`. Wire strings updated accordingly.
- **`grid.columns` prop renamed to `grid.num_columns`.** Dead aliases
  dropped.
- **Extension type names renamed to Widget terminology:**
  `ExtensionDef` -> `WidgetDef`, `ExtensionCommand` ->
  `WidgetCommand`, `ExtensionCommands` -> `WidgetCommands`,
  `ExtensionCommandError` -> `WidgetCommandError`. The module path
  (`plushie/widget`) and wire strings are unchanged.
- **`command.focus_element` removed.** Use `command.focus` with a
  widget ID string.
- **Spacing props on layout widgets widened from `Int` to `Float`.**
  Affects `row.spacing`, `column.spacing`, `grid.spacing`,
  `keyed_column.spacing`, and similar props.
- **`pane_grid.divider_color` now typed as `Color` instead of
  `String`.**
- **`markdown.style` and `qr_code.style` removed.** The renderer
  never read these props. Use `markdown`'s existing text and heading
  props, or `qr_code.cell_color` and `qr_code.background` for colors.
- **`stack.padding` removed.** The renderer has no stack padding field.
  Wrap in a `container` for outer padding.
- **`row.max_height` renamed to `row.max_width`.** The old name was
  incorrect; the prop constrains the row's width.
- **`PLUSHIE_SOURCE_PATH` renamed to `PLUSHIE_RUST_SOURCE_PATH`.**
  Aligns with plushie-rust's naming. Set the new variable; the old
  name is no longer read.
- **`binary_version` in `gleam.toml` renamed to
  `plushie_rust_version`.** Same value, new key. See the
  [versioning reference](docs/reference/versioning.md).

### Added

- **Color contrast helpers:** `color.contrast_ratio/2` computes the
  WCAG contrast ratio between two colors; `color.is_accessible/3`
  checks it against a minimum ratio.
- **Full CSS Level 4 named color catalog** in `plushie/prop/color`.
  All ~150 CSS named colors are now available as typed constants.
- **Typed `Diagnostic` event variants:** `UpdatePanicked`,
  `BufferOverflow`, `DispatchLoop`, and `ProtocolVersionMismatch` are
  now distinct constructors on the `Diagnostic` event. Previously all
  diagnostics landed as a generic `Diagnostic(level, code, message)`.
  `Diagnostic` also now carries a `session` field identifying the
  renderer session that emitted the diagnostic.
- **`ProtocolVersionMismatch` delivered as an observable event.**
  The runtime surfaces a structured `Error(ProtocolVersionMismatch)`
  event when the SDK and renderer versions are out of sync, then stops.
  See the Events reference for the `ErrorEvent` shape.
- **`LinkClicked` typed event variant** for markdown link clicks.
- **`SessionError` and `SessionClosed` typed event variants.**
  `SessionError` now carries an `error_code` field.
- **Key focus events:** `KeyCaptured` and `KeyLost` event variants;
  widget-scoped key events delivered through the scope chain.
- **`undo.push_with_coalesce/3`** for snapshot-style push with a
  custom coalesce key. Merges the new entry into the top of the stack
  when the key matches, instead of always appending.
- **`ui.text_editor/3` convenience helper** in `plushie/ui`.
- **`rule.thickness/2`** - direction-agnostic thickness prop that
  works on both horizontal and vertical rules.
- **Animated builder variants** for `pin`, `svg`, and `progress_bar`.
- **`Custom(StyleMap)` variant for `TextStyle` and `ButtonStyle`**,
  allowing per-widget style overrides beyond the built-in style presets.
- **Typed `EffectResult` variants** per effect kind. Effect callbacks
  now receive a structured result rather than a raw `Dynamic`.
- **Text direction props** on text widgets (`text_direction` on
  `text`, `text_input`, `text_editor`, and `rich_text`).
- **`text_input` expanded** with more builder props.
  `rich_text.SpanHighlight` border aligned with the shared `Border`
  type.
- **`required_widgets` propagated to the renderer handshake**
  settings message, so the renderer can validate that all native
  widget crates are present before the first render.
- **Dispatch-depth guard:** `Command.dispatch` now caps the
  synchronous chain depth to prevent infinite update loops.
  Integration tests verify the guard fires correctly.
- **Negative value rejection at encode time** for `Length`, `Padding`,
  and `Border`. Invalid values produce a compile-time-detectable
  encode error rather than sending malformed wire data.
- **`load_font` sent as a typed top-level protocol message.**
  Previously folded into a generic command envelope.
- **Preflight:** `gleam docs build` added as the final step.
  `PLUSHIE_TEST_TIMEOUT` configures the per-test timeout in seconds
  (default: `2`, matching CI). Override with
  `PLUSHIE_TEST_TIMEOUT=5 ./bin/preflight` on slow machines.

### Fixed

- Image list/clear commands sent over typed `image_op` channel instead
  of the generic command path.
- `default_font` always emitted as a family object on the wire, even
  when no custom font is configured.
- `window_opened` event position read from the top-level `x`/`y`
  fields, not a nested struct that was never populated.
- CLI flag parsing hardened against unexpected input formats.
- SHA-256 hex encoding standardized between the BEAM and JS targets.
- Custom theme key errors produce clearer messages pointing at the
  offending key.
- Test timeouts scaled correctly for the `PLUSHIE_TEST_TIMEOUT` value.
- Stale test interactions (e.g., `await` after the session has closed)
  fail immediately rather than hanging until the process timeout.
- Protocol inputs validated before encoding; invalid messages are
  rejected at the Gleam layer.
- Renderer subprocess environment whitelisted; sensitive host env vars
  are no longer forwarded to the renderer process.
- Web runtime callbacks serialized through the dispatch queue,
  preventing mid-update interleave on the JS target.
- Bridge inbound buffer bounded to prevent unbounded memory growth on
  a slow consumer.
- Range anchors in `plushie/selection` updated for correct
  anchor-based range expansion.
- `plushie/data` query results grouped correctly before pagination is
  applied.
- Widget accessibility state exposed through `testing` helpers.
- Platform locale helpers added (`platform.locale/0`).
- Renderer version read from `gleam.toml` (`config.plushie_rust_version`)
  rather than a hard-coded constant in the binary resolution path.
- Unicode widget IDs accepted; previously ASCII-only validation
  rejected valid non-ASCII identifiers.
- Web effect responses and timeouts handled correctly on the JS target.
- Spring presets aligned with renderer values.
- `floating` widget emitted with canonical `"floating"` kind.
- MessagePack frame size limits enforced; frames exceeding the cap are
  rejected with a structured error rather than silently truncated.
- Non-finite floats (`Infinity`, `NaN`) normalized to `0.0` before
  wire encoding.
- Concurrency bugs in bridge restart and build FFI resolved.
- File dialog `DefaultPath` emitted as the directory type on the wire.
- `SelectRange` wire format corrected: `start_pos`/`end_pos` keys
  (was `start`/`end`).
- `tooltip` and `text_editor` padding typed as scalar `Float` to match
  the renderer's expected field shape.
- Telemetry event atoms whitelisted to prevent dynamic atom creation
  at runtime on the BEAM target.
- Cross-target math helpers unified between BEAM and JS.
- Undo coalescing contract enforced for the standard push path.

### Changed

- **Tree diff uses LIS-based algorithm for minimal patches.** When
  children are reordered, the diff now computes the longest increasing
  subsequence to produce a smaller patch set, reducing the number of
  re-renders on heavy list operations.
- **Renderer: targets plushie-renderer 0.7.0** (was 0.5.1).
- **`plushie/build` delegates to `cargo-plushie`.** Workspace
  generation and widget wiring moved out of the SDK and into
  plushie-rust's `cargo-plushie` tool. The SDK now emits a tiny
  virtual app crate under `_build/plushie-renderer-spec/` and shells
  out to `cargo plushie build`.
  - `PLUSHIE_RUST_SOURCE_PATH` set: the build uses
    `cargo run -p cargo-plushie` from the checkout.
  - `PLUSHIE_RUST_SOURCE_PATH` unset: `cargo-plushie` is expected on
    PATH at a version matching `plushie_rust_version`.
  - Missing or mismatched: `plushie/build` prints the required
    `cargo install cargo-plushie --version X.Y.Z --locked` command.
- **Native widget crates must declare
  `[package.metadata.plushie.widget]`.** Widget discovery now runs
  through `cargo metadata`. The `crate_path|constructor` string in
  `gleam.toml` is still parsed for migration compatibility but the
  widget crate's own `Cargo.toml` is the source of truth.
  `cargo plushie new-widget <name>` scaffolds this correctly.
- **`testing.start()` event dispatch routes through the production
  decoder.** Events from `interact_response` and `interact_step`
  messages now go through `protocol/decode` rather than a parallel
  implementation, so bugs in the production decoder surface in
  `testing.start()` test suites instead of being silently bypassed.

### Removed

- `markdown.style`, `qr_code.style`, and `stack.padding` builder
  props. See Breaking changes above.
- `row.max_height` builder prop. See Breaking changes above.
- `command.focus_element`. See Breaking changes above.
- Internal FFI functions `cargo_build` and `cargo_build_workspace`.
- Patch-forwarding helpers (`forward_patches`,
  `forward_patches_with_sdk`, `extract_and_resolve_patches`,
  `collect_patch_section`, `resolve_patch_path`,
  `merge_patch_sections`, `sdk_crate_patches`, `CratePatch`).
  `cargo-plushie` owns patch forwarding.
- Hand-rolled constructor / identifier validators; `cargo-plushie`
  validates.

## [0.5.0] - 2026-03-23

### Added

- **Socket transport**: `plushie/connect` replaces `plushie/stdio`
  for connecting to an already-running renderer via Unix socket or
  TCP. `plushie/socket_adapter` bridges gen_tcp to the iostream
  transport protocol. Token authentication is included in the
  settings wire message when provided.
- **WASM download/build support**: `gleam run -m plushie/download`
  and `gleam run -m plushie/build` support `--wasm` flag for
  downloading or building the WASM renderer alongside or instead
  of the native binary.
- **`--bin-file` and `--wasm-dir` flags for `plushie/build`**:
  override the default binary destination or WASM output directory,
  matching the flags already available in `plushie/download`.
- **Canvas `FocusRingRadius`**: new `InteractiveOpt` variant for
  setting a custom border radius on interactive group focus rings.
- **Canvas `role` and `arrow_mode` props** on the Canvas widget for
  accessibility (e.g., `role: "radiogroup"` on star ratings).
- **`Diagnostic` event variant**: renderer diagnostic messages
  (warnings, errors) are now decoded as `Diagnostic(level,
  element_id, code, message)` events.
- **Demo project links in docs**: extensions, commands,
  getting-started, and running docs now link to the plushie-demos
  repository.

### Changed

- **Binary location**: downloaded and built binaries now install
  to `build/plushie/bin/` instead of `priv/bin/`. A `bin/plushie`
  symlink is created pointing to the installed artifact. The old
  `priv/bin/` location is still checked as a fallback for backward
  compatibility.
- **Renderer binary renamed**: all references updated from
  `plushie` to `plushie-renderer`. Download URLs now point to
  `plushie-ui/plushie-renderer` releases. Rust crate references
  updated from `plushie-core` to `plushie-ext`.
- **Binary version**: targets plushie-renderer 0.5.1.
- **Canvas group redesign**: groups now auto-wrap non-group shapes
  in `interactive()` calls. Shape interactive options updated.

### Fixed

- **Star rating `focus_style`**: corrected from flat
  `{stroke: color}` to nested `{stroke: {color, width}}` matching
  the renderer's `parse_canvas_stroke` format.
- **Theme toggle focus ring**: added padding for outset focus ring,
  group offset, `FocusRingRadius` for pill shape, and `toggled`
  a11y field for screen readers.
- **Rate Plushie page theme**: wrapped page in `themer` with
  custom interpolated palette so built-in widgets animate with the
  theme transition. Added `width: Fill` to card column.

## [0.4.0] - 2026-03-22

Initial public release.

### Added

- **Elm architecture**: `init`, `update`, `view`, optional
  `subscribe` callbacks via the `App` type and `app.simple`
  constructor.
- **38 built-in widget types**: layout (column, row, container,
  scrollable, stack, grid, pane_grid), display (text, rich_text,
  markdown, image, svg, progress_bar, qr_code, rule, canvas),
  input (button, text_input, text_editor, checkbox, radio, toggler,
  slider, vertical_slider, pick_list, combo_box, table), and
  wrappers (tooltip, mouse_area, sensor, overlay, responsive, themer,
  keyed_column, space, floating, pin, window).
- **Two-layer builder API**: `plushie/ui` convenience functions with
  `Attr` lists, and `plushie/widget/*` typed opaque builders with
  chainable setters.
- **22 built-in themes**: light, dark, dracula, nord, solarized,
  gruvbox, catppuccin, tokyo night, kanagawa, moonfly, nightfly,
  oxocarbon, ferra. Custom palettes and per-widget style overrides
  via `plushie/prop/style_map`.
- **Multi-window**: declare window nodes in the widget tree; the
  framework manages open/close/update automatically.
- **Platform effects**: native file dialogs, clipboard (text, HTML,
  primary selection), OS notifications.
- **Accessibility**: screen reader support via accesskit on all
  platforms. A11y builder (`plushie/prop/a11y`) on all widgets.
- **Commands**: async work, streaming, timers, widget ops (focus,
  scroll, select), window management, image management, platform
  effects, extension commands.
- **Subscriptions**: timers, keyboard, mouse, touch, IME, window
  lifecycle, animation frames, system theme changes.
- **Typed event union**: `Event` type with constructors for
  Widget, Key, Mouse, Touch, Ime, Window, Canvas, MouseArea, Pane,
  Sensor, Effect, System, Timer, Async, Stream, Modifiers events.
- **Scoped widget IDs**: containers namespace children's IDs
  automatically. Pattern match on local ID or scope chain.
- **Three-backend test framework**: mocked (fast, no display),
  headless (real rendering via tiny-skia, screenshots), windowed
  (real GPU windows). Same API across all three. Session pooling
  for parallel test execution.
- **`.plushie` script format**: declarative test scripts with
  parser, runner, and CLI entry points (`plushie/script`,
  `plushie/replay`).
- **Extension system**: pure Gleam composite widgets or Rust-backed
  native widgets via `ExtensionDef` data-driven definitions.
- **CLI entry points**: `plushie/gui` for local desktop apps,
  `plushie/stdio` for exec/remote rendering mode.
- **Bridge restart**: automatic renderer restart with exponential
  backoff on crash (model state preserved).
- **Event coalescing**: high-frequency events (mouse moves, sensor
  resizes) are deferred and coalesced per source.
- **Precompiled binaries**: `bin/plushie_download` fetches
  platform-specific binaries.
- **Build from source**: `bin/plushie_build` compiles the plushie
  binary with optional extension workspace generation.
- **State helpers**: `plushie/undo` (undo/redo), `plushie/selection`
  (single/multi/range), `plushie/route` (navigation), `plushie/data`
  (query pipeline), `plushie/animation` (easing functions).
- **Canvas drawing**: shape primitives (rect, circle, arc, path,
  text, image) with layers, gradients, opacity, interactive shapes,
  and caching.
- **Wire protocol**: MessagePack (default) and JSONL formats,
  version 1.
- **8 example apps**: Counter, Todo, Notes, Clock, Shortcuts,
  AsyncFetch, ColorPicker, Catalog.
