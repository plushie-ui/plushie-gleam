# Configuration

Plushie is configured at three levels: environment variables, runtime
options on `plushie.start`, and the app's `settings` callback.

## Environment variables

| Variable | Purpose |
|---|---|
| `PLUSHIE_BINARY_PATH` | Explicit path to the renderer binary |
| `PLUSHIE_RUST_SOURCE_PATH` | Path to a local plushie-rust checkout; makes `plushie/build` invoke `cargo-plushie` from source |
| `PLUSHIE_TEST_BACKEND` | Test backend: `mock` (default), `headless`, or `windowed` |
| `PLUSHIE_UPDATE_SCREENSHOTS` | Update screenshot golden files |
| `PLUSHIE_UPDATE_SNAPSHOTS` | Update tree-hash snapshot files |
| `RUST_LOG` | Renderer log verbosity (e.g. `plushie=debug`) |

The plushie-rust release the SDK targets is declared at the root of
`gleam.toml`:

```toml
plushie_rust_version = "0.6.1"
```

`plushie/build` and `plushie/download` use this value as the pinned
version. See [versioning](versioning.md).

## Runtime options (plushie.start)

```gleam
plushie.start(app, [
  plushie.AppOpts(my_config),
  plushie.Binary(path),
  plushie.Dev(True),
  plushie.Daemon(True),
  plushie.Format(plushie.Json),
])
```

| Option | Default | Purpose |
|---|---|---|
| `AppOpts(value)` | `Nil` | Forwarded to `init` |
| `Binary(path)` | auto-resolved | Renderer binary path |
| `Dev(bool)` | `False` | Enable hot code reloading |
| `Daemon(bool)` | `False` | Keep running after last window closes |
| `Format(format)` | `Msgpack` | Wire protocol format |
| `Transport(mode)` | `Spawn` | Transport mode: `Spawn`, `Stdio`, `Iostream(pid)` |

## App settings callback

The optional `settings` callback provides defaults to the renderer:

```gleam
fn settings() {
  [
    app.DefaultTextSize(16.0),
    app.Theme(theme.Dark),
    app.Fonts(["priv/fonts/inter.ttf"]),
    app.DefaultEventRate(60),
  ]
}
```

| Key | Purpose |
|---|---|
| `DefaultTextSize` | Default text size in pixels |
| `Antialiasing` | Font antialiasing (default True) |
| `Theme` | Default theme |
| `Fonts` | Font file paths to load |
| `DefaultEventRate` | Max events/sec for coalescable events |
| `ScaleFactor` | DPI scale multiplier |

## Transport modes

### Spawn (default)

The SDK spawns the renderer as a child process via an Erlang Port.

### Stdio

The renderer spawns the Gleam app. Communication over stdin/stdout.

### Iostream(pid)

A message-based adapter for custom transports (SSH, TCP, WebSocket).
See `plushie/transport/framing` for frame encode/decode.

## CLI tools

```bash
gleam run -m plushie/download            # download precompiled binary
gleam run -m plushie/build               # build from source
gleam run -m plushie/cli/gui             # run a local desktop app
gleam run -m plushie/cli/stdio           # exec/remote rendering
gleam run -m plushie/cli/inspect         # print UI tree as JSON
gleam run -m plushie/cli/script          # .plushie test script runner
gleam run -m plushie/cli/replay          # .plushie script replay
```

## See also

- `plushie/binary` - binary path resolution
- `plushie/bridge` - transport management
- [Wire Protocol](wire-protocol.md)
- [Testing](testing.md)
