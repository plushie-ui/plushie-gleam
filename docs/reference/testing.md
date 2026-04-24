# Testing

Plushie tests run against the real renderer binary by default so
the wire protocol, widget callbacks, and effect plumbing are all
exercised end to end. The facade lives in `plushie/testing`, with
helpers for assertions, tree hashing, screenshots, effect stubs,
and scripted automation under `plushie/testing/*`.

For a narrative introduction, see the
[Testing guide](../guides/15-testing.md).

## Testing philosophy

Tests fall into three categories:

- **Pure tests** for widget builders, tree diff, protocol
  encode / decode, and prop types. No runtime, no binary. Live in
  `test/plushie/` and use plain `gleeunit`.
- **App tests** driven through `plushie/testing`. Each test owns a
  `TestContext`, runs the Elm loop against the real renderer via
  the shared session pool, and inspects model, tree, and element
  state. Live in `test/plushie/examples/` and similar.
- **Integration tests** driven through `test/plushie/support.gleam`.
  These start the full supervisor tree (bridge + runtime +
  renderer) with `plushie.start` and exercise runtime-level
  behaviors: subscriptions, commands, coalescing, effect stubs,
  and event injection via `plushie.dispatch_event`.

App tests default to the `mock` backend: the real renderer binary
launched with `--mock`. That means real wire codecs, real handshake
ordering, real widget callbacks, just no GPU. The default catches
the class of bugs that matter most (wire format drift, FFI
mismatches, handshake ordering) without requiring a display server.

Tests that must not depend on the binary (the pure-session path on
JavaScript, for instance) run through the same facade. On the
JavaScript target, `testing.start` swaps in an in-memory session
backend that executes the app's init / update / view cycle
directly without a subprocess.

## Backend selection

The backend is resolved once when `testing.start` is called and
carried through the `TestContext`. Select via the
`PLUSHIE_TEST_BACKEND` environment variable:

```bash
gleam test                                  # default: mock
PLUSHIE_TEST_BACKEND=headless gleam test    # software rendering
```

Set `PLUSHIE_TEST_TIMEOUT` to a positive integer to scale test
infrastructure waits on slower machines or loaded CI runners.

| Backend | Process | Rendering | Screenshots | Effects |
|---|---|---|---|---|
| `mock` | `plushie-renderer --mock` (pooled) | Protocol only | Hash only | Stubs only |
| `headless` | `plushie-renderer --headless` (pooled) | Software | Pixel | Stubs only |
| `windowed` | `plushie-renderer` daemon per session | GPU | Pixel | Real |

The windowed backend requires a display server. On a headless
host, run behind a weston socket:

```bash
export XDG_RUNTIME_DIR=$(mktemp -d)
weston -B headless --socket=plushie-test &
WAYLAND_DISPLAY=plushie-test XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  PLUSHIE_TEST_BACKEND=windowed gleam test
```

The renderer binary must already exist before tests run. If not,
the backend panics with setup instructions. See the
[CLI Commands reference](cli-commands.md) for `plushie/build` and
`plushie/download`.

## Session lifecycle

`plushie/testing` exposes an opaque `TestContext(model)`
parameterized on the app's model type. The context bundles a
session with its backend so subsequent helpers don't re-resolve
either:

| Function | Signature | Description |
|---|---|---|
| `start` | `fn(App(model, Event)) -> TestContext(model)` | Start a session against the resolved backend |
| `stop` | `fn(TestContext(model)) -> Nil` | Release the session back to the pool |
| `model` | `fn(TestContext(model)) -> model` | Current app model |
| `tree` | `fn(TestContext(model)) -> Node` | Current normalized tree |
| `send_event` | `fn(TestContext(model), Event) -> TestContext(model)` | Dispatch an `Event` straight through `update` |

`start` only accepts apps whose message type is `Event`. For apps
built with `app.application(init, update, view, on_event)`, test
them via the `on_event` shape or use the integration harness
(below).

```gleam
import gleam/option
import gleeunit/should
import plushie/testing

pub fn increment_test() {
  let ctx = testing.start(counter.app())
  let ctx = testing.click(ctx, "increment")
  let assert option.Some(el) = testing.find(ctx, "count")
  testing.element_text(el) |> should.equal(option.Some("Count: 1"))
  testing.stop(ctx)
}
```

## Interactions

All interactions return a new `TestContext` with the updated
session. They are synchronous: the function returns after the
update cycle (and any commands it produced) has settled.

| Function | Widget types | Event produced |
|---|---|---|
| `click(ctx, id)` | button, anything clickable | `Widget(Click)` |
| `type_text(ctx, id, text)` | text_input, text_editor | `Widget(Input)` |
| `submit(ctx, id)` | text_input | `Widget(Submit)` |
| `toggle(ctx, id)` | checkbox, toggler | `Widget(Toggle)` |
| `select(ctx, id, value)` | pick_list, combo_box, radio | `Widget(Select)` |
| `slide(ctx, id, value)` | slider, vertical_slider | `Widget(Slide)` |
| `paste(ctx, id, text)` | text_input, text_editor | `Widget(Paste)` |
| `sort(ctx, id, column)` | table | `Widget(Sort)` |
| `canvas_press(ctx, id, x, y)` | canvas | `Widget(Press)` (mouse) |
| `canvas_touch_press(ctx, id, x, y, finger)` | canvas | `Widget(Press)` (touch) |
| `canvas_touch_release(ctx, id, x, y, finger)` | canvas | `Widget(Release)` (touch) |
| `canvas_touch_move(ctx, id, x, y, finger)` | canvas | `Widget(Move)` (touch) |
| `press_key(ctx, key)` | n/a | `Key(KeyEvent)` |
| `release_key(ctx, key)` | n/a | `Key(KeyEvent)` |
| `type_key(ctx, key)` | n/a | press + release |

The `id` argument is a plain widget ID, a scoped path, or a
window-qualified path. Interactions route through the backend:
on the pooled backends they ship a wire-level interact message
and wait for the renderer's update response; on the session
backend (JavaScript) they synthesize the corresponding `Event`
and thread it through `update`.

### Key names

Key strings are forwarded to the renderer untouched. The renderer
normalizes case, whitespace, and separators, and recognizes the
usual aliases (`"ctrl+s"`, `"Shift+Left_Arrow"`, `"escape"`,
`"ArrowLeft"`, `"F4"`, ...). Use the constants from `plushie/key`
when you want compile-time spell-checking.

## Selectors and element queries

`testing.find(ctx, selector)` accepts a unified string syntax
that covers ID, attribute, and focus selectors. It returns
`Option(Element)` where `Element` wraps a tree `Node`.

| Form | Matches |
|---|---|
| `"save"` or `"#save"` | Widget with ID `"save"` |
| `"form/save"` | Scoped path |
| `"main#save"` | Widget in a specific window |
| `"main#form/save"` | Scoped path in a specific window |
| `":focused"` | Currently focused widget |
| `"main#:focused"` | Focused widget inside window `"main"` |
| `"[role=button]"` | Widget with accessibility role |
| `"[label=Name]"` | Widget with accessibility label |
| `"[text=Save]"` | Widget whose content / label / value / placeholder matches |

String selectors are parsed by `backend.parse_selector` into a
typed `backend.Selector`:

```gleam
pub type Selector {
  ById(String)
  ByRole(String)
  ByLabel(String)
  ByText(String)
  Focused
  InWindow(window_id: String, selector: Selector)
}
```

For typed lookup, call `testing.find_by(ctx, selector)` with a
`Selector` value directly.

`testing.find` delegates `ById` lookups to the backend (the
pooled backends query the renderer for the real scoped ID);
semantic selectors (`ByRole`, `ByLabel`, `ByText`, `Focused`)
walk the current tree in-process.

### Element accessors

`plushie/testing/element` defines the `Element` wrapper and query
helpers. The facade re-exports the common ones:

| Function | Description |
|---|---|
| `testing.element_text(el)` | `content` \| `label` \| `value` \| `placeholder`, whichever is present |
| `testing.element_prop(el, key)` | Raw `PropValue` for any prop |
| `testing.element_children(el)` | Child elements |

Direct module helpers cover the rest: `element.id`, `element.kind`,
`element.has_children`, `element.child_at`, `element.find_within`,
`element.find_all`, `element.a11y`, `element.resolved_a11y`,
`element.local_id`.

## Assertions

The facade ships a small set of assertion helpers that panic on
mismatch (the standard Gleam testing pattern). All return the
context unchanged so they compose with interactions in a single
pipeline.

| Function | Description |
|---|---|
| `assert_exists(ctx, selector)` | Selector matches something in the tree |
| `assert_not_exists(ctx, selector)` | Selector matches nothing |
| `assert_text(ctx, selector, expected)` | Element text equals `expected` |
| `assert_a11y(ctx, selector, expected)` | Every key / value in `expected` appears in the resolved a11y dict |
| `resolved_a11y(ctx, selector)` | Returns the resolved a11y dict for direct inspection |

`resolved_a11y` layers render-pipeline inference (e.g.
placeholder becomes description on text-entry widgets, alt
becomes label on media widgets) on top of the explicit `a11y`
prop, so the assertion reflects what assistive technology sees.

For structural and pixel assertions, use the snapshot, tree
hash, and screenshot helpers below.

## Frame advancement

`testing.advance_frame(ctx, timestamp)` dispatches an
`AnimationFrame` event directly through `update`, advancing any
SDK-side tweens or spring simulations to the given monotonic
timestamp. It is a no-op on the headless and windowed backends:
the renderer generates its own animation frames there.

For renderer-side transitions, `command.advance_frame` (from the
[Commands reference](commands.md)) sends the timestamp over the
wire to step the renderer's clock.

## Integration tests

`test/plushie/support.gleam` provides a richer harness for tests
that need runtime-level behavior: subscriptions, command
dispatch, coalescing, effect stubs, and event injection into a
real supervisor tree. The harness type is `TestApp(model)`:

```gleam
import plushie/event.{Widget, Click, EventTarget}
import test/plushie/support

pub fn increments_on_click_test() {
  let rt = support.start(counter.app(), [])
  support.dispatch_event(
    rt,
    Widget(Click(target: EventTarget(
      id: "increment",
      scope: [],
      window_id: "main",
      full: "main#increment",
    ))),
  )
  let assert Ok(_) = support.await(rt, fn(m) { m.count >= 1 }, 500)
  support.stop(rt)
}
```

| Function | Description |
|---|---|
| `support.start(app, extra_args)` | Start a full supervisor. `extra_args` appends to the renderer command line; the harness always prepends `--mock` |
| `support.stop(rt)` | Stop the supervisor. Panics if prop validation warnings accumulated |
| `support.model(rt)` | Typed model snapshot |
| `support.tree(rt)` | Current normalized tree (if any) |
| `support.dispatch_event(rt, event)` | Inject an event into the runtime's mailbox |
| `support.register_effect_stub(rt, kind, response)` | Install an effect stub on the renderer |
| `support.unregister_effect_stub(rt, kind)` | Remove a stub |
| `support.await(rt, predicate, timeout_ms)` | Poll the model every 10 ms until `predicate` passes |
| `support.quiet_logs(f)` / `support.mute_logs(f)` | Run `f` with the logger level temporarily lowered |

The harness owner process monitors the test process and
self-terminates on test death, so failed tests do not leak the
60-second stop timeout.

## Effect stubs

Effect stubs are the only sanctioned mock mechanism. They operate
at the renderer level, not by bypassing the wire protocol, so the
full encode / decode path is still exercised. A stub registers by
effect **kind** (not tag) and applies to every effect of that
kind until unregistered. Stub kinds are limited to the platform
effects exposed by `plushie/effect`: `file_open`,
`file_open_multiple`, `file_save`, `directory_select`,
`directory_select_multiple`, `clipboard_read`, `clipboard_write`,
`clipboard_read_html`, `clipboard_write_html`, `clipboard_clear`,
`clipboard_read_primary`, `clipboard_write_primary`, and
`notification`.

From the integration harness:

```gleam
import plushie/node

support.register_effect_stub(
  rt,
  "file_open",
  node.StringVal("/tmp/report.txt"),
)
```

From the facade's underlying instance (use
`plushie.register_effect_stub` against the `Instance(model)` if
you already have one). Both calls block until the renderer
acknowledges. The response is returned as an `EffectOk` payload;
to simulate a cancelled dialog, dispatch an
`Effect(EffectEvent(result: EffectCancelled))` via
`support.dispatch_event` instead.

## Snapshots, tree hashes, and screenshots

These live in `plushie/testing/snapshot`,
`plushie/testing/tree_hash`, and `plushie/testing/screenshot`.

### JSON tree snapshots

`snapshot.assert_tree_snapshot(tree, name, path)` serializes the
tree to deterministic JSON (sorted keys, recursive), compares it
to a stored golden under `path/<name>.json`, and panics on
mismatch. The first run writes the golden file.

### Structural tree hashes

`tree_hash.hash(tree)` returns a SHA-256 hex digest of the same
canonical JSON form. `tree_hash.assert_tree_hash(tree, name, path)`
compares against `path/<name>.sha256`. Hash mismatches surface
the current and stored digests in the panic message so CI output
points at the drift.

### Pixel screenshots

`screenshot.Screenshot(name, hash, width, height, pixels)` is
produced by the headless and windowed backends. The mock backend
returns `screenshot.empty(name)` with no pixel data.

- `screenshot.assert_screenshot(s, name, path)` compares the
  hash against `path/<name>.sha256`. Empty-hash screenshots
  (mock) are silently accepted so the same test passes on every
  backend.
- `screenshot.save_png(s, path)` encodes raw RGBA as a minimal
  valid PNG using Erlang's `:zlib` and `:erlang.crc32`. A no-op
  for empty stubs.

### Updating goldens

Set the matching environment variable to overwrite the golden
file instead of asserting:

```bash
PLUSHIE_UPDATE_SNAPSHOTS=1 gleam test     # JSON snapshots + tree hashes
PLUSHIE_UPDATE_SCREENSHOTS=1 gleam test   # pixel screenshot hashes
```

Snapshots and tree hashes share the `PLUSHIE_UPDATE_SNAPSHOTS`
flag because both are derived from the same serialized tree.

## Session pool

On BEAM, `testing.start()` lazily starts a `SessionPool` actor
and reuses it for every subsequent test in the process. The pool
owns a single renderer port and multiplexes sessions over it via
session IDs; responses are demuxed by the `session` field on the
wire.

`plushie/testing/session_pool.PoolConfig` governs the pool:

| Field | Type | Default |
|---|---|---|
| `mode` | `PoolMode` (`Mock` / `Headless`) | `Mock` |
| `format` | `protocol.Format` | `Msgpack` |
| `max_sessions` | `Int` | `8` |
| `renderer_path` | `Option(String)` | `None` (auto-resolve) |

Eunit runs every test in the same module in a single process, so
the pool sends a `reset` to the renderer when a session is
reused. This clears widget state between tests and prevents
cross-test leaks without paying for a fresh subprocess each
time.

For parallel tests, each session has its own ID and state on the
renderer side; the pool routes and demultiplexes automatically.
The windowed backend is not a pool mode: it spawns a dedicated
renderer daemon per session.

## Widget harness

`plushie/testing/widget_harness` wraps a custom widget in a
minimal host app (window > column > widget) for isolated testing.
The harness model records every non-framework event the widget
emits so the test can assert on emitted output.

```gleam
import plushie/testing
import plushie/testing/widget_harness

pub fn clicking_star_emits_select_test() {
  let app =
    widget_harness.harness(
      "stars",
      star_rating.def(),
      StarProps(rating: 3, max: 5),
    )
  let ctx = testing.start(app)
  let ctx = testing.canvas_press(ctx, "stars", 50.0, 10.0)
  let events = widget_harness.events(testing.model(ctx))
  // assert on events...
  testing.stop(ctx)
}
```

| Function | Description |
|---|---|
| `harness(id, def, props)` | Build a harness app hosting the widget |
| `events(model)` | Captured events, newest first |
| `last_event(model)` | Most recent event, or `Error(Nil)` |
| `has_event(model, predicate)` | Whether any captured event matches |

The harness filters canvas framework events (`Focused`,
`Blurred`, `Enter`, `Exit`) so assertions focus on the widget's
semantic output.

## `.plushie` scripts

`.plushie` is a declarative script format for automation and
smoke tests. A header section (`app`, `viewport`, `theme`,
`backend`) is separated from the instruction list by a line of
five dashes:

```
app: my_app
viewport: 800x600
theme: dark
backend: mock
-----
click "#increment"
expect "Count: 1"
tree_hash "counter-at-1"
```

Supported instructions:

| Instruction | Description |
|---|---|
| `click SELECTOR` | Click a widget |
| `toggle SELECTOR` | Toggle a checkbox / toggler |
| `select SELECTOR VALUE` | Select a value |
| `slide SELECTOR VALUE` | Move a slider |
| `type SELECTOR TEXT` | Type into a widget |
| `type KEY` | Press and release a key |
| `press KEY` | Key down |
| `release KEY` | Key up |
| `move X,Y` or `move TARGET` | Cursor move |
| `wait MS` | Pause |
| `expect TEXT` | Assert text appears somewhere in the tree |
| `assert_text SELECTOR TEXT` | Assert widget text |
| `assert_model EXPR` | Assert against the model |
| `tree_hash NAME` | Capture / compare a tree hash |
| `screenshot NAME` | Capture / compare a screenshot |

Parsing lives in `plushie/testing/script`; execution lives in
`plushie/testing/script/runner`. The library entry points that
wrap them are `plushie/script` (headless run via the mock
backend) and `plushie/replay` (windowed replay with real timing).
See the [CLI Commands reference](cli-commands.md#plushiescript)
for wiring them into your app.

## CI patterns

`bin/preflight` is the canonical local check. It runs the same
steps CI runs, in order:

1. `gleam format --check`
2. `gleam build`
3. `gleam build --target=javascript` (source-only)
4. `gleam test` (mock backend)
5. `PLUSHIE_TEST_BACKEND=headless gleam test`

The `[error]` and `[warning]` lines in test output are bugs, not
expected noise: they indicate log output leaking from a test
that should be capturing it.

For a windowed run in CI, start weston in the background under a
temporary runtime directory, export `WAYLAND_DISPLAY`, and set
`PLUSHIE_TEST_BACKEND=windowed` before invoking `gleam test`.

## See also

- [Commands reference](commands.md) - effect lifecycle and the
  commands exercised by integration tests
- [Events reference](events.md) - event shapes that
  `dispatch_event` and `send_event` deliver
- [Configuration reference](configuration.md) - `PoolConfig`,
  backend environment variables, and snapshot update flags
- [CLI Commands reference](cli-commands.md) - `plushie/script`,
  `plushie/replay`, and `bin/preflight`
- [Custom Widgets reference](custom-widgets.md) - testing widgets
  with the widget harness
