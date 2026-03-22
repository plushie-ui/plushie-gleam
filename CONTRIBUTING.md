# Contributing to plushie-gleam

## Development setup

You need:

- **Gleam** (>= 1.0) -- install via your package manager or
  [gleam.run](https://gleam.run/getting-started/installing/)
- **Erlang/OTP** (>= 26) -- Gleam compiles to BEAM bytecode
- **Rust toolchain** (optional) -- only needed if building the
  plushie renderer from source or working on native extensions

### Getting the renderer

For built-in widgets only (no Rust extensions):

```sh
gleam run -m plushie/download
```

This fetches a precompiled renderer binary for your platform.

To build from source (required for native extensions):

```sh
gleam run -m plushie/build
```

### Building and testing

```sh
gleam build          # compile
gleam test           # compile + run tests
gleam format         # auto-format all .gleam files
./bin/preflight       # run all CI checks locally (format, compile, test)
```

Always run `./bin/preflight` before pushing. It mirrors what CI does.

## Code style

- `gleam format` is the single source of truth for formatting.
  Run it before every commit.
- `snake_case` for everything: modules, functions, variables,
  constants.
- Pipeline operator (`|>`) for data transformations.
- Qualified imports for clarity -- prefer `dict.insert(...)` over
  importing `insert` bare.
- Custom types for enums, not strings. If a value has a fixed set
  of options, model it as a type.
- Let the code speak. Only comment when intent isn't obvious from
  the types and names.

## Commit conventions

Commit messages should describe what changed and why.

Do not include:

- Counts of any kind -- if the content is listed, the reader can
  count
- Ticket, review, or tracking IDs

Keep messages concise. One to two sentences is typical. Use the
imperative mood ("Add feature" not "Added feature").

## Pull requests

- One logical change per PR.
- Include tests for new behaviour. Tests are documentation -- they
  should tell a story to the next person who reads them.
- Keep PRs small and focused. If you find unrelated issues while
  working, note them for a separate PR rather than bundling.
- Ensure `./bin/preflight` passes before opening.

## Architecture

Key invariants to be aware of:

- **Subject ownership**: all Subjects must be created inside the
  runtime's spawned process.
- **Patch paths are List(Int)**: child index arrays, not string IDs.
- **Encoding happens at build() time**: widget builders encode typed
  values to PropValue. Don't defer encoding to normalize or protocol
  encode.
- **Window detection depth**: only root and direct children are
  checked for window nodes.

## Testing philosophy

- Prefer real implementations over mocks -- tests that pass while
  reality is broken prove nothing.
- Write a failing test before fixing a bug when possible.
- Tests should read like specifications of behaviour.
- If tests are slow, the code is probably slow too.

## Getting help

Open an issue for bugs, questions, or feature discussions.
