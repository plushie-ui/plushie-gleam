# Packaging and Distribution

`gleam run -m plushie/package` turns a Plushie app into a self-contained
artifact that ships with its own Erlang runtime and Plushie renderer.
The output is either a portable single-file executable or an OS-native
installer (AppImage, `.dmg`, `.msi`). The recipient does not need
Gleam, Erlang, or anything else installed.

When the artifact runs, the launcher extracts the payload, starts the
bundled `erl` against the Erlang shipment, calls the app's connect
module, and the app starts its renderer from inside the payload. The
flow is the same as `plushie/gui`, just running from an extracted
directory instead of your project.

| Section | Topic |
|---|---|
| [Quickstart](#quickstart) | Three commands from a working app to a portable artifact |
| [The packaging pipeline](#the-packaging-pipeline) | How the SDK, cargo-plushie, and the launcher hand off |
| [plushie/package](#plushiepackage) | Flags and what the module owns |
| [The payload](#the-payload) | What goes in `dist/payload/` |
| [Source layout](#source-layout) | What to commit and what to gitignore |
| [Renderer selection](#renderer-selection) | Stock versus custom |
| [Bundled assets](#bundled-assets) | Icons, fonts, and other payload files |
| [The Erlang shipment and runtime](#the-erlang-shipment-and-runtime) | What gets bundled and how to slim it |
| [The managed tool set](#the-managed-tool-set) | `bin/plushie`, renderer, launcher |
| [The partial manifest](#the-partial-manifest) | TOML the SDK writes |
| [Package config](#package-config) | `plushie-package.config.toml` schema |
| [Forwarded environment](#forwarded-environment) | Host process environment policy |
| [Building artifacts](#building-artifacts) | Portable executable and OS installers |
| [Distribution](#distribution) | Release asset layout |
| [Continuous integration](#continuous-integration) | GitHub Actions workflow |
| [Signing](#signing) | Developer-driven signing hooks |
| [Updates](#updates) | `[updates]` schema |
| [Host-first versus renderer-parent](#host-first-versus-renderer-parent) | Default launch model and the alternative |

## Quickstart

Three commands take a working app to a portable artifact:

```bash
gleam run -m plushie/download                                                   # install Plushie tool set
gleam run -m plushie/package -- --app-id dev.example.my_app \
  --connect-module my_app@connect                                                # build payload + manifest
bin/plushie package portable --manifest dist/plushie-package.toml                # produce the artifact
```

Output lands under `target/plushie/package/`. `--app-id` and
`--connect-module` are the required flags. The connect module name is
the Erlang form of the Gleam module that calls `connect.run` or
`gui.run` (Gleam's `my_app/connect` compiles to Erlang module
`my_app@connect`).

## The packaging pipeline

A packaged app moves through three stages:

1. **SDK build.** `gleam run -m plushie/package` exports the Erlang
   shipment, copies it and a renderer into `dist/payload/`, optionally
   bundles the Erlang runtime, writes a `bin/start_host` wrapper, and
   emits a partial `dist/plushie-package.toml` carrying SDK identity,
   version pins, target triple, and the renderer descriptor.
2. **Manifest assembly.** The package module then shells out to
   `bin/plushie package assemble`. cargo-plushie validates the
   payload, reads `plushie-package.config.toml` for `[start]` defaults
   and `[platform]` metadata, materialises the icon, archives the
   payload, computes its SHA-256 and size, and fills in the rest of
   `plushie-package.toml`.
3. **Artifact build.** `bin/plushie package portable` produces a
   self-extracting single-file executable. `bin/plushie package bundle`
   produces OS-native installers via
   [cargo-packager](https://github.com/crabnebula-dev/cargo-packager).
   Both consume the same completed manifest.

Stage 1 is Gleam-specific. Stages 2 and 3 are language-agnostic and
shared across every Plushie SDK; the same `bin/plushie` tool that
assembles a Gleam payload assembles an Elixir or Python payload.

## plushie/package

Stage 1 of the pipeline. The module compiles the project, runs
`gleam export erlang-shipment`, assembles the payload directory,
writes the partial manifest, and shells to `bin/plushie package
assemble` to complete it.

| Flag | Description |
|---|---|
| `--app-id ID` | Package app identifier. Required. |
| `--app-name NAME` | Display app name. Used by cargo-plushie for OS-native bundles. |
| `--app-version VERSION` | App version. Defaults to `version` in `gleam.toml`. |
| `--connect-module MODULE` | Erlang module whose `main/0` connects the app. Required. |
| `--dist-dir DIR` | Output directory. Defaults to `dist`. |
| `--renderer-kind stock\|custom` | Renderer selection. Defaults to `stock`. |
| `--renderer-path PATH` | Use an existing renderer binary. |
| `--package-config PATH` | Use a non-default `plushie-package.config.toml` path. Auto-detected if present. |
| `--write-package-config` | Write a `plushie-package.config.toml` template and exit. |
| `--erlang-provider local\|path\|mise` | Runtime source. Defaults to `local`, or `path` when `--erlang-root` is set. |
| `--erlang-root PATH` | Erlang runtime root for the `path` provider. |
| `--erlang-version VERSION` | Erlang version for the `mise` provider. |

`--app-id` is a reverse-DNS identifier in the
`namespace.[subnamespace.]app` form (`dev.example.my_app`,
`com.acme.invoice`). cargo-plushie validates the format during
assembly.

`--connect-module` names the Erlang module the launcher invokes.
Gleam compiles `src/my_app/connect.gleam` to the Erlang module
`my_app@connect`, so the flag value uses the `@` form. The module
must expose `pub fn main` and typically calls `connect.run`,
`gui.run`, or `stdio.run`:

```gleam
// src/my_app/connect.gleam
import my_app
import plushie/connect

pub fn main() {
  connect.run(my_app.app(), connect.default_opts())
}
```

The output directory is rebuilt from scratch on every run. Anything
under `dist/` from a previous run is removed before the new payload
is assembled.

## The payload

`dist/payload/` is the directory that gets archived into the artifact:

```
dist/
  plushie-package.toml           # manifest (partial then completed)
  payload/
    bin/
      start_host                 # POSIX entry script
      start_host.cmd             # Windows entry script (windows-* targets)
      plushie-renderer           # payload-local renderer copy
    shipment/                    # gleam export erlang-shipment output
      my_app-0.1.0/ebin/         # compiled BEAM modules per OTP app
      gleam_stdlib-0.x.y/ebin/
      ...
    runtime/
      erlang/                    # bundled Erlang runtime (when enabled)
        bin/erl, erts-X.Y.Z/, lib/, releases/
    assets/                      # icon and other files from package_assets/
                                 #   (see Bundled assets below)
```

`bin/start_host` (or `bin/start_host.cmd` on Windows) is a small shell
wrapper. It locates `erl` (preferring the bundled runtime at
`runtime/erlang/bin/erl`, falling back to `erl` on `PATH`), adds every
OTP app under `shipment/*/ebin` to the code path, and evaluates
`<connect-module>:main().`. The shared package launcher runs this entry
script with `PLUSHIE_BINARY_PATH` set to the payload-local renderer,
and `connect.run` (or `gui.run`) starts that renderer through the
normal binary resolution path. The packaged app never reaches out to
the system `PATH` or a download cache; everything it needs is inside
the extracted payload.

## Source layout

Packaging adds project-owned files that belong in version control and
generated files that do not. Knowing which is which avoids accidentally
committing platform-specific binaries or losing project-owned config.

| Path | What it is | Commit or gitignore |
|---|---|---|
| `plushie-package.config.toml` | Package config: start command, forward_env, platform metadata. Like `gleam.toml`. | Commit. |
| `package_assets/` | Project-owned icon, fonts, and other files copied verbatim into the payload. | Commit. |
| `gleam.toml` | Carries `plushie_rust_version` (read to fetch the matching tool set). | Already committed. |
| `bin/` | Plushie tool set installed by `gleam run -m plushie/download`: `plushie`, `plushie-renderer`, `plushie-launcher`. Platform-specific binaries. | Gitignore. |
| `dist/` | Package output: payload directory and manifest. Rebuilt by every `plushie/package` run. | Gitignore. |
| `target/plushie/` | Portable and bundle artifacts produced by `bin/plushie package portable` / `bundle`. | Gitignore. |
| `build/` | Standard Gleam build output, including `build/erlang-shipment/`. | Already in default `.gitignore`. |

A minimum `.gitignore` for a packaging-enabled project looks like:

```
/build/
/bin/
/dist/
/target/
```

`gleam run -m plushie/download`, `gleam run -m plushie/package`, and
`bin/plushie package portable` each check whether their output path is
gitignored when run inside a git repository. If it is not, they print a
one-paragraph warning naming the directory and the line to add. The
command still succeeds; the warning is just a nudge.

## Renderer selection

The module picks a renderer based on whether your project declares
[native widgets](custom-widgets.md) (Rust-backed widgets that ship
their own crate):

- **No native widgets.** A stock renderer is bundled. By default, it
  comes from the managed tool set installed by `gleam run -m
  plushie/download`.
- **Native widgets present.** A custom renderer is built by shelling
  to `gleam run -m plushie/build -- --release`, which generates a
  Cargo workspace containing each widget crate listed in
  `[plushie].native_widgets`.

Override the auto-detection with `--renderer-kind stock|custom`.
Requesting `--renderer-kind stock` for an app that declares native
widgets fails fast, because a stock renderer cannot include those
widget crates.

Use `--renderer-path PATH` to package a specific binary. This skips
the download or build step and copies the file you point at directly
into the payload. The payload-local path is always
`bin/plushie-renderer` regardless of whether the renderer is stock or
custom.

## Bundled assets

A packaged app needs two kinds of files beyond the BEAM modules
themselves: the icon and other OS-bundle metadata that cargo-plushie
reads from the manifest, and runtime assets that your app loads at
startup (fonts, images, data files). Each has a different home.

### App-loaded assets (priv/)

Anything your app reads at runtime through `priv/` follows Gleam's
standard convention. `gleam export erlang-shipment` copies each OTP
app's `priv/` directory into `shipment/<app>-<vsn>/priv/`, and the
resolver works the same packaged or unpackaged. Use Erlang's
`code:priv_dir/1` from a small FFI or any helper your project
already uses:

```gleam
@external(erlang, "code", "priv_dir")
fn priv_dir(app: atom.Atom) -> Result(charlist.Charlist, atom.Atom)
```

Reference these paths from `app.Settings.fonts`,
`plushie/command/image`, or any widget that takes a file path. There
is no separate packaging step. If it works under `gleam run`, it
works packaged.

### Package-level assets (package_assets/)

Files that need to live inside the payload at a known location, such
as the OS bundle icon referenced from `[platform].icon`, go in a
`package_assets/` directory next to `plushie-package.config.toml`.
cargo-plushie copies the contents verbatim into the payload root
during `bin/plushie package assemble`:

```
my_app/
├── gleam.toml
├── plushie-package.config.toml
└── package_assets/
    ├── icon.png                # ends up at payload/icon.png
    └── fonts/
        └── extra.ttf           # ends up at payload/fonts/extra.ttf
```

The convention is zero-config: if `package_assets/` exists, it is
used. To use a different directory name, set `[assets].dir` in the
package config:

```toml
[assets]
dir = "branding"
```

Asset files overwrite SDK-generated payload files when the names
collide, so a `package_assets/bin/start_host` would replace the
generated entry script. Use this for overrides, not by accident; the
default layout has no overlap.

### Icon

cargo-plushie looks for an icon at the path named in `[platform].icon`
inside the payload. If no path is set and a file already exists at
`assets/default-app-icon-512.png`, that path is recorded. If nothing
exists at either location, cargo-plushie writes the built-in default
icon to `assets/default-app-icon-512.png` and records that path.

**Format:** PNG with RGBA alpha channel for transparency.

**Dimensions:** square aspect ratio, 512x512 minimum. cargo-packager
scales this single source down for `.ico` (16/32/48/64/128/256) and
up or down for `.icns` (16/32/64/128/256/512/1024). Provide 1024x1024
or larger if the same icon will be used for retina displays or
high-DPI Windows installers.

To use a custom icon, put a PNG in `package_assets/` and reference it
from `[platform].icon`:

```toml
[platform]
icon = "icon.png"               # payload-relative; resolves to payload/icon.png
                                # after package_assets/icon.png is copied
```

The schema accepts a single icon path. Multi-size sources and
per-platform `.icns`/`.ico` overrides are not yet supported.

## The Erlang shipment and runtime

`plushie/package` delegates BEAM bundling to `gleam export
erlang-shipment`, the standard Gleam tool for producing a deployable
Erlang artifact. The module runs the export internally and copies the
result into `dist/payload/shipment/`. Every OTP application your
project depends on appears under that directory as
`<app>-<vsn>/ebin/` (and `priv/` if the app has one).

The shipment by itself is not enough: it needs an Erlang runtime to
execute the BEAM modules. `plushie/package` bundles one into
`payload/runtime/erlang/` so the launcher works on machines without
`erl` on `PATH`.

### Runtime providers

The runtime to bundle is selected by `--erlang-provider`, which picks
from three modes:

- `--erlang-provider local` (default) uses the active `erl` on `PATH`
  and asks it for `code:root_dir()`. Build on a runner that matches
  the target OS and architecture.
- `--erlang-provider path --erlang-root PATH` copies an explicit
  extracted Erlang runtime root. Use this when CI installs runtimes
  via a tool that resolves paths externally.
- `--erlang-provider mise --erlang-version VERSION` runs `mise where
  erlang@VERSION` and copies that extracted runtime root. Use this
  on developer machines or CI that already manages runtimes through
  [mise](https://mise.jdx.dev/).

The corresponding environment variables `PLUSHIE_ERLANG_PROVIDER`,
`PLUSHIE_ERLANG_ROOT`, and `PLUSHIE_ERLANG_VERSION` mirror the flags.

Cross-target runtime bundling (a Linux runtime on a macOS runner, for
example) is not currently a supported flow. Build on a matching
runner per target.

### Skipping the runtime

Set `PLUSHIE_BUNDLE_ERLANG=0` to produce a payload without a bundled
runtime. The resulting artifact will require `erl` on `PATH` at run
time. This is useful for development proofs and for environments
where Erlang is already managed by the target host, but it is not
recommended for general distribution.

### Switching Erlang versions

Gleam build artifacts are tied to the Erlang runtime that compiled
them. When switching between Erlang installations, run `gleam clean`
before packaging so the shipment is rebuilt against the current
runtime.

### Slimming the runtime

The bundled runtime is the dominant size contributor in a packaged
app. `plushie/package` copies a minimum viable set out of the
selected root: `bin/`, `releases/`, the matching `erts-*` directory,
and the `crypto`, `kernel`, `sasl`, and `stdlib` OTP applications.
Other applications are omitted unless your shipment depends on them
through normal Gleam package resolution.

Going further from there means trimming the ERTS directory by hand
(building a pre-stripped runtime root and pointing
`--erlang-provider path` at it). This is possible but brittle. ERTS
layout changes between OTP versions, and removing the wrong file
surfaces as a runtime crash that does not reproduce on the build
machine. If you go that route, gate it behind a smoke test that
launches the packaged app on a clean target machine before each
release.

## The managed tool set

`gleam run -m plushie/download` installs three executables under
`bin/`:

| File | Role |
|---|---|
| `plushie` | Orchestration tool. Owns `tools sync`, `package assemble`, `package portable`, `package bundle`. |
| `plushie-renderer` | The renderer binary used at runtime. Resolved by `plushie/binary`. |
| `plushie-launcher` | The shared launcher used by `package portable` to build the self-extracting artifact. |

The version of each file matches the `plushie_rust_version` pin in
`gleam.toml`. `gleam run -m plushie/download` downloads `plushie`
first, then invokes `bin/plushie tools sync --required-version
VERSION` to fetch the matching renderer and launcher.

`gleam run -m plushie/package` requires all three files. The renderer
is copied into the payload, `plushie` runs the assemble step, and
`plushie-launcher` is the substrate that `package portable` wraps the
payload with. The module raises early if any are missing and prints a
download hint.

The Windows variants of these files carry an `.exe` suffix. The tool
name (`plushie` versus `plushie.exe`) is platform-specific; the role
is the same.

## The partial manifest

`plushie/package` writes a TOML document with everything the SDK
knows: identity, versions, target, and the renderer descriptor. A
minimal partial manifest looks like:

```toml
schema_version = 1
app_id = "dev.example.my_app"
app_version = "0.1.0"
target = "linux-x86_64"
host_sdk = "gleam"
host_sdk_version = "0.6.0"
plushie_rust_version = "0.7.1"
protocol_version = 1

[start]
command = ["bin/start_host"]

[renderer]
path = "bin/plushie-renderer"
kind = "stock"
```

`bin/plushie package assemble` reads this file plus the payload
directory and writes the completed manifest in place. The completed
manifest adds:

- A `[payload]` section with the archive hash, size, and compression
  format.
- `[start].working_dir` and `[start].forward_env` defaults from the
  package config.
- A `[platform]` block if one is set in the package config.
- A `[platform].icon` entry pointing at the materialised icon image
  (a built-in default is written into the payload when no icon is
  declared and none exists at `assets/default-app-icon-512.png`).

The split exists so that cargo-plushie owns the cross-SDK schema
once. Every Plushie SDK writes a partial manifest in this shape and
hands the rest to the same `package assemble` step.

## Package config

Optional defaults for the assemble step live in
`plushie-package.config.toml` at the project root. Generate a
template with:

```bash
gleam run -m plushie/package -- --write-package-config
```

The template includes all supported fields commented out:

```toml
# Plushie standalone package config.
# Commit this file and edit it when the packaged app needs a
# different entry point, working directory, or forwarded environment.

config_version = 1

[start]
# Relative to the extracted app package.
working_dir = "."
# Structured argv. The first item is the packaged host executable.
# bin/start_host is the POSIX entry point.
# On windows-* targets the SDK automatically uses bin/start_host.cmd.
command = ["bin/start_host"]
# Environment variable names copied from the parent process.
forward_env = [
  "PATH",
  "HOME",
  "LANG",
  "LC_ALL",
  "XDG_RUNTIME_DIR",
  "WAYLAND_DISPLAY",
  "DISPLAY",
]

# [assets]
# # Project-relative directory copied verbatim into the payload root
# # during package assembly. When this section is absent, a directory
# # named `package_assets/` next to this config file is used by
# # convention if it exists.
# dir = "package_assets"

# Optional platform metadata passed through to the launcher manifest.
# Uncomment and fill in any fields you need.
# [platform]
# publisher = "Example Corp"
# copyright = "Copyright 2025 Example Corp"
# category = "Utility"
# description = "A short description of your app"
# bundle_id = "dev.example.my_app"  # macOS: defaults to app_id
# icon = "assets/icon.png"          # set via --icon flag; listed here for reference

# [platform.macos]
# bundle_version = "1"  # CFBundleVersion; defaults to app_version

# [platform.windows]
# install_scope = "perUser"  # perUser or perMachine
```

`[start].working_dir` is relative to the extracted payload root.
`[start].command` is a structured argv; the first element is the
host entry script. The SDK substitutes `bin/start_host.cmd` for
`bin/start_host` automatically on `windows-*` targets.

`[start].forward_env` is the list of environment variable **names**
copied from the parent process into the host process at launch
time. Names only; values are never logged or recorded. The defaults
cover the variables a typical Linux GUI app needs. Add more entries
when your app reads additional environment, for example `RUST_LOG`
during development.

The `[platform]` block populates OS-native bundle metadata. All
fields are optional. `bundle_id` defaults to `app_id`. The
`[platform.macos]` and `[platform.windows]` subtables carry
OS-specific fields and are also optional.

Use `--package-config PATH` to point at a config file outside the
project root.

## Forwarded environment

The package launcher does not blanket-inherit the user's environment.
It builds the host process environment from two closed sources:

- The Plushie reserved namespace (`PLUSHIE_BINARY_PATH`, plus a small
  set of internal coordination variables that the launcher sets
  itself).
- The names listed in `[start].forward_env`.

Variables outside both sets are dropped. This matches the
`plushie/renderer_env` allowlist that the SDK uses to bound the
renderer subprocess environment, and gives packaged apps a
predictable, narrow runtime environment regardless of where the
launcher is invoked from.

## Building artifacts

Once the manifest is complete, the same payload feeds two artifact
shapes.

### Portable single-file launcher

```bash
bin/plushie package portable --manifest dist/plushie-package.toml
```

Produces a self-extracting executable wrapping `plushie-launcher` and
the archived payload. Output lands under `target/plushie/package/`
by default; pass `--out PATH` to override. The artifact is
content-addressed by the payload hash, so two builds of the same
inputs produce a byte-identical executable.

The launcher extracts the payload to a per-user cache directory keyed
by the payload hash. Repeated runs of the same artifact reuse the
extraction.

### OS-native installers

```bash
bin/plushie package bundle --manifest dist/plushie-package.toml --format appimage
bin/plushie package bundle --manifest dist/plushie-package.toml --format dmg --format app
bin/plushie package bundle --manifest dist/plushie-package.toml --format nsis
```

`--format` is repeatable; pass it once per format. Delegates to
[cargo-packager](https://github.com/crabnebula-dev/cargo-packager) for
AppImage (Linux), `.app` and `.dmg` (macOS), and Windows installers
produced via the `nsis` and `wix` formats. AppImage, `.app`, and
`.dmg` are real file extensions; `nsis` and `wix` are cargo-packager
format identifiers, not extensions (their output is `.exe` and `.msi`
respectively). Format availability depends on the runner: Apple
formats need a macOS runner, Windows formats need a Windows runner.

Both commands default to a strict-tools check: they verify that the
launcher, renderer, and `plushie` itself match the SDK-pinned version.
Pass `--lax-tools` to bypass the check; this is intended for local
experimentation and not for release builds.

## Distribution

Artifacts are version-named and signed with SHA-256 sidecars in the
same layout the SDK uses to fetch its own managed tools:

```
BASE/vVERSION/ARTIFACT
BASE/vVERSION/ARTIFACT.sha256
```

GitHub releases match this layout naturally. Other hosting works the
same way: any HTTPS endpoint that serves `vVERSION/ARTIFACT` and
`vVERSION/ARTIFACT.sha256` is usable.

For local release verification, point `PLUSHIE_RELEASE_BASE_URL` at a
`file://` directory or a loopback HTTP server before assets are
uploaded. The download flow accepts both schemes alongside the
default HTTPS.

## Continuous integration

The following GitHub Actions workflow builds a portable artifact per
target on a `v*` tag push and uploads everything to a GitHub release
with SHA-256 sidecars. Drop it in at `.github/workflows/release.yml`
and edit the marked lines for your app:

```yaml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write          # for uploading release assets

jobs:
  package:
    name: Package (${{ matrix.target }})
    runs-on: ${{ matrix.runner }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - target: linux-x86_64
            runner: ubuntu-latest
          - target: darwin-x86_64
            runner: macos-13
          - target: darwin-aarch64
            runner: macos-14
          - target: windows-x86_64
            runner: windows-latest
    steps:
      - uses: actions/checkout@v4

      - uses: erlef/setup-beam@v1
        with:
          otp-version: "27"
          gleam-version: "1.5"
          rebar3-version: "3"

      - name: Cache build
        uses: actions/cache@v4
        with:
          path: |
            build
          key: gleam-${{ matrix.target }}-${{ hashFiles('manifest.toml') }}

      - name: Fetch dependencies
        run: gleam deps download

      - name: Install Plushie tools
        run: gleam run -m plushie/download

      - name: Build the package payload
        # EDIT: replace dev.example.my_app and my_app@connect below
        run: |
          gleam run -m plushie/package -- \
            --app-id dev.example.my_app \
            --connect-module my_app@connect

      - name: Build the portable artifact
        run: bin/plushie package portable --manifest dist/plushie-package.toml

      - name: Compute SHA-256 sidecar
        shell: bash
        run: |
          cd target/plushie/package
          for f in *; do
            if [ -f "$f" ] && [[ "$f" != *.sha256 ]]; then
              shasum -a 256 "$f" | awk '{print $1}' > "$f.sha256"
            fi
          done

      - name: Upload to release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            target/plushie/package/*
          generate_release_notes: true
```

The workflow runs four parallel jobs, one per supported target. Each
fetches dependencies, installs the Plushie tool set, exports the
Erlang shipment, assembles the payload (bundling the runner's own
Erlang runtime), produces the portable artifact, computes a SHA-256
sidecar, and uploads both files to the release that the tag push
creates.

Lines to tweak for your project:

- The matrix runner labels (`macos-13` for Intel macOS, `macos-14`
  for Apple Silicon). GitHub-hosted runner labels change over time;
  pin or update as needed. Add `ubuntu-24.04-arm` (or use a
  self-hosted runner) for Linux aarch64.
- The OTP and Gleam versions in `setup-beam`. Match what your
  project supports.
- The `plushie/package` arguments: `--app-id` and `--connect-module`.
- Release notes: set `generate_release_notes` to `false` and add
  `body` (or `body_path`) if you write release notes by hand.

To also build OS-native installers, add a second matrix entry that
calls `bin/plushie package bundle --format <name>` (repeated per format) instead of
`package portable`, and adjust the upload glob accordingly. Apple
formats need a macOS runner with valid signing identities; Windows
formats need a Windows runner with the appropriate SDKs.

For private hosting, replace the upload step with whatever pushes the
artifact and sidecar to your release endpoint. Any service that
exposes the assets at `BASE/vVERSION/ARTIFACT` plus
`BASE/vVERSION/ARTIFACT.sha256` works with the download flow.

## Signing

`plushie-package.toml` carries a `[[signing.hooks]]` block: a list of
commands that run after the artifact is built. Pass
`--run-signing-hooks` to `package portable` or `package bundle` to
invoke them. Hooks are opt-in so release builds run them and local
experimentation does not.

Each hook is a structured argv. Use them for macOS notarization,
Windows code signing, Linux checksum attestation, or whatever else
the target platform needs. Plushie does not hold signing keys; the
hook commands do.

## Updates

`plushie-package.toml` reserves an `[updates]` block for update
channel metadata. The schema is in place. The runtime side that
consumes it, planned around
[cargo-packager-updater](https://github.com/crabnebula-dev/cargo-packager),
is not yet shipped.

## Host-first versus renderer-parent

Packaging is host-first. The launcher starts the Gleam app and the
app starts its own renderer.

A separate renderer-parent flow exists for development and embedding
hosts. The renderer starts first, binds a Unix socket, and spawns the
host command with `PLUSHIE_SOCKET` pointing at it:

```bash
plushie-renderer --listen \
  --exec-bin gleam \
  --exec-arg run \
  --exec-arg -m \
  --exec-arg my_app/connect
```

`--listen`, `--exec-bin`, and `--exec-arg` are flags on the renderer
binary itself (`plushie-renderer`), not on the `plushie` orchestration
tool.

`plushie/connect.run` reads the socket and connects. The same module
is what `bin/start_host` invokes in a packaged app, so driving a
packaged app from an external renderer is possible but requires
adding `PLUSHIE_SOCKET` to `[start].forward_env` so the launcher
passes the variable through. This is not a default-on configuration.

## See also

- [CLI Commands reference](cli-commands.md) - the full
  `plushie/package`, `plushie/download`, `plushie/build`, and
  `plushie/connect` surface
- [Configuration reference](configuration.md) - environment variables,
  `gleam.toml` keys, and transport modes
- [Versioning reference](versioning.md) - the relationship between
  the SDK version, `plushie_rust_version`, and the renderer binary
- [Wire Protocol reference](wire-protocol.md) - message format, token
  handling, and renderer-parent startup
- [Erlang Interop reference](erlang-interop.md) - how Gleam modules
  map to Erlang module names (the `--connect-module` form)
