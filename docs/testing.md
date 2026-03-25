# Testing

## Philosophy

Progressive fidelity: test your app's logic with fast, pure-Gleam mock tests;
promote to headless or windowed backends when you need wire-protocol verification
or pixel-accurate screenshots.


## Unit testing

`update` is pure, `view` returns `Node` values. Plain gleeunit -- no framework
needed.

### Testing `update`

<!-- test: testing_doc_adding_a_todo_appends_and_clears_input_test -- keep this code block in sync with the test -->
```gleam
import gleeunit/should
import plushie/event.{WidgetClick}
import plushie/command

pub fn adding_a_todo_appends_to_list_and_clears_input_test() {
  let model = Model(todos: [], input: "Buy milk")
  let #(model, _cmd) = my_app.update(model, WidgetClick(id: "add_todo", scope: []))

  should.equal(model.todos, [Todo(text: "Buy milk", done: False)])
  should.equal(model.input, "")
}
```

### Testing commands from `update`

Commands are `Command(msg)` union values. Pattern-match on the constructor to
verify what `update` asked the runtime to do, without executing anything.

<!-- test: testing_doc_submitting_todo_returns_focus_command_test -- keep this code block in sync with the test -->
```gleam
import gleeunit/should
import plushie/command
import plushie/event.{WidgetSubmit, WidgetClick}

pub fn submitting_todo_refocuses_the_input_test() {
  let model = Model(todos: [], input: "Buy milk")
  let #(model, cmd) = my_app.update(model, WidgetSubmit(
    id: "todo_input", scope: [], value: "Buy milk",
  ))

  should.equal(list.length(model.todos), 1)
  let assert command.Focus(widget_id: "todo_input") = cmd
}

pub fn save_triggers_an_async_task_test() {
  let model = Model(data: "unsaved")
  let #(_model, cmd) = my_app.update(model, WidgetClick(id: "save", scope: []))

  let assert command.Async(tag: "save_result", ..) = cmd
}
```

### Testing `view`

<!-- test: testing_doc_view_shows_todo_count_test -- keep this code block in sync with the test -->
```gleam
import gleam/option
import plushie/tree
import plushie/node

pub fn view_shows_todo_count_test() {
  let model = Model(
    todos: [Todo(id: 1, text: "Buy milk", done: False)],
    input: "",
    filter: "all",
  )
  let tree = my_app.view(model)

  let assert option.Some(counter) = tree.find(tree, "todo_count")
  let assert option.Some(node.StringVal(content)) =
    dict.get(counter.props, "content") |> option.from_result()
  should.be_true(string.contains(content, "1"))
}
```

### Testing `init`

<!-- test: testing_doc_init_returns_valid_initial_state_test -- keep this code block in sync with the test -->
```gleam
pub fn init_returns_valid_initial_state_test() {
  let #(model, _cmd) = my_app.init(dynamic.nil())

  should.be_true(list.is_empty(model.todos))
  should.equal(model.input, "")
}
```

### Tree query helpers

`plushie/tree` provides helpers for querying view trees directly:

<!-- test: testing_doc_tree_find_test, testing_doc_tree_ids_test, testing_doc_tree_find_all_test -- keep this code block in sync with the test -->
```gleam
import plushie/tree
import gleam/option

tree.find(tree, "my_button")            // find node by ID
tree.exists(tree, "my_button")          // check existence
tree.ids(tree)                          // all IDs (depth-first)
tree.find_all(tree, fn(node) {          // find by predicate
  node.kind == "button"
})
```

These work on the raw `Node` values returned by `view`. No test
session or backend required.

### JSON tree snapshots

For complex views, snapshot the entire tree as JSON to catch unintended
structural changes. `plushie/testing/snapshot.assert_tree_snapshot` compares
a tree against a stored JSON file at the unit test level -- no backend
needed.

```gleam
import plushie/testing/snapshot

pub fn initial_view_snapshot_test() {
  let #(model, _cmd) = my_app.init(dynamic.nil())
  let tree = my_app.view(model)

  snapshot.assert_tree_snapshot(tree, "initial_view", "test/snapshots")
}
```

First run writes the file. Subsequent runs compare and fail with a diff on
mismatch. Update after intentional changes:

```bash
PLUSHIE_UPDATE_SNAPSHOTS=1 gleam test
```

This is a pure JSON comparison -- it normalizes key ordering for stable
output. It is distinct from the framework's `tree_hash.assert_tree_hash`
(which uses SHA-256 hashes of the tree) and `screenshot.assert_screenshot`
(which compares pixel data).


## The test framework

Unit tests cover logic. But they cannot click a button, verify a widget
appears after an interaction, or catch a rendering regression when you bump
iced. That is what the test framework is for.

<!-- test: testing_doc_clicking_increment_updates_counter_test -- keep this code block in sync with the test -->
```gleam
import gleeunit/should
import gleam/option
import plushie/testing as test
import plushie/testing/element

pub fn clicking_increment_updates_counter_test() {
  let session = test.start(counter_app)
  let session = test.click(session, "increment")

  let assert option.Some(el) = test.find(session, "count")
  let assert option.Some(text) = element.text(el)
  should.equal(text, "1")
}
```

`plushie/testing.start` creates a session, runs init, and normalizes the
initial view. State is threaded explicitly through each operation -- no
process dictionary, no mutable state.


## Selectors, interactions, and assertions

### Where do widget IDs come from?

Every widget in plushie gets an ID from the first argument to its builder or
constructor. For example, `ui.button("save_btn", "Save", [])` creates a
button with ID `"save_btn"`.

When using the test framework, pass the ID directly (no `#` prefix):

```gleam
test.click(session, "save_btn")
test.find(session, "save_btn")
```

### Element handles

`test.find` returns `Option(Element)`. The `Element` type wraps a `Node`
with convenient accessors:

<!-- test: testing_doc_element_id_and_kind_test -- keep this code block in sync with the test -->
```gleam
import plushie/testing/element

let assert option.Some(el) = test.find(session, "my-button")
element.id(el)        // => "my-button"
element.kind(el)      // => "button"
element.text(el)      // => Some("Click me")
element.children(el)  // => [...]
```

Use `element.text` to extract display text from an element:

```gleam
let assert option.Some(el) = test.find(session, "count")
let assert option.Some(txt) = element.text(el)
should.equal(txt, "42")
```

`element.text` checks props in order: `content`, `label`, `value`,
`placeholder`. Returns `None` if no text prop is found.

### Interaction functions

All interaction functions take a session and return an updated session.
State threading is explicit.

| Function | Widget types | Event produced |
|---|---|---|
| `test.click(session, id)` | `button` | `WidgetClick(id:, scope: [])` |
| `test.type_text(session, id, text)` | `text_input`, `text_editor` | `WidgetInput(id:, scope: [], value: text)` |
| `test.submit(session, id)` | `text_input` | `WidgetSubmit(id:, scope: [], value: val)` |
| `test.toggle(session, id)` | `checkbox`, `toggler` | `WidgetToggle(id:, scope: [], value: !current)` |
| `test.select(session, id, value)` | `pick_list`, `combo_box`, `radio` | `WidgetSelect(id:, scope: [], value: val)` |
| `test.slide(session, id, value)` | `slider`, `vertical_slider` | `WidgetSlide(id:, scope: [], value: val)` |

### Assertions

<!-- test: testing_doc_text_content_assertion_test, testing_doc_existence_assertion_test, testing_doc_model_assertion_test -- keep this code block in sync with the test -->
```gleam
import gleeunit/should
import gleam/option
import plushie/testing as test
import plushie/testing/element

// Text content
let assert option.Some(el) = test.find(session, "count")
let assert option.Some(txt) = element.text(el)
should.equal(txt, "42")

// Existence
should.be_true(option.is_some(test.find(session, "my-button")))
should.be_true(option.is_none(test.find(session, "admin-panel")))

// Full model equality
should.equal(test.model(session), expected_model)

// Direct model inspection
should.equal(test.model(session).count, 5)

// Element type
let assert option.Some(el) = test.find(session, "count")
should.equal(element.kind(el), "text")
```


## API reference

All functions are in `plushie/testing`:

| Function | Description |
|---|---|
| `test.start(app)` | Start a test session, run init and render initial view |
| `test.model(session)` | Returns the current app model |
| `test.tree(session)` | Returns the current normalized UI tree |
| `test.find(session, id)` | Find element by ID, returns `Option(Element)` |
| `test.click(session, id)` | Click a button widget |
| `test.type_text(session, id, text)` | Type text into a text_input or text_editor |
| `test.submit(session, id)` | Submit a text_input (simulates pressing enter) |
| `test.toggle(session, id)` | Toggle a checkbox or toggler |
| `test.select(session, id, value)` | Select a value from pick_list, combo_box, or radio |
| `test.slide(session, id, value)` | Slide a slider to a numeric value |
| `test.send_event(session, event)` | Dispatch a raw event through the update cycle |
| `test.element_text(element)` | Extract text content from an Element |
| `test.element_prop(element, key)` | Get a prop value from an Element |
| `test.element_children(element)` | Get an element's children |

Additional modules:

| Module | Key functions |
|---|---|
| `plushie/testing/element` | `find`, `text`, `prop`, `id`, `kind`, `children`, `find_all` |
| `plushie/testing/snapshot` | `assert_tree_snapshot`, `node_to_json` |
| `plushie/testing/tree_hash` | `hash`, `assert_tree_hash` |
| `plushie/testing/screenshot` | `empty`, `save_png`, `assert_screenshot` |
| `plushie/testing/script` | `parse`, `parse_file` |


## Backends

All tests work on all backends. Write tests once, swap backends without
changing assertions.

### Backend modes

| | `:pooled_mock` | `:headless` | `:windowed` |
|---|---|---|---|
| **Speed** | ~ms | ~100ms | ~seconds |
| **Renderer** | Yes (`--mock`) | Yes (`--headless`) | Yes |
| **Display server** | No | No | Yes (Xvfb in CI) |
| **Protocol round-trip** | Yes | Yes | Yes |
| **Structural tree hashes** | Yes | Yes | Yes |
| **Pixel screenshots** | No | Yes (software) | Yes |
| **Effects** | Cancelled | Cancelled | Executed |
| **Subscriptions** | Tracked, not fired | Tracked, not fired | Active |
| **Real rendering** | No | Yes (tiny-skia) | Yes (GPU) |
| **Real windows** | No | No | Yes |

- **`:pooled_mock`** -- shared `plushie --mock` process with session
  multiplexing. Tests app logic, tree structure, and wire protocol.
  No rendering, no display, sub-millisecond. The right default for
  90% of tests.

- **`:headless`** -- `plushie --headless` with software rendering via
  tiny-skia (no display server). Pixel screenshots for visual
  regression. Catches rendering bugs that mock mode can't.

- **`:windowed`** -- `plushie` with real iced windows and GPU rendering.
  Effects execute, subscriptions fire, screenshots capture exactly
  what a user sees. Needs a display server (Xvfb or headless Weston).

### Backend selection

You never choose a backend in your test code. Backend selection is an
infrastructure decision made via environment variable or application config.
Tests are portable across all three.

| Priority | Source | Example |
|---|---|---|
| 1 | Environment variable | `PLUSHIE_TEST_BACKEND=headless gleam test` |
| 2 | Default | `:pooled_mock` |


## Snapshots and screenshots

Plushie has three distinct regression testing mechanisms. Understanding the
difference is important.

### Structural tree hashes (`assert_tree_hash`)

`tree_hash.assert_tree_hash` captures a SHA-256 hash of the serialized UI
tree and compares it against a golden file. It works on all backend modes
because every mode can produce a tree.

```gleam
import plushie/testing as test
import plushie/testing/tree_hash

pub fn counter_initial_state_test() {
  let session = test.start(counter_app)
  tree_hash.assert_tree_hash(test.tree(session), "counter-initial", "test/snapshots")
}

pub fn counter_after_increment_test() {
  let session = test.start(counter_app)
  let session = test.click(session, "increment")
  tree_hash.assert_tree_hash(test.tree(session), "counter-at-1", "test/snapshots")
}
```

Golden files are stored in `test/snapshots/` as `.sha256` files. On first
run, the golden file is created automatically. On subsequent runs, the hash
is compared and the test fails on mismatch.

To update golden files after intentional changes:

```bash
PLUSHIE_UPDATE_SNAPSHOTS=1 gleam test
```

### Pixel screenshots (`assert_screenshot`)

`screenshot.assert_screenshot` captures real RGBA pixel data and compares it
against a golden file. It produces meaningful data on both the `:windowed`
backend (GPU rendering via wgpu) and the `:headless` backend (software
rendering via tiny-skia). On `:pooled_mock`, it silently succeeds as a no-op
(returns an empty hash, which is accepted without creating or checking a
golden file).

Note that headless screenshots use software rendering, so pixels will not
match GPU output exactly. Maintain separate golden files per backend, or
use headless screenshots for layout regression testing only.

```gleam
import plushie/testing as test
import plushie/testing/screenshot

pub fn counter_renders_correctly_test() {
  let session = test.start(counter_app)
  let session = test.click(session, "increment")
  // screenshot capture would come from a backend-specific session
  screenshot.assert_screenshot(
    screenshot.empty("counter-at-1"),
    "counter-at-1",
    "test/screenshots",
  )
}
```

Golden files are stored in `test/screenshots/` as `.sha256` files. The
workflow is the same as structural snapshots but uses a separate env var:

```bash
PLUSHIE_UPDATE_SCREENSHOTS=1 gleam test
```

Because screenshots silently no-op on pooled_mock, you can include
`assert_screenshot` calls in any test without conditional logic. They will
produce assertions when run on the headless or windowed backends.

### JSON tree snapshots (`assert_tree_snapshot`)

`snapshot.assert_tree_snapshot` is a unit-test-level tool that compares
a raw tree `Node` against a stored JSON file. No backend or session needed.
See the [Unit testing](#json-tree-snapshots) section above.

### When to use each

- **`assert_tree_hash`** -- always appropriate. Catches structural regressions
  (widgets appearing/disappearing, prop changes, nesting changes). Works on
  every backend. Use liberally.

- **`assert_screenshot`** -- after bumping iced, changing the renderer,
  modifying themes, or any change that affects visual output. Only meaningful
  on the windowed backend. Include alongside `assert_tree_hash` for critical views.

- **`assert_tree_snapshot`** -- for unit tests of `view` output. No
  framework overhead. Good for documenting what a view produces for a given
  model state.


## Script-based testing

`.plushie` scripts provide a declarative format for describing interaction
sequences. The format is a superset of iced's `.ice` test scripts -- the
core instructions (`click`, `type`, `expect`, `snapshot`) use the same
syntax. Plushie adds `assert_text`, `assert_model`, `screenshot`, `wait`, and
a header section for app configuration.

### The `.plushie` format

A `.plushie` file has a header and an instruction section separated by
`-----`:

```
app: my_counter_app
viewport: 800x600
theme: dark
backend: pooled_mock
-----
click "#increment"
click "#increment"
expect "Count: 2"
tree_hash "counter-at-2"
screenshot "counter-pixels"
assert_text "#count" "2"
wait 500
```

#### Header fields

| Field | Required | Default | Description |
|---|---|---|---|
| `app` | Yes | -- | App module name |
| `viewport` | No | `800x600` | Viewport size as `WxH` |
| `theme` | No | `dark` | Theme name |
| `backend` | No | `pooled_mock` | Backend: `pooled_mock`, `headless`, or `windowed` |

Lines starting with `#` are comments (in both header and body sections).

#### Instructions

| Instruction | Syntax | Mock support | Description |
|---|---|---|---|
| `click` | `click "selector"` | Yes | Click a widget |
| `type` | `type "selector" "text"` | Yes | Type text into a widget |
| `type` (key) | `type enter` | Yes | Send a special key (press + release). Supports modifiers: `type ctrl+s` |
| `expect` | `expect "text"` | Yes | Assert text appears somewhere in the tree |
| `tree_hash` | `tree_hash "name"` | Yes | Capture and assert a structural tree hash |
| `screenshot` | `screenshot "name"` | No-op on pooled_mock | Capture and assert a pixel screenshot |
| `assert_text` | `assert_text "selector" "text"` | Yes | Assert widget has specific text |
| `assert_model` | `assert_model "expression"` | Yes | Assert expression appears in inspected model (substring match) |
| `press` | `press key` | Yes | Press a key down. Supports modifiers: `press ctrl+s` |
| `release` | `release key` | Yes | Release a key. Supports modifiers: `release ctrl+s` |
| `move` | `move "selector"` | No-op | Move mouse to a widget (requires widget bounds) |
| `move` (coords) | `move "x,y"` | Yes | Move mouse to pixel coordinates |
| `wait` | `wait 500` | Ignored (except replay) | Pause N milliseconds |

### Running scripts

```bash
# Run all scripts in test/scripts/
gleam run -m plushie/testing/script_runner

# Run specific scripts
gleam run -m plushie/testing/script_runner -- test/scripts/counter.plushie test/scripts/todo.plushie
```

### Replaying scripts

```bash
gleam run -m plushie/testing/script_runner -- --replay test/scripts/counter.plushie
```

Replay mode forces the `:windowed` backend and respects `wait` timings, so you
see interactions happen in real time with real windows. Useful for debugging
visual issues, demos, and onboarding.


## Testing async workflows

### On the pooled_mock backend

The pooled_mock backend executes `Async`, `Stream`, and `Done` commands
synchronously. When `update` returns a command like
`command.Async(work: fn() { fetch_data() }, tag: "data_loaded")`, the
backend immediately calls the function, gets the result, and dispatches
an `AsyncResult` event through `update` -- all within the same call.

```gleam
pub fn fetching_data_loads_results_test() {
  let session = test.start(my_app)
  let session = test.click(session, "fetch")
  // On pooled_mock, the async command already executed synchronously.
  // The model is already updated.
  let model = test.model(session)
  should.be_true(list.length(model.results) > 0)
}
```

Widget ops (focus, scroll), window ops, and timers are silently skipped on
pooled_mock because they require a renderer. Test the command shape at the
unit test level instead:

```gleam
pub fn clicking_fetch_starts_async_load_test() {
  let model = Model(loading: False, data: option.None)
  let #(model, cmd) = my_app.update(model, WidgetClick(id: "fetch", scope: []))

  should.equal(model.loading, True)
  let assert command.Async(tag: "data_loaded", ..) = cmd
}
```

### On headless and windowed backends

All backend modes execute async commands synchronously. Async results
are available immediately on all modes because the commands have already
completed.


## Debugging and error messages

### Element not found

<!-- test: testing_doc_find_nonexistent_returns_none_test -- keep this code block in sync with the test -->
```gleam
test.find(session, "nonexistent")
// => None
```

Use `test.tree` to inspect the current tree and verify the widget's ID:

```gleam
let tree = test.tree(session)
io.debug(tree)
```

### Inspecting state when a test fails

`test.model` and `test.tree` are your best debugging tools:

```gleam
pub fn debugging_a_failing_test_test() {
  let session = test.start(my_app)
  let session = test.click(session, "increment")

  io.debug(test.model(session))
  io.debug(test.tree(session))

  let assert option.Some(el) = test.find(session, "count")
  let assert option.Some(txt) = element.text(el)
  should.equal(txt, "1")
}
```


## CI configuration

### Pooled mock CI (simplest)

No special setup. Works anywhere Gleam runs.

```yaml
- run: gleam test
```

### Headless CI

Requires the plushie binary (download or build from source).

```yaml
- run: PLUSHIE_TEST_BACKEND=headless gleam test
```

### Windowed CI

Requires a display server and GPU/software rendering. Two options:

**Option A: Xvfb (X11)**

```yaml
- run: sudo apt-get install -y xvfb mesa-vulkan-drivers
- run: |
    Xvfb :99 -screen 0 1024x768x24 &
    export DISPLAY=:99
    export WINIT_UNIX_BACKEND=x11
    PLUSHIE_TEST_BACKEND=windowed gleam test
```

**Option B: Weston (Wayland)**

Weston's headless backend provides a Wayland compositor without a physical
display. Combined with `vulkan-swrast` (Mesa software rasterizer), this
runs the full rendering pipeline on CPU.

```yaml
- run: sudo apt-get install -y weston mesa-vulkan-drivers
- run: |
    export XDG_RUNTIME_DIR=/tmp/plushie-xdg-runtime
    mkdir -p "$XDG_RUNTIME_DIR" && chmod 0700 "$XDG_RUNTIME_DIR"
    weston --backend=headless --width=1024 --height=768 --socket=plushie-test &
    sleep 1
    export WAYLAND_DISPLAY=plushie-test
    PLUSHIE_TEST_BACKEND=windowed gleam test
```

On Arch Linux, `weston` and `vulkan-swrast` are available via pacman.

### Progressive CI

Run pooled_mock tests fast, then promote to higher-fidelity backends for subsets:

```yaml
# All tests on pooled_mock (fast, catches logic bugs)
- run: gleam test

# Full suite on headless for protocol verification
- run: PLUSHIE_TEST_BACKEND=headless gleam test

# Windowed for pixel regression (tagged subset)
- run: |
    Xvfb :99 -screen 0 1024x768x24 &
    export DISPLAY=:99
    PLUSHIE_TEST_BACKEND=windowed gleam test
```


## Wire format in test backends

The headless and windowed backends communicate with the renderer using the same
wire protocol as the production Bridge. By default, both use MessagePack
(`{packet, 4}` framing). JSON is available for debugging via environment
variable or session options.

The pooled_mock backend does not use a wire protocol (pure Gleam, no
renderer process), so the format option has no effect on it.


## Testing extensions

Extension widgets have two testing layers: Gleam-side logic (struct
building, command generation, demo app behavior) and Rust-side
rendering (the widget actually renders, handles events, etc.).

### Gleam-side: unit tests (no renderer)

Extension modules generate types, setters, and protocol
implementations. Test these directly:

```gleam
import gleeunit/should

pub fn new_creates_struct_with_defaults_test() {
  let gauge = my_gauge.new("g1", value: 50)
  should.equal(gauge.id, "g1")
  should.equal(gauge.value, 50)
}

pub fn build_produces_correct_node_test() {
  let node = my_gauge.new("g1", value: 75) |> my_gauge.build()
  should.equal(node.kind, "gauge")
}
```

Demo apps test the extension in context:

```gleam
import plushie/tree
import gleam/option

pub fn view_produces_a_gauge_widget_test() {
  let #(model, _cmd) = my_gauge_demo.init(dynamic.nil())
  let tree = my_gauge_demo.view(model) |> tree.normalize()
  let assert option.Some(gauge) = tree.find(tree, "my-gauge")
  should.equal(gauge.kind, "gauge")
}
```

### Rust-side: unit tests (no Gleam)

The `plushie_ext::testing` module provides `TestEnv` and node factories
for testing `WidgetExtension::render()` in isolation:

```rust
use plushie_ext::testing::*;
use plushie_ext::prelude::*;

#[test]
fn gauge_renders_without_panic() {
    let ext = MyGaugeExtension::new();
    let test = TestEnv::default();
    let node = node_with_props("g1", "gauge", json!({"value": 75}));
    let env = test.env();
    let _element = ext.render(&node, &env);
}
```

### End-to-end: through the renderer

To verify extension widgets survive the wire protocol round-trip and
render correctly, build a custom renderer binary that includes the
extension's Rust crate, then run tests through it with the headless
backend:

```bash
# Run tests through the real renderer (headless, no display server)
PLUSHIE_TEST_BACKEND=headless gleam test
```

Write end-to-end tests with the test framework:

```gleam
import plushie/testing as test
import gleam/option

pub fn gauge_appears_in_rendered_tree_test() {
  let session = test.start(my_gauge_demo_app)
  should.be_true(option.is_some(test.find(session, "my-gauge")))
}

pub fn gauge_responds_to_push_command_test() {
  let session = test.start(my_gauge_demo_app)
  let session = test.click(session, "push-value")
  let assert option.Some(el) = test.find(session, "value-display")
  let assert option.Some(txt) = element.text(el)
  should.equal(txt, "42")
}
```

These tests run on `:pooled_mock` by default (fast, logic-only). Set
`PLUSHIE_TEST_BACKEND=headless` to exercise the full Rust rendering path
with the extension compiled in.


## Key name validation

`testing.press_key`, `testing.type_key`, and `testing.release_key`
validate key names at call time. Input is case-insensitive. Named keys
use PascalCase matching the renderer's wire format (same strings that
appear in `handle_event` data):

    testing.press_key(ctx, "Tab")
    testing.press_key(ctx, "ArrowRight")
    testing.press_key(ctx, "Shift+PageUp")
    testing.press_key(ctx, "a")

Unrecognized key names panic immediately:

```
unknown key "tabb". Examples: Tab, ArrowRight, PageUp, Escape, Enter.
See plushie/key.gleam for the full list.
```

Single characters are also accepted and lowercased (`"a"`, `"Z"`,
`"1"`). Modifier combos use `+`: `"Ctrl+s"`, `"Shift+ArrowUp"`.
Modifiers: `shift`, `ctrl`, `alt`, `logo`, `command`.


## Known limitations

Workarounds and details for each limitation are noted inline below.

- Script instruction `move` (move cursor to a widget by selector) is a
  no-op. It requires widget bounds from layout, which only the renderer knows.
- `move_to` on the pooled_mock backend dispatches a mouse moved event but has
  no spatial layout info. Mouse area enter/exit events won't fire.
- Pixel screenshots are only available on the headless and windowed backends (pooled_mock returns stubs).
- Headless screenshots use software rendering (tiny-skia) and may not match
  GPU output pixel-for-pixel.
- Script `assert_model` uses substring matching against the inspected model.
  Use specific substrings or use gleeunit assertions for precise model checks.
- The `CommandProcessor` executes async/stream/batch commands synchronously
  in all test backends. Timing and concurrency bugs will not surface in mock
  tests. Use headless or windowed backends for concurrency-sensitive tests.
- Headless and windowed backends spawn a renderer via `Port`. The cleanup
  handles normal teardown; if a test crashes without triggering it, the
  BEAM's process exit propagation kills the port.
