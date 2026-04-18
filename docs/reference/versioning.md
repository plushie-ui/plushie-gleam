# Versioning

The Gleam SDK and the plushie-rust renderer are versioned
independently.

## Two axes

| Version | Lives in | Meaning |
|---|---|---|
| SDK version | `gleam.toml` `version = "..."` | This package's semver |
| `plushie_rust_version` | `gleam.toml` `plushie_rust_version = "..."` | plushie-rust release this SDK targets |

The SDK version moves on host-language changes (API tweaks, docs,
dialyzer fixes). `plushie_rust_version` moves only when the SDK opts
in to a new plushie-rust release (new renderer widgets, protocol
additions, renderer bug fixes).

## Compatibility rule

`plushie_rust_version` must exactly match the plushie-rust release
it targets. No semver ranges. The SDK pins the exact version used to:

- download the matching prebuilt `plushie-renderer` binary,
- install the matching `cargo-plushie` on the developer machine,
- render path-dep versions in the generated renderer workspace.

Mixing a different plushie-rust version is not supported.

## Canonical policy

See
[plushie-rust's versioning policy](https://github.com/plushie-ui/plushie-rust/blob/main/docs/versioning.md)
for the full rationale, including the "one workspace version across
every plushie-rust crate" rule and the wire-protocol-version story.
