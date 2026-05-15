# CLI Commands

Plushie ships CLI entry points for building and downloading the
renderer binary, plus library modules you wire into your own `main`
for running, inspecting, and scripting Plushie apps. Gleam has no
equivalent of Mix tasks; everything is invoked via
`gleam run -m <module>` against a module that exposes `pub fn main`,
or called programmatically from your app's own entry point.

| Module | Purpose |
|---|---|
| [`plushie/build`](#plushiebuild) | Build the renderer binary from a plushie-rust checkout |
| [`plushie/download`](#plushiedownload) | Download a precompiled renderer binary |
| [`plushie/package`](#plushiepackage) | Build a standalone package payload |
| [`plushie/gui`](#plushiegui) | Library entry for local desktop apps |
| [`plushie/stdio`](#plushiestdio) | Library entry for exec / remote rendering |
| [`plushie/connect`](#plushieconnect) | Library entry for socket-based transport |
| [`plushie/inspect`](#plushieinspect) | Library helper that prints the initial UI tree as JSON |
| [`plushie/script`](#plushiescript) | Library helper that runs `.plushie` test scripts |
| [`plushie/replay`](#plushiereplay) | Library helper that replays a `.plushie` script |
| [`bin/preflight`](#preflight) | Run all CI checks locally |

The two standalone CLIs (`plushie/build` and `plushie/download`)
are runnable directly. The rest are library functions (`run`)
that expect your app value as their first argument. Wire them
into an app-specific module with a `pub fn main` and invoke that
with `gleam run -m`:

```gleam
// src/my_app/gui.gleam
import my_app
import plushie/gui

pub fn main() {
  gui.run(my_app.app(), gui.default_opts())
}
```

```bash
gleam run -m my_app/gui
```

## plushie/build

Builds the renderer binary and/or WASM bundle by shelling out to
the `cargo-plushie` Cargo subcommand.

```bash
gleam run -m plushie/build                          # native binary (default)
gleam run -m plushie/build -- --release             # optimised build
gleam run -m plushie/build -- --wasm                # WASM renderer only
gleam run -m plushie/build -- --bin --wasm          # both
gleam run -m plushie/build -- --verbose             # print cargo output on success
gleam run -m plushie/build -- --bin-file PATH       # override native binary destination
gleam run -m plushie/build -- --wasm-dir PATH       # override WASM output directory
```

Plushie apps run as two processes: your Gleam app (state, events,
UI trees) and a Rust renderer (windowing, GPU, platform
integration). The renderer is a compiled binary that the SDK
communicates with over the wire protocol. This module produces
that binary.

Most apps use `plushie/download` for a precompiled binary and
never build from source. Building is required when you declare
native widgets in `[plushie].native_widgets` in `gleam.toml` or
when working against a local `plushie-rust` checkout.

### Flags

| Flag | Description |
|---|---|
| `--bin` | Build the native binary (default when no selector flag is given) |
| `--wasm` | Build the WASM renderer via `wasm-pack` |
| `--release` | Build with optimisations |
| `--verbose` | Print full Cargo output on success |
| `--bin-file PATH` | Override native binary destination |
| `--wasm-dir PATH` | Override WASM output directory |

`--bin` and `--wasm` can be combined to build both artifacts in
one pass. When neither selector flag nor a path override is
provided, the module falls back to the `artifacts` key in the
`[plushie]` section of `gleam.toml`, defaulting to `bin` only.

### What it generates

The Gleam module writes a minimal virtual app crate that
`cargo-plushie` reads via `cargo metadata`:

- `_build/plushie-renderer-spec/Cargo.toml` - declares each widget
  crate under `[plushie].native_widgets` as a path dependency and
  carries `[package.metadata.plushie]` (binary name, source path).
- `_build/plushie-renderer-spec/src/lib.rs` - stub so
  `cargo metadata` accepts the manifest.

`cargo-plushie` then produces the real workspace and binary:

- `_build/plushie-renderer-spec/target/plushie-renderer/` - the
  generated Cargo workspace.
- `_build/plushie-renderer-spec/target/plushie-renderer/target/<profile>/<bin>` -
  the compiled binary, copied to `bin/plushie-renderer` after a
  successful build.

If `PLUSHIE_RUST_SOURCE_PATH` is set, `cargo-plushie` emits
`[patch.crates-io]` redirecting plushie crates to the local
checkout.

### cargo-plushie resolution

The module resolves `cargo-plushie` in this order:

1. `PLUSHIE_RUST_SOURCE_PATH` set: invoked via
   `cargo run -p cargo-plushie ...` against the checkout. Always
   works during local plushie-rust development.
2. Otherwise, expect `cargo-plushie` on `PATH` at the version
   pinned by `plushie_rust_version` in `gleam.toml`. Install with
   `cargo install cargo-plushie --version <version> --locked`.
3. Missing or mismatched: fails with an install hint. There is no
   auto-install.

### Native widget metadata

Widget crates listed in `[plushie].native_widgets` must declare
`[package.metadata.plushie.widget]` in their own `Cargo.toml`,
with `type_name` and `constructor` keys. `cargo-plushie` reads
these tables via `cargo metadata` and refuses to build a crate
without them. Use `cargo plushie new-widget <name>` to scaffold a
widget crate with the correct layout.

### Local source versus crates.io

By default, Rust dependencies come from crates.io at the version
in `plushie_rust_version`. To build against a local renderer
checkout:

```bash
git clone https://github.com/plushie-ui/plushie-rust ../plushie-rust
PLUSHIE_RUST_SOURCE_PATH=../plushie-rust gleam run -m plushie/build
```

`PLUSHIE_RUST_SOURCE_PATH` can also be set via `source_path` in
the `[plushie]` section of `gleam.toml`.

### WASM builds

```bash
gleam run -m plushie/build -- --wasm
gleam run -m plushie/build -- --wasm --release
```

WASM builds always run against a local plushie-rust checkout.
`PLUSHIE_RUST_SOURCE_PATH` (or `[plushie].source_path`) must
point at one, and `wasm-pack` must be on `PATH`. The output files
(`plushie_renderer_wasm.js` and `plushie_renderer_wasm_bg.wasm`)
are copied from the WASM crate's `pkg/` to `priv/wasm/` by
default, or to `--wasm-dir` if provided.

### Requirements

- Rust toolchain with `cargo` on `PATH`. `rustc` 1.92 or newer is
  expected; older versions produce a warning but do not fail the
  build.
- `cargo-plushie` at the matching `plushie_rust_version`, or
  `PLUSHIE_RUST_SOURCE_PATH` set to a local plushie-rust checkout.
- For WASM: `wasm-pack` on `PATH` and a local plushie-rust
  checkout.

## plushie/download

Downloads the precompiled native tool set from GitHub releases.

```bash
gleam run -m plushie/download                       # native binary (default)
gleam run -m plushie/download -- --wasm             # WASM renderer only
gleam run -m plushie/download -- --bin --wasm       # both
gleam run -m plushie/download -- --force            # re-download even if present
gleam run -m plushie/download -- --bin-file PATH    # override native binary destination
gleam run -m plushie/download -- --wasm-dir PATH    # override WASM output directory
```

The release assets are platform-specific (OS and architecture) and
version-matched to the SDK via `plushie_rust_version` in `gleam.toml`.
The default native path installs `bin/plushie`, then uses it to sync
`bin/plushie-renderer` and `bin/plushie-launcher`.

### Flags

| Flag | Description |
|---|---|
| `--bin` | Download the native binary (default when no selector flag is given) |
| `--wasm` | Download the WASM renderer tarball |
| `--force` | Re-download even if the target files already exist |
| `--bin-file PATH` | Override native binary destination |
| `--wasm-dir PATH` | Override WASM output directory |

Selector resolution matches `plushie/build`: CLI flags win, then
the `artifacts` key in `[plushie]`, defaulting to `bin` only.

### Destinations

- Native tool set: `bin/plushie`, `bin/plushie-renderer`, and
  `bin/plushie-launcher` by default.
- WASM tarball: extracted to `priv/wasm/` by default, producing
  `plushie_renderer_wasm.js` and `plushie_renderer_wasm_bg.wasm`.

### Checksum verification

Every download is verified against a `.sha256` file fetched from
the same GitHub release. On mismatch, the downloaded file is
deleted and the module exits with status 1. If the checksum file
itself cannot be fetched, the artifact is deleted and the module
exits rather than trust an unverified binary. There is no flag to
skip verification.

### Release mirrors

By default downloads come from GitHub releases. Set
`PLUSHIE_RELEASE_BASE_URL` to verify the same flow against another
release mirror. The mirror must expose assets as
`BASE/vVERSION/ARTIFACT` with checksum sidecars at
`BASE/vVERSION/ARTIFACT.sha256`.

Remote mirrors must use HTTPS. `file://` mirrors and loopback HTTP are
for local release verification before assets are uploaded.

## plushie/package

Builds an Erlang shipment payload and `plushie-package.toml` manifest
for the shared Rust launcher.

```bash
gleam run -m plushie/package -- \
  --app-id dev.example.my_app \
  --app-name "My App" \
  --connect-module my_app@connect

bin/plushie package portable --manifest dist/plushie-package.toml
```

This module owns the Gleam-specific part of standalone packaging:

- Runs `gleam export erlang-shipment`.
- Copies the shipment into `dist/payload/`.
- Bundles the active Erlang runtime by default.
- Places the selected renderer in the payload.
- Writes `bin/connect`, which starts the shipment and calls the
  configured connect module.
- Writes app icon assets under `dist/payload/assets/` and sets
  `[platform].icon` in `dist/plushie-package.toml`.
- Archives the payload as `dist/payload.tar.zst`.
- Writes `dist/plushie-package.toml` for `cargo plushie package`.

The shared Rust package command remains language-agnostic. It consumes
the manifest and embedded payload archive produced here. By default,
the package command prints the final
`bin/plushie package portable --manifest ...` handoff after writing the
manifest. Pass `--portable` to run that final step immediately.
Pass `--strict-tools` with `--portable` to have the Rust package tool
reject missing, stale, dirty, mixed, or mismatched native tools.
Run `bin/plushie package check --manifest dist/plushie-package.toml
--strict-tools` to check that gate before building the portable
launcher.

### Flags

| Flag | Description |
|---|---|
| `--app-id ID` | Package app identifier. Required |
| `--app-name NAME` | Display app name |
| `--app-version VERSION` | App version. Defaults to `version` in `gleam.toml` |
| `--connect-module MODULE` | Erlang module whose `main/0` connects the app. Required |
| `--dist-dir DIR` | Output directory. Defaults to `dist` |
| `--icon PATH` | App icon PNG to copy into payload assets. Defaults to Plushie's bundled icon |
| `--payload-archive NAME` | Payload archive filename. Defaults to `payload.tar.zst` |
| `--portable` | Run `bin/plushie package portable --manifest <manifest>` after writing the manifest |
| `--portable-out PATH` | Pass `--out PATH` to the portable package command when `--portable` is set |
| `--strict-tools` | Pass `--strict-tools` to the portable package command when `--portable` is set |
| `--renderer-kind stock|custom` | Renderer selection. Defaults to `stock` |
| `--renderer-path PATH` | Use an existing renderer binary |
| `--release` | Build a release custom renderer when `--renderer-kind custom` builds the renderer |
| `--erlang-provider local|path|mise` | Runtime source. Defaults to `local`, or `path` when `--erlang-root` / `PLUSHIE_ERLANG_ROOT` is set |
| `--erlang-root PATH` | Erlang runtime root for the `path` provider |
| `--erlang-version VERSION` | Erlang version passed to `mise where erlang@VERSION` for the `mise` provider |

Apps with `[plushie].native_widgets` must use
`--renderer-kind custom`, because a stock renderer cannot include those
widget crates. If no `--renderer-path` is supplied for a custom
renderer, the package command delegates to `plushie/build`.

When `--icon` is omitted, the command invokes `cargo-plushie
default-icons --out <payload-assets-dir>` before the payload archive is
created and uses `assets/plushie-checkbox-512x512.png` as the manifest
icon path. With `PLUSHIE_RUST_SOURCE_PATH` set, it invokes the tool
from that checkout with `cargo run --manifest-path
$PLUSHIE_RUST_SOURCE_PATH/Cargo.toml -p cargo-plushie -- default-icons
...`. With `--icon`, the provided file is copied into payload assets
and referenced with a payload-relative path.

### Erlang runtime

By default, the package command copies the active Erlang runtime into
the payload so the portable launcher can run on machines without
`erl` on `PATH`. Runtime roots are OS and architecture specific, so
release builds should run on matching target runners until
cross-target runtime downloads are proven.

Runtime provider options:

- `--erlang-provider local` uses the active `erl` on `PATH` and asks it
  for `code:root_dir()`.
- `--erlang-provider path --erlang-root PATH` copies an explicit
  extracted Erlang runtime root.
- `--erlang-provider mise --erlang-version VERSION` runs
  `mise where erlang@VERSION` and copies that extracted runtime root.

Environment equivalents are `PLUSHIE_ERLANG_PROVIDER`,
`PLUSHIE_ERLANG_ROOT`, and `PLUSHIE_ERLANG_VERSION`. Set
`PLUSHIE_BUNDLE_ERLANG=0` to skip runtime bundling for development
proofs.

When switching between Erlang installations, run `gleam clean` before
packaging. Gleam build artifacts are tied to the Erlang runtime that
compiled them.

## plushie/gui

Library module for starting a local Plushie desktop application.
Resolves the renderer binary, starts the runtime (which spawns
the renderer as a child port over stdio), and blocks the calling
process until the runtime exits.

```gleam
import plushie/gui

pub fn main() {
  gui.run(my_app.app(), gui.default_opts())
}
```

### GuiOpts

| Field | Type | Description |
|---|---|---|
| `json` | `Bool` | Use JSON wire format instead of MessagePack. Default: `False` |
| `daemon` | `Bool` | Keep running after all windows close. Default: `False` |
| `dev` | `Bool` | Enable dev-mode live reload. Default: `False` |
| `debounce` | `Int` | File-watch debounce in milliseconds. Default: `100` |
| `binary_path` | `Result(String, Nil)` | Explicit binary path; `Error(Nil)` auto-resolves |

### Daemon mode

In either mode, closing all windows delivers
`System(AllWindowsClosed)` to `update`. Without `daemon`, the
runtime shuts down after that update. With `daemon: True`, it
keeps running so the app can open new windows, show a tray menu,
and so on.

### Dev mode

With `dev: True`, a dev server actor watches `src/` for `.gleam`
changes, runs `gleam build` as a subprocess, hot-loads changed
BEAM modules, and signals the runtime to re-render. The app's
model is preserved across reloads; only the view tree and any
state the renderer owns are replaced. The `debounce` field
controls the debounce timer; the default is 100 ms.

Requires the `file_system` Hex package in your `[dependencies]` and
Elixir installed. See [Dev mode and hot reload](app-lifecycle.html#dev-mode-and-hot-reload).

### Binary resolution

`plushie/gui` calls into `plushie/binary` to find the renderer.
Resolution order:

1. The `binary_path` field on `GuiOpts`, if set (explicit).
2. `PLUSHIE_BINARY_PATH` environment variable.
3. `bin/plushie-renderer` (downloaded or installed binary).
4. `_build/dev/plushie-renderer/target/release/plushie-renderer`
   or `_build/prod/...` (custom builds).
5. `./plushie-renderer`,
   `../plushie-renderer/target/release/plushie-renderer`,
   `../plushie-renderer/target/debug/plushie-renderer`.

Steps 1 and 2 raise immediately if the path points at a missing
file. The remaining steps are silent fall-through. If nothing is
found the module prints install hints (download, build, or
`PLUSHIE_BINARY_PATH`) and exits with status 1.

## plushie/stdio

Library module for running a Plushie app in stdio transport mode.
The Rust renderer spawns the Gleam process (not the other way
around) and communicates over stdin and stdout. Use this when
embedding Plushie in a larger host that manages the renderer
lifecycle externally.

```gleam
import plushie/stdio

pub fn main() {
  stdio.run(my_app.app(), stdio.default_opts())
}
```

### StdioOpts

| Field | Type | Description |
|---|---|---|
| `format` | `protocol.Format` | Wire format. Default: `Msgpack` |
| `daemon` | `Bool` | Keep running after all windows close. Default: `False` |

All log output is routed to stderr so that stdout remains a clean
protocol channel. The runtime blocks until stdin closes.

## plushie/connect

Library module for connecting to an already-listening renderer
via a Unix domain socket or TCP port. The renderer runs somewhere
else and listens on a socket; this module connects to it and
speaks the same wire protocol a local renderer would.

```gleam
import plushie/connect

pub fn main() {
  connect.run(my_app.app(), connect.default_opts())
}
```

### ConnectOpts

| Field | Type | Description |
|---|---|---|
| `format` | `protocol.Format` | Wire format. Default: `Msgpack` |
| `daemon` | `Bool` | Keep running after all windows close. Default: `False` |

### Socket and token resolution

The socket address is resolved in order:

1. `--socket` CLI flag.
2. `PLUSHIE_SOCKET` environment variable.

If neither is set, the module prints an error and exits with
status 1.

The authentication token is resolved in order:

1. `--token` CLI flag.
2. `PLUSHIE_TOKEN` environment variable.
3. A JSON negotiation line on stdin (1-second timeout) of the
   form `{"token":"..."}`.
4. No token (the renderer decides whether that is acceptable).

When a token is available, the SDK sends `settings.token_sha256` in the
Settings message. It does not send the plaintext token to the renderer.

### Address formats

- Paths beginning with `/`: Unix domain socket.
- `:port`: TCP on `localhost` at that port.
- `host:port`: TCP on the specified host and port.

## plushie/inspect

Library helper that prints a Plushie app's initial UI tree as
JSON, without starting a renderer. Useful for debugging layout
structure, verifying prop values, checking scoped IDs after
normalization, and sanity-checking `view` with a fresh model.

```gleam
import plushie/inspect

pub fn main() {
  inspect.run(my_app.app())
}
```

The helper calls `init` with a nil argument, renders the view,
normalizes the tree, converts it to a `PropValue`, and prints it
as JSON to stdout. No renderer binary is needed; everything runs
in Gleam.

If inspect cannot produce JSON, it prints a concise error to stderr
with the failed phase (`app init`, `app view`, `tree normalization`,
or `JSON encoding`) and exits nonzero.

## plushie/script

Library helper that runs `.plushie` automation scripts
headlessly. Each script starts a fresh app session against the
mock backend, executes the instructions, and reports pass / fail.

```gleam
import plushie/script

pub fn main() {
  script.run(["test/scripts/smoke.plushie"], my_app.app())
}
```

`run` takes a list of script paths. If the list is empty it
currently returns without running anything; automatic discovery
of scripts under `test/scripts/` is not implemented, so callers
must pass explicit paths.

On any parse or assertion failure, the helper prints the failing
assertions and exits with status 1.

## plushie/replay

Library helper that replays a single `.plushie` script with the
windowed backend (real windows, real timing). Useful for
visually verifying an automation sequence or producing demo
recordings.

```gleam
import plushie/replay

pub fn main() {
  replay.run("demo.plushie", my_app.app())
}
```

Select the windowed backend by setting
`PLUSHIE_TEST_BACKEND=windowed` before running. On a headless
host, run behind a display server (for example a headless
weston socket; see the [Testing reference](testing.md)).

## preflight

`bin/preflight` runs the full CI check suite locally, stopping at
the first failure.

```bash
./bin/preflight
```

Steps, in order:

1. `gleam format --check` - formatting.
2. `gleam build` - compile the BEAM target.
3. `gleam build --target=javascript` - compile the JS / WASM
   target (source only; test-file errors are ignored because
   tests may use BEAM-only APIs).
4. `gleam test` - test suite against the mock backend.
5. `PLUSHIE_TEST_BACKEND=headless gleam test` - test suite
   against the headless backend.

Gleam has no separate lint or type-check step; the compiler
covers both. If preflight passes, CI passes.

## Environment variables

| Variable | Effect |
|---|---|
| `PLUSHIE_BINARY_PATH` | Explicit path to the renderer binary. Errors if set but missing |
| `PLUSHIE_RUST_SOURCE_PATH` | Path to a local plushie-rust checkout. Switches builds to source mode, pins `cargo-plushie` to the checkout, and enables WASM builds |
| `PLUSHIE_SOCKET` | Default socket address for `plushie/connect` |
| `PLUSHIE_TOKEN` | Fallback authentication token for `plushie/connect`; sent as `settings.token_sha256` |
| `PLUSHIE_TEST_BACKEND` | Selects the test backend: `mock` (default), `headless`, or `windowed` |
| `PLUSHIE_TEST_TIMEOUT` | Positive integer multiplier for test infrastructure timeouts |
| `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR` | Required for the windowed test backend on a headless host with a weston socket |
| `RUST_LOG` | Passed through to the renderer for tracing-based logging |

## See also

- [Versioning reference](versioning.md) - the relationship
  between the SDK version, `plushie_rust_version`, and the
  renderer binary
- [Commands reference](commands.md) - the command values returned
  from `update` that the runtime executes
- [Events reference](events.md) - including `System(AllWindowsClosed)`
