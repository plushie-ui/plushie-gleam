# Configuration

Plushie is configured at three levels: environment variables for
deployment and CI, `gleam.toml` for project-wide defaults, and
runtime records passed to `plushie.start` (or the thin wrappers in
`plushie/gui`, `plushie/stdio`, `plushie/connect`) for per-instance
control. App-wide renderer defaults (theme, fonts, event rate) come
from the `app.Settings` record returned by the app's `settings`
callback.

Most projects only need `plushie_rust_version` in `gleam.toml` and a
built-or-downloaded renderer binary.

## Environment variables

| Variable | Purpose |
|---|---|
| `PLUSHIE_BINARY_PATH` | Explicit path to the renderer binary. Overrides all other binary resolution. |
| `PLUSHIE_RUST_SOURCE_PATH` | Path to a local plushie-rust checkout for source builds. |
| `PLUSHIE_SOCKET` | Socket address for `plushie/connect` (Unix path, `:port`, or `host:port`). |
| `PLUSHIE_TOKEN` | Fallback auth token for socket transport. Sent to the renderer as a digest. |
| `PLUSHIE_TEST_BACKEND` | Test backend: `mock` (default), `headless`, or `windowed`. |
| `PLUSHIE_TEST_TIMEOUT` | Positive integer multiplier for test infrastructure timeouts. Invalid values use `1`. |
| `PLUSHIE_UPDATE_SCREENSHOTS` | When set to `1`, updates screenshot golden files instead of comparing. |
| `PLUSHIE_UPDATE_SNAPSHOTS` | When set to `1`, updates tree-hash and JSON snapshot golden files instead of comparing. |
| `RUST_LOG` | Renderer log verbosity. Forwarded to the renderer process if set in the parent environment; the SDK defaults it to `error` otherwise. |

### PLUSHIE_BINARY_PATH

Forces a specific renderer binary. If set but pointing to a missing
file, `plushie.start` fails with `BinaryNotFound(EnvVarPointsToMissing(path))`
rather than falling through to other candidate paths. Useful in CI
where the binary is pre-built at a known location, or in production
deployments where the binary ships alongside the release.

When unset, `plushie/binary` searches candidate paths in order:

```
build/plushie/bin/plushie-renderer-{platform}-{arch}
build/plushie/bin/plushie-renderer
priv/bin/plushie-renderer-{platform}-{arch}
priv/bin/plushie-renderer
_build/dev/plushie-renderer/target/release/plushie-renderer
_build/prod/plushie-renderer/target/release/plushie-renderer
./plushie-renderer
../plushie-renderer/target/release/plushie-renderer
../plushie-renderer/target/debug/plushie-renderer
```

### PLUSHIE_RUST_SOURCE_PATH

Points to a local checkout of the plushie-rust repository. When set,
`gleam run -m plushie/build` uses a path-dependency workspace and
invokes `cargo-plushie` via `cargo run` against that checkout instead
of the crates.io release. The typical setup is a sibling directory:

```bash
git clone https://github.com/plushie-ui/plushie-rust ../plushie-rust
PLUSHIE_RUST_SOURCE_PATH=../plushie-rust gleam run -m plushie/build
```

`plushie/build` also consults the `[plushie] source_path` key from
`gleam.toml` when this env var is not set.

### RUST_LOG

Controls the renderer's log output using the standard `env_logger`
format. The renderer port inherits this value from the parent
environment when it is on the whitelist in `plushie/renderer_env`.
When unset, the SDK sets `RUST_LOG=error` for the child process.
Common values:

- `plushie=debug` - full protocol and rendering detail
- `plushie=info` - connection events and major state changes
- `plushie=warn` - warnings only

The renderer environment is scrubbed by default: only a canonical
whitelist (display, locale, font, accessibility, and explicit
Plushie-owned toggles) is forwarded. Everything else is explicitly
unset to prevent leaking secrets from the parent shell. See
`plushie/renderer_env`.

## Project config (gleam.toml)

The `[plushie]` section of `gleam.toml` provides project-wide
defaults read by the build and download tooling. A root-level
`plushie_rust_version` key pins the plushie-rust release that the
SDK expects.

```toml
name = "my_app"
version = "0.1.0"
plushie_rust_version = "0.7.0"

[plushie]
artifacts = ["bin", "wasm"]
bin_file = "build/plushie-renderer"
wasm_dir = "static/wasm"
source_path = "/path/to/plushie-rust"
native_widgets = ["native/gauge|gauge::GaugeExtension::new()"]
```

| Key | Level | Type | Default | Purpose |
|---|---|---|---|---|
| `plushie_rust_version` | root | `String` | required | Pins the plushie-rust release. `gleam run -m plushie/build` and `plushie/download` fail with installation guidance if this is missing. |
| `artifacts` | `[plushie]` | `List(String)` | `["bin"]` | Which artifacts `plushie/build` and `plushie/download` produce or install. Values: `"bin"`, `"wasm"`. |
| `bin_file` | `[plushie]` | `String` | auto | Destination path for the installed renderer binary. |
| `wasm_dir` | `[plushie]` | `String` | auto | Destination directory for the WASM artifact. |
| `source_path` | `[plushie]` | `String` | unset | Fallback for `PLUSHIE_RUST_SOURCE_PATH`. The env var wins when both are set. |
| `native_widgets` | `[plushie]` | `List(String)` | `[]` | Native widget crate entries in the form `"crate_path|constructor"`. The constructor field is redundant when the widget crate declares `[package.metadata.plushie.widget]`; it is parsed for migration compatibility. |

Resolution order for build and download flags (highest priority
first):

1. CLI flag (`--bin-file`, `--wasm-dir`, `--bin`, `--wasm`)
2. `[plushie]` section in `gleam.toml`
3. Environment variable (where applicable)
4. Hardcoded default

## App settings

The `app.Settings` record carries renderer defaults that apply to
every window. Settings are sent once during the initial handshake
and re-sent automatically after a renderer restart. Override the
defaults via `app.with_settings`:

```gleam
import gleam/option.{Some}
import plushie/app
import plushie/prop/theme

fn settings() -> app.Settings {
  app.Settings(
    ..app.default_settings(),
    default_text_size: 14.0,
    theme: Some(theme.Dark),
    fonts: ["priv/fonts/inter.ttf"],
    default_event_rate: Some(60),
  )
}

pub fn app() {
  app.simple(init, update, view)
  |> app.with_settings(settings)
}
```

| Field | Type | Default | Purpose |
|---|---|---|---|
| `antialiasing` | `Bool` | `True` | Enable font antialiasing. |
| `default_text_size` | `Float` | `16.0` | Default text size in logical pixels. |
| `theme` | `Option(Theme)` | `None` | Override the application theme. `None` uses the renderer default. |
| `fonts` | `List(String)` | `[]` | Paths to font files loaded at startup. Loaded fonts are addressable by family name from any widget's `font` prop. |
| `vsync` | `Bool` | `True` | Synchronize frame presentation with the display refresh rate. |
| `scale_factor` | `Float` | `1.0` | Multiplier on top of OS DPI scaling. Per-window overrides are available via the `scale_factor` window prop. |
| `default_font` | `Option(PropValue)` | `None` | Override the default font family. `None` uses the built-in default. |
| `default_event_rate` | `Option(Int)` | `None` | Maximum events per second for coalescable sources (mouse moves, sensor resizes, animation frames). `Some(0)` subscribes but never emits. Per-subscription `max_rate` and per-widget `EventRate` overrides still apply. |
| `validate_props` | `Bool` | `False` | When `True`, the renderer emits `PropValidation` diagnostic events for unknown or invalid widget props. Useful in dev. |
| `widget_config` | `Dict(String, PropValue)` | `dict.new()` | Per-widget config passed to native widgets. Keys match the widget's type name. |
| `required_widgets` | `List(String)` | `[]` | Native widget type names the app requires. The renderer emits a `required_widgets_missing` diagnostic during the handshake for unknown names. Non-fatal. |

The `default_event_rate` setting is the bottom of a three-level
rate hierarchy: per-widget `EventRate` overrides per-subscription
`set_max_rate`, which overrides `default_event_rate`. See the
[Subscriptions reference](subscriptions.md).

## Runtime options

`plushie.start(app, opts)` is the core entry point. The options
record is `plushie.StartOpts`:

| Field | Type | Default | Purpose |
|---|---|---|---|
| `binary_path` | `Option(String)` | `None` | Path to the renderer binary. `None` triggers auto-resolution via `plushie/binary`. |
| `format` | `protocol.Format` | `Msgpack` | Wire format. `Json` is human-readable and useful for debugging. |
| `daemon` | `Bool` | `False` | Keep running after all windows close. Without daemon mode, the runtime shuts down after receiving `System(AllWindowsClosed)`. |
| `session` | `String` | `""` | Session identifier for pooled / multiplexed renderers. |
| `app_opts` | `Dynamic` | `dynamic.nil()` | Forwarded to `init/1` for apps created with `simple_with_opts` or `application_with_opts`. |
| `required_native_widgets` | `List(String)` | `[]` | Native widget type names expected in the renderer. Merged with `Settings.required_widgets` on the wire. |
| `renderer_args` | `List(String)` | `[]` | Extra CLI arguments prepended to the renderer command. Only applies in `Spawn` transport. |
| `transport` | `Transport` | `Spawn` | Transport mode (`Spawn`, `Stdio`, or `Iostream(adapter)`). See [transport modes](#transport-modes). |
| `dev` | `Bool` | `False` | Enable the dev server: watch `src/`, recompile on change, hot-reload BEAM modules, and trigger a force re-render. App model state is preserved. Requires `file_system` dep and Elixir; see [Dev mode and hot reload](app-lifecycle.html#dev-mode-and-hot-reload). |
| `token` | `Option(String)` | `None` | Authentication token for socket transport. Sent to the renderer as a digest in the settings message. |

Start an app with default options and a resolved binary:

```gleam
import plushie

let assert Ok(instance) =
  plushie.start(my_app, plushie.default_start_opts())
plushie.wait(instance)
```

## GUI wrapper

`plushie/gui.run` is a convenience wrapper for the common case of a
local desktop app: resolve the binary, start the runtime in `Spawn`
transport, and block the calling process.

| Field | Type | Default | Purpose |
|---|---|---|---|
| `json` | `Bool` | `False` | Use JSON wire format instead of MessagePack. |
| `daemon` | `Bool` | `False` | Keep running after all windows close. |
| `dev` | `Bool` | `False` | Enable dev-mode live reload. |
| `debounce` | `Int` | `100` | File watch debounce in milliseconds. |
| `binary_path` | `Result(String, Nil)` | `Error(Nil)` | Explicit binary path. `Error(Nil)` auto-resolves. |

```gleam
import plushie/gui

pub fn main() {
  gui.run(my_app.app(), gui.default_opts())
}
```

`gui.run` halts the OS process with a non-zero status on binary
resolution failure or runtime start failure, writing a diagnostic
to stderr.

## Stdio wrapper

`plushie/stdio.run` starts the runtime in `Stdio` transport mode,
where the renderer is the parent and the Gleam app reads and writes
the wire protocol on its own stdin and stdout. All log output goes
to stderr to avoid corrupting the wire stream.

| Field | Type | Default | Purpose |
|---|---|---|---|
| `format` | `protocol.Format` | `Msgpack` | Wire format. |
| `daemon` | `Bool` | `False` | Keep running after all windows close. |

## Connect wrapper

`plushie/connect.run` connects to an already-running renderer via
Unix socket or TCP. Used when the renderer was started with
`--listen` and this process was spawned via `--exec` or launched
manually with socket details in the environment.

| Field | Type | Default | Purpose |
|---|---|---|---|
| `format` | `protocol.Format` | `Msgpack` | Wire format. |
| `daemon` | `Bool` | `False` | Keep running after all windows close. |

Socket address resolution order:

1. `--socket` CLI flag
2. `PLUSHIE_SOCKET` environment variable
3. Error

Auth token resolution order:

1. `--token` CLI flag
2. `PLUSHIE_TOKEN` environment variable
3. JSON line from stdin within 1 second: `{"token":"..."}`
4. No token (renderer decides whether that is acceptable)

Address shapes:

- Paths starting with `/` are Unix domain sockets
- `:port` is TCP on localhost
- `host:port` is TCP on the given host

## Transport modes

The renderer communicates with the SDK over a language-agnostic
wire protocol (MessagePack or JSON over a byte stream). `StartOpts`
selects one of three transports.

### Spawn (default)

The SDK spawns the renderer as a child process via an Erlang Port.
Communication happens over the child's stdin and stdout. This is
the default for local development, used by `plushie/gui`.

The bridge manages the port lifecycle: starting, monitoring, and
restarting the renderer on crash with exponential backoff (100ms
base, 5s cap, 5 consecutive failures before giving up). On successful
restart the bridge re-sends settings, re-syncs subscriptions and
windows, replays the current view as a fresh snapshot, discards
stale coalescable events, and fails pending effects with
`renderer_restarted`. The app's model is preserved.

### Stdio

The renderer spawns the Gleam app (via `plushie-renderer --exec "..."`)
and communication happens over the BEAM's own stdin and stdout. The
`binary_path` option is ignored because no subprocess is spawned
from the Gleam side. Use `plushie/stdio.run` as the entry point.

### Iostream(adapter)

A Subject-based adapter for custom transports: SSH channels, TCP
sockets, Unix sockets, WebSockets. The adapter Subject is the pid
of a process that bridges the wire protocol and the underlying
transport. `plushie/socket_adapter` is the built-in adapter used
by `plushie/connect` for Unix-socket and TCP transports;
`plushie/transport/framing` provides length-prefixed frame encode
and decode for custom adapters.

This mode enables remote rendering: the Gleam app runs on one
machine (server, cloud), the renderer runs on another (desktop,
laptop). The wire protocol is identical; only the transport layer
differs. See the [Shared State guide](../guides/16-shared-state.md).

## Test configuration

`plushie/testing` runs tests against a pooled renderer process.
`plushie/testing/session_pool.PoolConfig` tunes the pool:

| Field | Type | Default | Purpose |
|---|---|---|---|
| `mode` | `PoolMode` | `Mock` | `Mock` (`plushie-renderer --mock`, protocol only) or `Headless` (software rendering). |
| `format` | `protocol.Format` | `Msgpack` | Wire format. |
| `max_sessions` | `Int` | `8` | Maximum concurrent sessions. Higher values permit more parallel tests at the cost of renderer memory. |
| `renderer_path` | `Option(String)` | `None` | Explicit binary path; `None` auto-resolves. |

`testing.start()` auto-resolves the pool mode from
`PLUSHIE_TEST_BACKEND` (`mock` or `headless`) at first use. The
pool is shared across all tests in a run.

The windowed backend (real iced windows) is not a pool mode. It
requires a display server and is selected by starting tests under
a compositor such as headless weston. See the
[Testing reference](testing.md) for the complete setup.

Screenshot and snapshot tests compare against golden files. Set
`PLUSHIE_UPDATE_SCREENSHOTS=1` or `PLUSHIE_UPDATE_SNAPSHOTS=1` to
update them instead of asserting.

## See also

- [Subscriptions reference](subscriptions.md) - rate limiting
  hierarchy and `default_event_rate` interactions
- [Commands reference](commands.md) - runtime side effects
- [Events reference](events.md) - the `System(AllWindowsClosed)`
  event that interacts with `daemon`
- [Built-in Widgets reference](built-in-widgets.md) - per-widget
  `EventRate` and `scale_factor` props
