# Versioning

Plushie has three version numbers that evolve independently: the
Gleam SDK, the plushie-rust release it targets, and the wire
protocol spoken between the SDK and the renderer.

## SDK version

The Gleam package's own semver, declared as `version` in
`gleam.toml` and published to
[Hex](https://hex.pm/packages/plushie_gleam). Bumps cover
Gleam-side changes: bug fixes, new widget builders, type
improvements, docs, test helpers, and so on.

Pre-1.0, breaking changes may land in any minor bump (`0.X.0`).
Patch releases (`0.X.Y`) stay backwards-compatible within the SDK.
The [CHANGELOG](../../CHANGELOG.md) lists every release's changes
with breaking items called out first.

## `plushie_rust_version`

The root-level `plushie_rust_version` key in `gleam.toml` (read via
`plushie/config.plushie_rust_version()`) pins the exact
[plushie-rust](https://github.com/plushie-ui/plushie-rust) release
this SDK targets. Every plushie-rust artefact the SDK touches comes
from that release:

- The `plushie-renderer` binary downloaded by
  `gleam run -m plushie/download`.
- The `cargo-plushie` tool invoked by
  `gleam run -m plushie/build`. The build fails if the tool on
  `PATH` does not match this version exactly, and prints a
  `cargo install cargo-plushie --version X.Y.Z --locked` command.
- The version string embedded in the virtual app crate generated
  under `_build/plushie-renderer-spec/Cargo.toml`.

Bumping this key is how the SDK opts in to a newer renderer. The
version axes move independently:

- SDK-only fixes bump the SDK version only; `plushie_rust_version`
  stays put.
- plushie-rust upgrades bump `plushie_rust_version` (and usually
  the SDK version too, to cut a release that ships the upgrade).

`plushie_rust_version` must match a plushie-rust release exactly:
no semver ranges, no `~> 0.6` fuzzy pins. Exact match is the only
way to guarantee the renderer binary, the generated dependencies,
and the wire protocol travel together.

## Wire protocol version

`plushie/protocol.protocol_version` is a constant integer embedded
in the `settings` message the runtime sends to the renderer on
startup. The renderer compares it against its own constant. On
mismatch the renderer replies with an error and the runtime
surfaces a structured `Error(ProtocolVersionMismatch(expected,
got))` event through the normal event path, logs the mismatch,
then stops. A mismatched protocol is not safe to continue on; see
the [Events reference](events.md) for the `ErrorEvent` shape.

Mismatches are a symptom, not the root cause. They indicate the
SDK and the renderer binary came from different plushie-rust
releases. Realigning `plushie_rust_version` with the installed
renderer, or re-running `gleam run -m plushie/download`, restores
compatibility.

## Upgrade guidance

To take a newer plushie-rust release:

1. Edit the root `plushie_rust_version` key in `gleam.toml`.
2. Run `gleam run -m plushie/download` to fetch the matching
   `plushie-renderer` binary, or `gleam run -m plushie/build` to
   rebuild from source. The build tool expects `cargo-plushie` on
   `PATH` at the same version; install it with the
   `cargo install cargo-plushie --version X.Y.Z --locked` command
   the build prints on mismatch.
3. Rebuild the app (`gleam build`).

The CHANGELOG for each SDK release calls out whether it bumps
`plushie_rust_version` and what plushie-rust changes come with it.

See
[plushie-rust's versioning policy](https://github.com/plushie-ui/plushie-rust/blob/main/docs/versioning.md)
for the canonical rules covering the full Rust workspace, the wire
protocol version, and cross-SDK compatibility.

## See also

- [Configuration reference](configuration.md) - the full
  `gleam.toml` `[plushie]` section and root-level keys
- [Events reference](events.md) - the
  `Error(ProtocolVersionMismatch)` event shape
- [Wire Protocol reference](wire-protocol.md) - message framing
  and the `settings` handshake that carries `protocol_version`
