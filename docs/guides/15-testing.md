# Testing

Plushie tests exercise the real renderer binary. Every test starts a
full application instance (runtime, bridge, and renderer) and drives
it through the same wire protocol a real user session uses. That
catches the bugs that hide at the boundary between the SDK and the
renderer: wire format drift, startup handshake ordering, codec
issues, widget callback plumbing.

This chapter covers the testing framework and applies it to the pad.

## Setup

Plushie tests use `gleeunit` as the test runner, which is the
default for any Gleam project. In `test/<your_app>_test.gleam`:

```gleam
import gleeunit

pub fn main() {
  gleeunit.main()
}
```

There is no separate test setup step. The `plushie/testing` facade
resolves the backend, starts the renderer session pool lazily, and
registers cleanup hooks the first time a test calls
`testing.start`.

Tests run against the `mock` backend by default. The mock backend
launches the real renderer binary with `--mock`, so real wire codecs
and real handshake ordering are exercised. It skips GPU rendering,
which keeps tests fast.

The renderer binary must exist before tests run. Build it from a
sibling plushie-rust checkout or download a precompiled artifact:

```bash
gleam run -m plushie/build        # build from source
gleam run -m plushie/download     # download precompiled
```

## Starting a session

`testing.start` creates a `TestContext` bundling a session with its
backend. The context is threaded through every helper so the
backend is resolved once and the model type flows through:

```gleam
import gleeunit/should
import plushie/testing

pub fn initial_state_test() {
  let ctx = testing.start(plushie_pad.app())
  should.equal(testing.model(ctx).event_log, [])
  testing.stop(ctx)
}
```

`testing.start` expects an `App(model, Event)`. Apps built with
`app.simple(init, update, view)` fit directly. Apps built with
`app.application(init, update, view, on_event)` use a custom `msg`
type and need the integration harness (below) instead.

`testing.stop` releases the session back to the pool.

## Interactions

Interaction helpers take the `TestContext` and return a new one with
the update cycle fully settled. You chain them like any other
pipeline:

```gleam
let ctx =
  testing.start(plushie_pad.app())
  |> testing.type_text("editor", "defmodule Pad.Test do end")
  |> testing.click("save")

should.equal(testing.model(ctx).dirty, False)
testing.stop(ctx)
```

Each helper targets a widget by ID. Use the plain local ID
(`"save"`), a scoped path (`"form/save"`), or a window-qualified
path (`"main#save"`). The renderer resolves scoped IDs for you.

| Helper | Widget |
|---|---|
| `click(ctx, id)` | button or anything clickable |
| `type_text(ctx, id, text)` | text_input, text_editor |
| `submit(ctx, id)` | text_input (Enter) |
| `toggle(ctx, id)` | checkbox, toggler |
| `select(ctx, id, value)` | pick_list, combo_box, radio |
| `slide(ctx, id, value)` | slider, vertical_slider |
| `paste(ctx, id, text)` | text_input, text_editor |
| `sort(ctx, id, column)` | table |
| `canvas_press(ctx, id, x, y)` | canvas (mouse) |
| `canvas_touch_press(ctx, id, x, y, finger)` | canvas (touch) |

Keyboard helpers ignore the widget argument: keys route through the
global focus / key subscription path.

| Helper | Description |
|---|---|
| `press_key(ctx, key)` | Key down |
| `release_key(ctx, key)` | Key up |
| `type_key(ctx, key)` | Press and release |

Key strings are forwarded to the renderer untouched. The renderer
recognizes the usual aliases: `"ctrl+s"`, `"Shift+Left_Arrow"`,
`"escape"`, `"ArrowLeft"`, `"F4"`. Import the constants from
`plushie/key` when you want compile-time spell-checking.

All interactions are synchronous. They wait for the full update
cycle (event -> update -> view -> patch) and any commands it
produced before returning.

## Assertions

The assertion helpers panic on mismatch and return the context
unchanged so they compose inside an interaction pipeline:

```gleam
testing.start(plushie_pad.app())
|> testing.click("save")
|> testing.assert_exists("preview")
|> testing.assert_not_exists("error")
|> testing.stop
```

| Helper | Description |
|---|---|
| `assert_exists(ctx, selector)` | Selector matches at least one widget |
| `assert_not_exists(ctx, selector)` | Selector matches nothing |
| `assert_text(ctx, selector, expected)` | Widget text equals `expected` |
| `assert_a11y(ctx, selector, pairs)` | Every pair is present in the resolved a11y dict |

For model assertions, pipe through `testing.model` and use
`should` or a plain pattern match:

```gleam
let ctx = testing.click(ctx, "increment")
should.equal(testing.model(ctx).count, 1)
```

## Element queries

`testing.find` returns `Option(Element)` for ad-hoc inspection. The
selector string also accepts `":focused"`, `"[role=button]"`,
`"[label=Save]"`, and `"[text=Save]"` for semantic lookup. See the
[Testing reference](../reference/testing.md) for the full table.

## Applying it: test the pad

The pad saves the editor buffer and renders its output into the
preview pane. The save button and Ctrl+S trigger the same update,
so both paths deserve tests:

```gleam
import gleeunit/should
import plushie/testing

pub fn save_updates_preview_test() {
  let source = "ui.text_(\"t\", \"Test passed\")"

  testing.start(plushie_pad.app())
  |> testing.type_text("editor", source)
  |> testing.click("save")
  |> testing.assert_not_exists("error")
  |> testing.assert_text("preview", "Test passed")
  |> testing.stop
}

pub fn ctrl_s_saves_test() {
  let ctx =
    testing.start(plushie_pad.app())
    |> testing.type_text("editor", "// edited")
    |> testing.press_key("ctrl+s")

  should.equal(testing.model(ctx).dirty, False)
  testing.stop(ctx)
}

pub fn ctrl_z_undoes_last_edit_test() {
  let ctx =
    testing.start(plushie_pad.app())
    |> testing.type_text("editor", "first")
    |> testing.type_text("editor", "second")
    |> testing.press_key("ctrl+z")

  should.equal(testing.model(ctx).source, "first")
  testing.stop(ctx)
}
```

Gleeunit picks up any public function ending in `_test` and runs
it. Each test owns its context and is responsible for calling
`testing.stop`.

## Effect stubs

Effects (file dialogs, clipboard, notifications) open real OS
dialogs by default. For tests, register a stub that returns a
controlled response instead. Stubs register by effect **kind**, not
tag, so one stub handles every effect of that kind until removed.

Stubs are available from the integration harness (below). To test
the pad's import flow, for instance:

```gleam
import gleam/dict
import plushie/node.{DictVal, StringVal}
import plushie/support

pub fn import_loads_from_file_test() {
  let rt = support.start(plushie_pad.app(), [])

  let assert Ok(_) =
    support.register_effect_stub(
      rt,
      "file_open",
      DictVal(dict.from_list([
        #("path", StringVal("/tmp/hello.gleam")),
        #("contents", StringVal("// imported")),
      ])),
    )

  support.dispatch_event(rt, import_click_event())
  let assert Ok(_) = support.await(rt, fn(m) { m.active_file != None }, 500)
  support.stop(rt)
}
```

The stub responds immediately with the configured payload. The full
encode / decode path still runs, so wire mismatches still surface.

## Backends

| Backend | Process | Rendering | Screenshots | Effects |
|---|---|---|---|---|
| `mock` | `plushie-renderer --mock` (pooled) | Protocol only | Hash only | Stubs only |
| `headless` | `plushie-renderer --headless` (pooled) | Software | Pixel | Stubs only |
| `windowed` | `plushie-renderer` daemon per session | GPU | Pixel | Real |

Select the backend with the `PLUSHIE_TEST_BACKEND` environment
variable. Tests are backend-agnostic: the same test code runs on
all three.

```bash
gleam test                                  # default: mock
PLUSHIE_TEST_BACKEND=headless gleam test    # software rendering
```

The windowed backend needs a display server. On a headless host,
run behind a weston socket:

```bash
export XDG_RUNTIME_DIR=$(mktemp -d)
weston -B headless --socket=plushie-test &
WAYLAND_DISPLAY=plushie-test XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  PLUSHIE_TEST_BACKEND=windowed gleam test
```

## Snapshots, tree hashes, and screenshots

Plushie ships three regression tools for structural and visual
drift, all under `plushie/testing`:

```gleam
import plushie/testing
import plushie/testing/snapshot
import plushie/testing/tree_hash

pub fn preview_structure_is_stable_test() {
  let ctx =
    testing.start(plushie_pad.app())
    |> testing.click("save")

  let tree = testing.tree(ctx)
  snapshot.assert_tree_snapshot(tree, "pad-saved", "test/snapshots")
  tree_hash.assert_tree_hash(tree, "pad-saved", "test/snapshots")
  testing.stop(ctx)
}
```

`assert_tree_snapshot` writes a deterministic JSON form to
`test/snapshots/pad-saved.json` on the first run and compares
against that golden on later runs. `assert_tree_hash` stores a
SHA-256 of the same form under `pad-saved.sha256`. Pixel
screenshots come from the headless and windowed backends; the mock
backend returns an empty stub so the same assertion passes on every
backend.

Update goldens when the UI intentionally changes:

```bash
PLUSHIE_UPDATE_SNAPSHOTS=1 gleam test     # JSON snapshots + tree hashes
PLUSHIE_UPDATE_SCREENSHOTS=1 gleam test   # pixel screenshot hashes
```

Snapshots and tree hashes share one flag because both derive from
the same serialized tree.

## Integration tests

`test/plushie/support.gleam` is the richer harness for runtime-level
behaviors: subscriptions, command dispatch, coalescing, effect
stubs, and direct event injection. It starts the full supervisor
tree (bridge, runtime, renderer) and returns a `TestApp(model)`:

```gleam
import plushie/event.{Widget, Click, EventTarget}
import plushie/support

pub fn auto_save_fires_after_edit_test() {
  let rt = support.start(plushie_pad.app(), [])

  support.dispatch_event(
    rt,
    Widget(Click(target: EventTarget(
      id: "auto-save",
      scope: [],
      window_id: "main",
      full: "main#auto-save",
    ))),
  )

  let assert Ok(_) =
    support.await(rt, fn(m) { m.auto_save }, 500)
  support.stop(rt)
}
```

`support.await` polls the model every 10 ms until the predicate
matches or the timeout expires. `support.dispatch_event` bypasses
the renderer's event source and pushes the event directly into the
runtime's mailbox, which is useful for events the renderer would
normally synthesize (subscriptions, timers).

The harness's owner process monitors the test process and
self-terminates if the test dies, so a failing test does not leak
the 60-second shutdown timeout.

## CI patterns

`bin/preflight` is the canonical local check and mirrors CI
exactly: format check, compile for both targets, run the mock
backend, run the headless backend. Any `[error]` or `[warning]`
lines in test output are bugs; they indicate a test that should be
capturing logs but isn't.

## Try it

- Add a test for the counter from chapter 3: click increment three
  times and assert the model and the displayed text.
- Test a keyboard shortcut by pressing `"ctrl+z"` on the pad and
  asserting the undo stack pops.
- Register a `"clipboard_write"` stub, click copy, and verify the
  resulting model.
- Run the same suite with `PLUSHIE_TEST_BACKEND=headless` and watch
  the wall-clock difference.

---

Next: [Shared State](16-shared-state.md)
