# Testing

Plushie tests exercise the real renderer binary. Every test starts a full
application instance and interacts with it through the same wire protocol
that a real user session uses.

## Setting up

The renderer binary must be built before running tests:

```bash
PLUSHIE_SOURCE_PATH=../plushie-renderer gleam run -m plushie/build
gleam test
```

Tests run against the mock backend by default (real binary, real wire
protocol, no GPU rendering).

## Writing tests

```gleam
import plushie/testing

pub fn increment_test() {
  let session = testing.start(my_app())
  testing.click(session, "#increment")
  testing.click(session, "#increment")
  testing.assert_text(session, "#count", "Count: 2")
}
```

`testing.start` starts a fresh app instance connected to the session pool.

## Selectors

| Selector | Matches |
|---|---|
| `"#save"` | Widget with local ID `"save"` |
| `"#sidebar/hello.gleam/delete"` | Widget at exact scoped path |
| `"main#save"` | Widget `"save"` in window `"main"` |
| `"main#form/save"` | Scoped path `"form/save"` in window `"main"` |

## Interactions

```gleam
testing.click(session, "#save")
testing.type_text(session, "#editor", "hello")
testing.submit(session, "#search")
testing.toggle(session, "#auto-save")
testing.slide(session, "#volume", 75.0)
testing.press(session, "ctrl+s")
```

All interactions are synchronous. They wait for the full update cycle to
complete before returning.

## Effect stubs

For platform effects in tests, register stubs:

```gleam
testing.register_effect_stub(session, "file_open", Ok(#{path: "/tmp/test.gleam"}))
testing.click(session, "#import")
```

## Three backends

```bash
gleam test                                  # mock (default)
PLUSHIE_TEST_BACKEND=headless gleam test    # software rendering
PLUSHIE_TEST_BACKEND=windowed gleam test    # real windows
```

See the [Testing reference](../reference/testing.md) for the full API.

---

Next: [Shared State](16-shared-state.md)
