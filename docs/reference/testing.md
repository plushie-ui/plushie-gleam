# Testing

Complete reference for the Plushie test framework. For a narrative
introduction, see the [Testing guide](../guides/15-testing.md).

## Setup

Build the renderer before running tests:

```bash
PLUSHIE_SOURCE_PATH=../plushie-renderer gleam run -m plushie/build
gleam test
```

Tests run against the mock backend by default.

## Writing tests

```gleam
import plushie/testing

pub fn save_compiles_preview_test() {
  let session = testing.start(my_app())
  testing.click(session, "#save")
  testing.assert_exists(session, "#preview")
}
```

`testing.start` starts a fresh app instance via the session pool.

## Selectors

| Form | Matches |
|---|---|
| `"#widget_id"` | Local widget ID |
| `"#scope/path/id"` | Exact scoped path |
| `"window_id#widget_id"` | Widget in a specific window |
| `"window_id#scope/path/id"` | Scoped path in a specific window |

## Helpers

### Queries

`find`, `find_by_role`, `find_by_label`, `find_focused`.

### Interactions

| Function | Event produced |
|---|---|
| `click(session, selector)` | `WidgetClick` |
| `type_text(session, selector, text)` | `WidgetInput` |
| `submit(session, selector)` | `WidgetSubmit` |
| `toggle(session, selector)` | `WidgetToggle` |
| `select(session, selector, value)` | `WidgetSelect` |
| `slide(session, selector, value)` | `WidgetSlide` |
| `press(session, key)` | `KeyPress` |
| `release(session, key)` | `KeyRelease` |
| `canvas_press(session, selector, x, y)` | `WidgetPress` |
| `canvas_release(session, selector, x, y)` | `WidgetRelease` |
| `canvas_move(session, selector, x, y)` | `WidgetMove` |

All interactions are synchronous.

### Multi-window interactions

```gleam
testing.click(session, "settings#save")
```

### Assertions

`assert_text`, `assert_exists`, `assert_not_exists`, `assert_role`,
`assert_a11y`, `assert_no_diagnostics`.

### State inspection

`get_model(session)`, `get_tree(session)`.

### Async and effects

`await_async(session, tag, timeout)`,
`register_effect_stub(session, kind, response)`.

Effect stubs register by **kind** (the operation type like `"file_open"`),
not by tag. Stubs are scoped to the test session.

## Backend capabilities

| Backend | Speed | Rendering | Screenshots | Effects |
|---|---|---|---|---|
| `mock` | ~ms | Protocol only | Hash only | Stubs only |
| `headless` | ~100ms | Software rendering | Pixel-accurate | Stubs only |
| `windowed` | ~seconds | GPU rendering | Pixel-accurate | Real |

```bash
gleam test                                  # mock (default)
PLUSHIE_TEST_BACKEND=headless gleam test    # software rendering
PLUSHIE_TEST_BACKEND=windowed gleam test    # real windows
```

## Screenshots and tree hashes

```gleam
testing.assert_tree_hash(session, "initial-state")
testing.assert_screenshot(session, "styled-view")
```

Golden files in `test/snapshots/` and `test/screenshots/`. Update with:

```bash
PLUSHIE_UPDATE_SNAPSHOTS=1 gleam test
PLUSHIE_UPDATE_SCREENSHOTS=1 gleam test
```

## .plushie scripting format

```
app: my_app
viewport: 800x600
theme: dark
-----
click "#save"
type_text "#editor" "Hello"
expect "Hello"
screenshot "after-hello"
```

```bash
gleam run -m plushie/cli/script
gleam run -m plushie/cli/replay -- path/to/test.plushie
```

## See also

- [Testing guide](../guides/15-testing.md)
- [Commands](commands.md) - effect stubs
- [Configuration](configuration.md) - test pool and backend
