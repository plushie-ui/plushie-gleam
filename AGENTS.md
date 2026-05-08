# plushie-gleam

This file is not version controlled. Do not reference it in commit
messages, pull requests, or documentation.

Gleam SDK for plushie, a native desktop GUI framework powered by iced.
Implements the Elm architecture (init/update/view) with commands
and subscriptions. Communicates with a plushie Rust binary over
stdin/stdout using MessagePack (default) or JSONL.

## Stewardship

Direction, trust posture, goals, and non-goals live in
`docs/stewardship/`. That directory is the authority. The summary
below is enough for routine work; pull the relevant doc when an axis
is in play. Use `docs/stewardship/triage.md` as the routing tool.

Pre-1.0: no backcompat; right design wins; rename across SDKs is
fine. Post-1.0: stability obligations begin (Hyrum's Law).
plushie-rust = protocol authority; plushie-elixir = canonical API-
shape reference; plushie-gleam follows. A rename here that does not
propagate is drift. Cross-SDK parity audited in sibling
`plushie-sdk-parity/`. Library, not a registered OTP application.
Multi-target: BEAM and JS share the pure layer; concurrency shape
differs.

### Disciplines (non-negotiable)

Tests through real renderer (BEAM) or pure session runner (JS);
cross-SDK claims verified by reading source; design before code at
boundaries; clarity is the bar; no half-built features; use the type
system aggressively (no `coerce`/`unsafe_coerce`, no internal
`Dynamic`); local cleanup not scope creep; no legacy shims pre-1.0.

### Goals

Wire codec fidelity; cross-SDK concept parity (semantics converge,
syntax diverges per language); Elm-architecture purity (typed return
tuples, pure view, declarative subs, commands as data); lightweight
runtime (no idle work, no polling, minimal tree diff); fault
tolerance (renderer crash auto-recovers + state re-syncs on BEAM;
neither side takes the other down); multi-target parity (BEAM and JS
share user-facing API); type-system clarity (custom types, opaque
builders, parameterized `Command(msg)` / `Instance(model)`).

### Non-goals (declined, not deprioritized)

Backcompat before 1.0; per-Gleam ergonomics diverging from cross-SDK
shape; API stability hardening pre-1.0 (single sweep at 1.0);
coverage targets; mocking renderer for speed on BEAM; micro-
optimization at cost of readability; refactoring without a forcing
function; general-purpose Dynamic plumbing internally; builder
extensions for hypothetical future widgets; defending against
speculative deployment shapes.

### Trust model

Asymmetric. Renderer-to-host = closed and typed; host structurally
protected (typed decoding, no opaque-blob path, effect/query
correlation by request ID, no host-side eval, closed diagnostic
union, no `coerce` on wire path). Host-to-renderer = broad by design
(file paths, fonts, images, screenshots, effects, `--exec`); bounding
it is the capability-manifest roadmap in plushie-rust. Wire = byte-
stream agnostic; confidentiality + integrity = outer transport's job.
Same-access out of scope. JS sandbox inherits host page/worker.

### Resilience

Things-go-wrong axis, not adversary axis. Errors-as-values via
`Result(t, e)`. Bridge classifies messages as rebuildable (dropped
during restart; runtime regenerates) or transient (queued, flushed
after ResyncComplete). Bounded exponential backoff on bridge restart
with capped failures; model preserved across restarts. Subjects
created in receiving process. JS callbacks enter through dispatch
queue (no mid-update interleave). Async nonces validate freshness.
Dispatch-loop guard caps synchronous chain depth. Framing rejects
oversized frames. Fail-fast on invariant violations; degrade on
user-facing input.

### Performance

Lightweight = baseline, not optimization-after-fact. Don't do
unnecessary work in the first place; cost compounds. Worth doing
without benchmark (readability preserved): consolidate redundant
traversals, right data structure, encode prop values once inside
`build()` (encoding-at-build invariant), move per-frame work that
doesn't depend on per-frame inputs to the edge. Need benchmark
first: clever encoding, big-O without realistic N, FFI shortcuts
where pure Gleam suffices. Numeric direction: 16.67ms frame budget,
idle CPU = no measurable work, tree diff load-bearing (single-pass,
MemoCache, patch paths as `List(Int)`).

### Test discipline

Integration spine: BEAM tests exercise real renderer (default `mock`
backend = real binary, real wire, real Core, no GPU). Three modes
(cross-SDK contract): mock (default, pooled), headless (tiny-skia,
pixels), windowed (full iced, real display). Pooled mock multiplexes
via `--max-sessions N`. JS target uses pure session runner through
`runtime_core` (renderer is WASM there, not a corner-cut for speed).
Stubs acceptable only for renderer-level effect stubs, forced crash
sim, malformed wire bytes, test infra. Sync via
`plushie.get_model`/`get_tree`/`dispatch_event`. Tests as
documentation; slow tests = slow code; failing test before fix. Test
apps must return `window` nodes from `view`.

### Simplicity

Clarity = constraint, not aspiration. Readability wins ties.
Abstraction earns its place: 3 similar lines > premature abstraction;
3rd use earns consideration; single-user abstraction = costume; "we
might need this someday" = reason not to extract. Local complexity >
global; cohesion across file > brevity. Functional by design (Gleam
fits): pure where possible, immutable, pattern matching, sum types,
errors-as-values, builder pipelines. No `coerce(a) -> b` /
`unsafe_coerce`; named narrow boundary functions
(`event_to_msg`, `from_dynamic`, `model_to_dynamic`). No internal
`Dynamic`; lives only at wire-edge decode, async result, `app_opts`.

### Elm invariants

`init`/`update` return `#(model, Command(msg))` (compiler-checked).
`command.none()` = no side effect. Commands are pure data; runtime
executes. `view(model) -> List(Node)`; pure; top level must be
`window` nodes; empty list renders nothing. Subscriptions
declarative; runtime diffs by stable key per cycle. Widget event
flow walks scope chain innermost-first; handlers return
`Ignored`/`Consumed`/`Emit(kind, data)` (optional state persist).
Canvas-internal events auto-consumed if not captured. Wire IDs:
`window#scope/path/id`; events expose `EventTarget(id, scope,
window_id)`; commands use forward-order path strings.
`App(model, msg)` and `Instance(model)` parameterized; types flow.

### DSL (library, not macros)

No macros; DSL is library functions over typed builders. Two shapes:
chained per-widget builders (`button.new(id, label) |>
button.width(Fill) |> button.build()`) and `Opt`-list shorthand
through `plushie/ui`. Property types in `plushie/prop/*`.
Encoding-at-build invariant: prop values reach the tree already
encoded; deferred encoding forbidden. New builder option earns its
place when: renderer prop exists, 2+ real users, real bug class
addressed, `gleam docs` reads cleanly, errors point at user call
site, shape matches plushie-elixir. Type-level enforcement welcome
for closed sets, opaque invariants, type-flow params; not for
runtime-shaped checks or phantom params with one constraint user.

### Concurrency shape

BEAM: Bridge owns Port + wire framing + restart loop; Runtime owns
app loop + model + tree. RestForOne supervisor; Bridge starts first;
Runtime registers its notification Subject after start. Subjects
created in receiving process. Three transports (Spawn, Stdio,
Iostream) behind `TransportOps` record-of-functions. SessionPool
multiplexes mock/headless; windowed = one renderer per session.
JS: `runtime_web` callback-driven; state in mutable JS object via
FFI; `queueMicrotask` coalescing; callbacks through dispatch queue.
Both targets share `runtime_core`. No `:sys` debug; no staged event
pipeline; no distributed messaging; no auto application start.

### Common shapes -> outcomes

- "mock the renderer for speed on BEAM" -> decline
- "add a `coerce(a) -> b` helper" -> decline; named boundary fn
- "pass `Dynamic` to this internal call" -> upstream type wants param
- "add API hardening / sealed unions piecemeal" -> decline; 1.0 sweep
- "this is O(n) on a hot path" -> need realistic N
- "split this large module" -> need forcing function
- "harden against malicious renderer" -> structurally protected;
  check if proposal loosens that, otherwise misframed
- "harden against malicious host" -> defer to capability-manifest
  (plushie-rust roadmap)
- "wire should encrypt / sign" -> outer transport's job
- "consolidate N redundant traversals" -> do
- "extract this single-use abstraction" -> decline; costume
- "this exception should propagate" -> usually no; reject+report
- "let users return a different shape from `update`" -> no
- "rename field across SDKs" -> route through parity workflow
- "add a new builder option for X" -> run dsl-discipline criteria
- "this widget works on BEAM only / JS only" -> parity bug
- "create Subject in caller, deliver in actor" -> wrong; foot-gun

## Before committing

Run `./bin/preflight`. It mirrors CI: format check, compile, test, docs build.

Gleam has no separate lint or type-check step; the compiler does
both. If it compiles, the types are correct.

Preflight output must be clean. Any `[error]` or `[warning]` log
lines in the test output are bugs. They indicate log output
leaking from tests that should be capturing it. Fix the source

### Renderer freshness during preflight

Tests exercise the real renderer binary, so a stale binary hides
real bugs and surfaces phantom ones. When `PLUSHIE_RUST_SOURCE_PATH`
is set to a plushie-rust checkout, the first preflight step
rebuilds `plushie-renderer` from source via
`cargo build --release -p plushie-renderer` and exports
`PLUSHIE_BINARY_PATH` so subsequent steps use the fresh binary.

Without `PLUSHIE_RUST_SOURCE_PATH` the existing binary resolution
(env var, downloaded artifact, custom build, sibling checkout) is
used unchanged.

```
PLUSHIE_RUST_SOURCE_PATH=../plushie-rust ./bin/preflight
```

## Commit hygiene

Every commit should be self-contained and functional. Preflight
should pass at each commit, not just at the tip.

Commits after `github/main` are unpublished and can be freely
amended, squashed, or reordered to keep the history clean. Run
`git fetch github` first to ensure the boundary is current. Use
`--amend` to fold small fixes into the commit they belong to
rather than creating "fix the fix" commits. If a later commit
fixes a bug introduced by an earlier unpublished commit, squash
them together.

Never amend or rebase commits that are already on `github/main`.

## Commit messages

Commit messages should describe what changed and why. Do not include:
- Counts of any kind (findings, files, tests, items). If the
  content is listed, the reader can count. Counts add noise.
- Ticket, review, or tracking IDs (R-001, PROJ-123, etc.)
- References to this file

More broadly, think carefully before including counts anywhere
(code comments, docs, log messages). If the count is derivable
from the surrounding content, it doesn't add value.

## Writing style

Do not use `--` (double dash) as a separator or em-dash substitute
in prose, docs, comments, or bullet lists. Use a single `-` for
list item separators and reword sentences to avoid inline dashes
(use commas, periods, colons, or parentheses instead). `--` should
only appear as part of CLI flag names (e.g. `--watch`, `--release`).

## Quick reference

```
./bin/preflight                         # run all CI checks locally
gleam test                              # compile + run tests (default: real binary)
gleam format                            # auto-format
gleam format --check                    # check formatting (CI mode)
gleam build                             # compile (BEAM, default)
gleam build --target=javascript         # compile (JS/WASM)
gleam run -m <module>                   # run an app entry point
gleam docs build                        # generate documentation
gleam add <package>                     # add a dependency
```

### Building the renderer binary

`gleam run -m plushie/build` generates a minimal virtual app crate
under `_build/plushie-renderer-spec/` (listing the project's native
widget crates as path deps) and shells out to `cargo-plushie build`.
`cargo-plushie` owns workspace generation, widget discovery, and
the cargo invocation; the SDK is a thin façade.

`cargo-plushie` is resolved in this order:

1. `PLUSHIE_RUST_SOURCE_PATH` set: invoked via
   `cargo run -p cargo-plushie ...` against the checkout.
2. `cargo-plushie` on PATH at the version pinned by
   `plushie_rust_version` in `gleam.toml`.
3. Fails with install instructions.

For local development, point at the sibling plushie-rust checkout:

```
PLUSHIE_RUST_SOURCE_PATH=../plushie-rust gleam run -m plushie/build
```

`gleam run -m plushie/download` downloads a precompiled release
binary for the pinned `plushie_rust_version`. Only used for released
packages, not local development.

#### Native widget metadata

Widget crates listed in `[plushie].native_widgets` must declare
`[package.metadata.plushie.widget]` in their own `Cargo.toml`
(`type_name`, `constructor`). `cargo plushie new-widget` scaffolds
this correctly. The `crate_path|constructor` shape in `gleam.toml`
is still parsed for migration compatibility but the constructor
field is redundant; the widget crate is the source of truth.

## Testing

### Philosophy

Tests must exercise the real renderer binary. The default backend
is `mock` which runs `plushie-renderer --mock` (real binary, real wire
protocol, real Core engine, just no GPU rendering). This catches
bugs that live at the boundary between the SDK and the renderer:
wire format drift, startup handshake ordering, codec issues, FFI
mismatches. A test that passes against a pure-Gleam substitute but
fails against the real binary is worse than no test; it hides
the exact class of bugs that matter most.

Effect stubs (registered with the renderer via
`register_effect_stub`) provide controlled responses for effects
the test environment can't handle (file dialogs, clipboard). Stubs
are the only acceptable mock mechanism: they operate at the
renderer level, not by bypassing the wire protocol.

### Test structure

Use `describe` blocks for organization. Do not add comment-based
section headers (e.g. `# --- new/1 ---`) before `describe` blocks
because the describe string already serves that purpose. Comment headers
are only appropriate before groups of `defmodule` definitions at
the top of a test file (separating test module setup from the tests
themselves).

### Backend selection

Tests run against the real renderer binary. The binary must be
built before running tests (see "Building the renderer binary"
above). If not found, tests fail immediately with setup
instructions.

```
gleam test                                  # default: mock (plushie-renderer --mock, pooled)
PLUSHIE_TEST_BACKEND=headless gleam test    # software rendering
```

For windowed tests (real GPU rendering), start headless weston:

```
export XDG_RUNTIME_DIR=$(mktemp -d)
weston -B headless --socket=plushie-test &
WAYLAND_DISPLAY=plushie-test XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  PLUSHIE_TEST_BACKEND=windowed gleam test
```

Backend names match the Elixir SDK: `mock`, `headless`, `windowed`.

### Test categories

- **Pure tests** (`test/plushie/`): widget builders, tree diff,
  protocol encode/decode, prop types. No runtime, no binary.
- **App tests** (`test/plushie/test_test.gleam`,
  `test/plushie/examples/`): use `testing.start()` which runs
  against the real binary via the session pool.
- **Integration tests** (`test/plushie/integration/`): use
  `plushie.start()` directly via `test/plushie/support.gleam` for
  runtime-level behavior (subscriptions, commands, event injection,
  effect stubs).

### Runtime state queries

`plushie.get_model(instance)` and `plushie.get_tree(instance)` query
a running runtime's state. `Instance(model)` is parameterized so
`get_model` returns the typed model directly, with no Dynamic coercion
needed at call sites.

`plushie.dispatch_event(instance, event)` injects an event into the
runtime's message loop, bypassing the renderer. Used by integration
tests to trigger state changes.

### Test support helpers

`test/plushie/support.gleam` provides `TestApp(model)` for
integration tests:

```
let rt = support.start(my_app, [])
let result = support.await(rt, fn(m) { m.count >= 3 }, 500)
support.stop(rt)
let assert Ok(_) = result
```

The owner process monitors the test process and self-terminates on
test failure, preventing resource leaks.

### Session pool behavior

The `testing.start()` facade shares a single renderer process across
all tests via the session pool. Eunit runs tests within a module in
the same process, so `start_pooled` sends a `reset` to clear the
previous test's renderer state before reusing the session. This
prevents widget state leaks between tests.

## Architecture

### Elm loop

```
init(app_opts) -> #(model, Command(msg))
update(model, msg) -> #(model, Command(msg))
view(model) -> Node
```

The runtime is generic over `msg`. For simple apps (msg = Event),
use `app.simple(init, update, view)`. For custom message types,
use `app.application(init, update, view, on_event)` which maps
Event -> msg at the dispatch boundary.

The runtime calls `view` after every `update`, normalizes the
tree (applies scoped IDs), diffs against the previous tree, and
sends patches to the Rust binary. Commands returned from `update`
are executed before the next view render.

### Process model

The runtime is an OTP-supervised process started via
`runtime.start_supervised()`. The bridge and runtime are both
supervised children under a RestForOne supervisor. It owns all
state:

- Creates its own Subjects inside the spawned process (critical
  for correct message delivery; Gleam Subjects can only be
  received by the process that created them)
- Starts the bridge actor (which manages the Erlang Port to the
  Rust binary)
- Runs the message loop: select from both its own Subject and
  the bridge notification Subject

The bridge is a thin pipe. It receives pre-encoded `BitArray`
from the runtime, writes to the port, decodes inbound port data,
and forwards events to the runtime. It does not encode messages
or manage application state. It supports three transport modes:
Spawn (default port), Stdio (stdin/stdout), and Iostream (custom).

### Encoding boundary

Widget builders encode typed Gleam values (Length, Color, Padding)
to `PropValue` primitives at `build()` time. By the time a Node
reaches the tree, its props are already wire-compatible. Tree
normalization only handles scoped IDs and a11y reference resolution.
Protocol encode serializes the PropValue tree to wire bytes.

Do not defer encoding to normalize or protocol encode. If you add
a new widget, encode all prop values inside `build()`.

### Bridge restart

When the Rust binary crashes (non-zero exit), the runtime
automatically restarts it with exponential backoff (100ms base,
5s cap, 5 max consecutive failures). On successful restart:
settings are re-sent, view is re-rendered as a fresh snapshot,
subscriptions and windows are re-synced, stale coalescable events
are discarded, and pending effects are failed with "renderer_restarted".
The app's model is preserved across restarts.

Clean exit (status 0) stops the runtime.

### Event coalescing

High-frequency events (mouse moves, sensor resizes) are deferred
and coalesced. Only the latest value per source is kept. A
zero-delay timer flushes them before the next non-coalescable event
is processed.

### Dev server

When `dev: True` is set in StartOpts, a dev server actor watches
`src/` for `.gleam` file changes, runs `gleam build` as a
subprocess, hot-loads changed BEAM modules via `code:purge` +
`code:load_file`, and signals the runtime to re-render via
`ForceRerender`. The app's model and state are preserved across
hot reloads.

## Invariants

Things that will break if violated:

- **Subject ownership**: all Subjects must be created inside the
  runtime's spawned process. Creating them outside causes messages
  to be delivered to the wrong mailbox.
- **Patch paths are List(Int)**: child index arrays like `[0, 2]`,
  not string IDs. The Rust binary expects integer arrays.
- **Settings nesting**: the settings wire message wraps fields
  under a `"settings"` key: `{type: "settings", settings: {...}}`.
- **Node kind -> "type"**: the `kind` field on Node maps to
  `"type"` on the wire. This happens in `node_to_prop_value`.
- **Prop directory**: property types live in `plushie/prop/`, not
  `plushie/type/`, because `type` is a reserved keyword in Gleam
  module paths. Similarly, test infrastructure lives in
  `plushie/testing/`, not `plushie/test/`, because `test` is reserved.
- **Async nonces**: every async/stream task carries a monotonic
  nonce. The runtime validates the nonce before dispatching results.
  Stale results from cancelled tasks are silently discarded.
- **Window detection depth**: the runtime recursively searches the
  entire tree for window nodes, matching the renderer's behavior.
- **Shaping prop key**: the wire key is `"shaping"` (not
  `"text_shaping"`). Rust and Elixir both use `"shaping"`.

## Module organization

```
src/
  plushie.gleam               # BEAM start/stop API (@target(erlang))
  plushie_web.gleam           # JS/WASM start/stop API (@target(javascript))
  plushie/
    app.gleam                 # App(model, msg) type, Settings, constructors
    platform.gleam            # cross-target FFI (logging, env, time, hashing)
    runtime.gleam             # BEAM Elm loop (OTP actor, @target(erlang))
    runtime_core.gleam        # shared pure Elm loop logic (both targets)
    runtime_web.gleam         # JS Elm loop (callbacks, @target(javascript))
    bridge.gleam              # BEAM port actor (@target(erlang) functions)
    bridge_web.gleam          # JS WASM transport (@target(javascript))
    renderer_port.gleam       # Erlang Port operations for renderer subprocess
    node.gleam                # PropValue (incl BinaryVal), Node types
    event.gleam               # Event union (scoped events use EventTarget)
    event/
      types.gleam             # shared types: EventTarget, Modifiers, PointerType, etc.
    command.gleam             # Command(msg) union (~50 constructors)
    command_encode.gleam      # Command -> WireOp classification for transport
    subscription.gleam        # Subscription types + diffing keys + max_rate
    tree.gleam                # normalize, diff, search, ID validation
    patch.gleam               # PatchOp type
    protocol.gleam            # Format, version, error types
    protocol/
      encode.gleam            # all outbound message encoders
      decode.gleam            # all inbound event decoders
    ui.gleam                  # typed per-widget Opt builders
    effect.gleam              # file dialogs, clipboard, notifications
    widget.gleam              # custom widget system (WidgetDef, registry, dispatch)
    native_widget.gleam       # native (Rust-backed) widget definitions
    binary.gleam              # Rust binary path resolution + download_dir
    build.gleam               # build renderer binary from source (CLI)
    download.gleam            # download precompiled renderer artifacts (CLI)
    config.gleam              # gleam.toml [plushie] section reader
    connect.gleam             # socket-based transport entry point
    socket_adapter.gleam      # gen_tcp <-> iostream bridge actor
    renderer_env.gleam        # secure env for renderer port
    key.gleam                 # ~300 keyboard key constants
    telemetry.gleam           # erlang :telemetry (no-op on JS)
    dev_server.gleam          # file watcher + hot reload
    gui.gleam                 # local desktop app entry point (CLI)
    stdio.gleam               # exec/remote rendering entry point (CLI)
    inspect.gleam             # print UI tree as JSON (CLI)
    script.gleam              # .plushie test script runner (CLI)
    replay.gleam              # .plushie script replay with timing (CLI)
    cli_helpers.gleam         # binary/source path resolution for CLIs
    animation/
      tween.gleam             # SDK-side frame-based interpolation
      easing.gleam            # named easing curves + cubic bezier
      transition.gleam        # renderer-side timed transition descriptors
      spring.gleam            # renderer-side physics-based springs
      sequence.gleam          # sequential animation chains
    route.gleam               # navigation stack
    selection.gleam           # single/multi/range selection
    undo.gleam                # undo/redo stack with coalescing
    data.gleam                # query pipeline (filter/search/sort/page)
    transport/
      framing.gleam           # wire framing for non-port transports
    testing.gleam             # test facade (start, click, find, etc.)
    testing/
      session.gleam           # TestSession opaque type, Elm loop runner
      element.gleam           # Element query wrapper for Node
      backend.gleam           # TestBackend record-of-functions type
      command_processor.gleam # synchronous command execution for tests
      event_decoder.gleam     # wire event family -> Event mapping
      renderer.gleam          # OTP actor wrapping Port to Rust binary
      session_pool.gleam      # shared renderer for parallel tests
      snapshot.gleam          # JSON tree snapshot golden files
      tree_hash.gleam         # SHA-256 structural tree hash
      screenshot.gleam        # pixel screenshot capture + PNG encoding
      widget_harness.gleam    # isolated widget test harness
      script.gleam            # .plushie script parser
      script/
        runner.gleam          # script executor (instruction dispatch)
      backend/
        headless.gleam        # --headless backend (software rendering)
        windowed.gleam        # real iced windows (needs display server)
        mock.gleam            # --mock backend (protocol only, no rendering)
        session_backend.gleam # pure in-memory session backend (no renderer)
    canvas/
      shape.gleam             # drawing primitives, paths, transforms
    prop/                     # shared property types
      a11y.gleam, alignment.gleam, anchor.gleam, border.gleam,
      color.gleam, content_fit.gleam, direction.gleam,
      filter_method.gleam, font.gleam, gradient.gleam, length.gleam,
      padding.gleam, pointer.gleam, position.gleam, shadow.gleam,
      shaping.gleam, style_map.gleam, theme.gleam, wrapping.gleam
    widget/                   # per-widget typed builders
      build.gleam             # shared builder helpers
      button.gleam, canvas.gleam, checkbox.gleam, column.gleam,
      combo_box.gleam, container.gleam, floating.gleam, grid.gleam,
      image.gleam, keyed_column.gleam, markdown.gleam, overlay.gleam,
      pane_grid.gleam, pick_list.gleam, pin.gleam,
      pointer_area.gleam, progress_bar.gleam, qr_code.gleam,
      radio.gleam, responsive.gleam, rich_text.gleam, row.gleam,
      rule.gleam, scrollable.gleam, sensor.gleam, slider.gleam,
      space.gleam, stack.gleam, svg.gleam, table.gleam, text.gleam,
      text_editor.gleam, text_input.gleam, themer.gleam,
      toggler.gleam, tooltip.gleam, vertical_slider.gleam,
      window.gleam
  # FFI: JavaScript (.mjs)
  plushie_platform_ffi.mjs     # JS: logging, env, time, hashing, math
  plushie_bridge_web_ffi.mjs   # JS: WASM renderer interop
  plushie_runtime_web_ffi.mjs  # JS: mutable state, timers, async
  # FFI: Erlang (.erl)
  plushie_ffi.erl              # BEAM: port ops, telemetry, identity
  plushie_build_ffi.erl        # cargo/rustc helpers for build.gleam
  plushie_config_ffi.erl       # TOML config reader
  plushie_connect_ffi.erl      # socket connect CLI helpers
  plushie_dev_server_ffi.erl   # file watcher, module reload helpers
  plushie_download_ffi.erl     # HTTP download, flag parsing
  plushie_example_clock_ffi.erl # localtime helper for clock example
  plushie_renderer_env_ffi.erl # env var helpers
  plushie_screenshot_ffi.erl   # binary file write for screenshots
  plushie_snapshot_ffi.erl     # atomic file write for snapshots
  plushie_socket_adapter_ffi.erl # gen_tcp operations for socket adapter
  plushie_test_cleanup_ffi.erl # test cleanup helpers
  plushie_test_ffi.erl         # test harness FFI (stream collection, coerce)
  plushie_test_pool_ffi.erl    # pool session monitoring
  plushie_test_pooled_ffi.erl  # pooled backend mailbox ops
  plushie_test_renderer_ffi.erl # renderer process dict, wire deser
examples/
  counter.gleam, todo_app.gleam, clock.gleam, async_fetch.gleam,
  shortcuts.gleam, notes.gleam, color_picker.gleam, rate_plushie.gleam
  widgets/
    color_picker_widget.gleam, star_rating.gleam, theme_toggle.gleam
docs/
  README.md
  guides/
    01-introduction.md, 02-getting-started.md, 03-your-first-app.md,
    04-the-development-loop.md, 05-events.md, 06-lists-and-inputs.md,
    07-layout.md, 08-styling.md, 09-animation.md, 10-subscriptions.md,
    11-async-and-effects.md, 12-canvas.md, 13-custom-widgets.md,
    14-state-management.md, 15-testing.md, 16-shared-state.md
  reference/
    accessibility.md, animation.md, app-lifecycle.md,
    built-in-widgets.md, canvas.md, commands.md,
    composition-patterns.md, configuration.md, custom-widgets.md,
    events.md, scoped-ids.md, subscriptions.md, testing.md,
    themes-and-styling.md, windows-and-layout.md, wire-protocol.md
bin/
  preflight, plushie-renderer
```

## Multi-target support (BEAM + JavaScript)

The codebase compiles for both `erlang` and `javascript` targets.
The pure layer (~80 modules: widgets, props, tree, protocol,
events, commands) works on both targets unchanged.

BEAM-specific modules (runtime, bridge, ffi, testing backends,
CLI) use `@target(erlang)` on public items. JS-specific modules
(runtime_web, bridge_web, plushie_web) use `@target(javascript)`.

Cross-target FFI lives in `plushie/platform.gleam` with dual
`@external(erlang, ...)` / `@external(javascript, ...)` annotations.
BEAM-only port operations stay in `plushie/ffi.gleam`.

Naming convention:
- `_web` suffix: JavaScript/WASM-specific modules
- No suffix on BEAM modules (they predate the JS target)
- `platform.gleam`: shared cross-target utilities

Build both targets:
```
gleam build                    # BEAM (default)
gleam build --target=javascript  # JS/WASM
```

## Design principles

### Use the type system aggressively

Prefer compile-time safety over runtime flexibility:

- Events are a flat union type with typed fields per variant
- Commands are a parameterized union type
- Widget props are typed per-widget via opaque builder types
- Lengths, colors, paddings, alignments are proper types
- Invalid states should be unrepresentable

### No Dynamic unless forced by the wire

`Dynamic` is for the wire boundary (decode.gleam), async
result payloads, and app_opts. Internal code should never pass
`Dynamic`.

### No general-purpose type coercion

Never write `fn coerce(value: a) -> b` or
`fn unsafe_coerce(value: a) -> b`. These bypass the type system
entirely and make bugs invisible.

When type information must cross a boundary (process messages,
FFI, Dynamic payloads), use a narrow function with a specific
type signature that documents exactly what boundary it crosses:

- `fn event_to_msg(value: Event) -> msg`: for the simple app
  invariant where msg = Event but the type system can't prove it
- `fn from_dynamic(value: Dynamic) -> a`: narrowing a Dynamic
  received from a process reply back to a known type
- `fn model_to_dynamic(value: a) -> Dynamic`: widening a typed
  model for a reply channel that carries Dynamic

Each of these is private, has one or two call sites, and the name
explains why it exists. If you find yourself needing a general
coerce, the types upstream should be parameterized to carry the
information instead.

### Result types, not panics

Use `Result` for operations that can fail. Use `panic`/`todo`
only for genuinely unreachable states.

### Builder pattern for widgets

Two layers:
- `plushie/ui.gleam`: convenience functions with per-widget typed
  `Opt` lists (`ui.button("id", "label", [button.Width(Fill)])`)
- `plushie/widget/*.gleam`: typed opaque builders with chainable
  setters (`button.new("id", "label") |> button.width(Fill) |> button.build()`)

### Follow Gleam conventions

- snake_case for everything
- Modules map to file paths
- Custom types for enums, not strings
- Qualified imports for clarity
- Pipeline operator for data transformations

## Wire protocol

The canonical protocol spec is at `../plushie-rust/docs/protocol.md`.
That document is the source of truth for all message types, event
families, and interaction semantics.

## Dependencies

- gleam_stdlib, gleam_erlang, gleam_otp, gleam_json
- glepack (MessagePack codec, Gleam-native)
- telemetry (erlang :telemetry for observability)
- file_system (file watcher for dev server hot reload)
- gleeunit (test, dev only)

## Reference SDK

The plushie Rust SDK (`../plushie-rust/crates/plushie/`) is the
primary reference for Gleam due to similar type system conventions.
The plushie-elixir SDK (`../plushie-elixir/`) is the overall
reference implementation and defines the wire protocol. Consult
both when adding features or debugging wire format issues.

## Related repositories

These are expected as sibling directories (e.g. `../plushie-rust/`):

- plushie-rust - Rust workspace (SDK, widget SDK, renderer)
- plushie-elixir - Elixir SDK (reference implementation)
- plushie-iced - vendored iced fork
