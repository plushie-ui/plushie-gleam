# Test discipline

How tests are written, what they cost, and what they commit to.
The discipline below shows up in plushie-gleam's own test suite
and in parallel form across every host SDK. It is one of the
project's load-bearing conventions.

## The integration spine

Tests exercise the real renderer. On the BEAM target, the
default test backend (`mock`) runs `plushie-renderer --mock`:
real binary, real wire protocol, real codec, real Core engine.
The only thing the default backend strips is the GPU rendering
step. Tests dispatch events, read model and tree state, and
assert on observable behavior through the same API user apps
use.

A test that passes against a pure-Gleam substitute and would
fail against the binary is worse than no test. It gives
confidence on the exact class of bugs the integration is meant
to catch: wire format drift between encoder and renderer,
startup handshake ordering, codec edge cases, lifecycle on
bridge restart, the small protocol-level details that pure-
Gleam mocks have no mechanism to diverge on.

This is not about coverage as a metric. It is about catching
the bugs that matter where they actually live, which is at
boundaries.

## Three test modes (BEAM)

The renderer offers three runtime modes; the test backends
follow them by name. The naming is a cross-SDK contract.

- **mock**: microseconds to milliseconds per test. Protocol-
  only. Real binary, real wire, real Core, no rendering. The
  default for most tests; fast enough that a full suite runs
  through the binary without flinching. `gleam test` uses this.
- **headless**: tens to low hundreds of milliseconds per test.
  Real rendering via tiny-skia, no display server. Used when
  the test cares about pixels: screenshot golden files, tree-
  hash assertions, layout-affecting bugs.
  `PLUSHIE_TEST_BACKEND=headless gleam test`.
- **windowed**: seconds per test. Full iced rendering with a
  real display (headless weston on Linux, native display
  elsewhere; Xvfb works for X11-only environments). Used when
  the test cares about full window lifecycle, focus events, or
  platform-specific behavior.

The names mean the same thing in plushie-rust, plushie-elixir,
plushie-typescript, plushie-python, plushie-ruby. Findings
about naming or behavior drift between the three modes route
through the parity workflow.

## JS target

On JavaScript, the renderer compiles to WASM (or runs remotely
over the wire). The default test backend runs the app's
`init/update/view` cycle in-memory through the pure session
runner. No renderer process, no wire bytes; widget interactions
construct events directly against the same runtime-core logic
the real runtime uses.

This is target shape, not a corner-cut for speed. The pure
session backend exists because the JS target's "real renderer"
is a WASM module, not a subprocess; the in-memory runner
exercises the same `runtime_core` logic the WASM-driven path
exercises. Tests written against the unified `testing` API
work on both targets unchanged.

## Pooled mock backend (BEAM)

`plushie/testing/session_pool` starts a single
`plushie-renderer --mock --max-sessions N` process and
multiplexes tests over it. Each test gets isolated state via
session IDs in every wire message. This keeps mock-mode startup
amortized across the suite rather than paid per test. Windowed
mode does not pool: each test gets its own renderer.

eunit runs tests within a module in the same process; the pool
sends a `reset` to clear the previous test's renderer state
before reusing the session, so widget state does not leak
between tests.

## Synchronous test API

Tests synchronize with the runtime through production APIs:

- `plushie.get_model(instance)` returns the typed model
  directly. `Instance(model)` is parameterized so the model
  type flows through without `Dynamic` coercion at call sites.
- `plushie.get_tree(instance)` returns the current normalized
  tree.
- `plushie.dispatch_event(instance, event)` injects an event
  into the runtime, bypassing the renderer; integration tests
  use this for direct event triggering.
- `support.await(rt, predicate, timeout_ms)` blocks until the
  predicate matches or the timeout fires; the owner process
  monitors the test process and self-terminates on test
  failure to prevent resource leaks.

## When stubs are acceptable

A pure-Gleam stub that does not go through the renderer is
acceptable only for failure modes the binary cannot exhibit
cleanly:

- **Effect stubs** (registered with the renderer via
  `register_effect_stub`) provide controlled responses for
  effects the test environment cannot handle (file dialogs,
  clipboard). Stubs operate at the renderer level, not by
  bypassing the wire protocol.
- Forced renderer crash simulation. The binary cannot be told
  "panic now" via the protocol.
- Malformed wire bytes the codec rejects before any typed
  delivery path runs.
- Test infrastructure that wraps the integration primitives
  themselves.

If a test can run against the binary, it does. The bar for
adding a non-binary stub is "what failure mode does this
expose that nothing else can," answered concretely.

## Tests as documentation

Tests should read as a story for the next person who opens the
file. A clear setup, an explicit action, an assertion that
names what is being verified. Behavior-driven shape: the test
framework is incidental; what is being verified should be
obvious from the test name and the body.

The corollary: tests are not allowed to be slow. If a test is
slow, the underlying code path is usually slow in production
too. Speed up the code; do not accept the slow test. mock-mode
exists to skip the GPU step, not to hide a slow code path
behind a faster harness.

## Failing test before fix

For a bug fix, write the failing test first when possible. A
test added alongside the fix that would have passed without
the fix proves nothing about the bug. The failing test is the
definition of done.

Exceptions: refactors with no behavior change (the existing
suite is the regression net), and new features where the test
and the implementation arrive together.

## Capturing logs

Test apps must return `window` nodes from `view`. A bare
column or row triggers diagnostics that leak to stdout.

Tests that intentionally trigger errors (crash recovery, view
failures, renderer restarts) capture the relevant diagnostics
through the test API rather than letting them log to stdout.
Preflight output must be clean. Any `[error]` or `[warning]`
log lines in test output are bugs. They indicate log output
leaking from tests that should be capturing it.

## Implications

- A feature has to be testable through the renderer (or, on
  JS, through the pure session runner). If a feature cannot be
  exercised through the integration spine, that is a design
  problem with the feature, not a problem with the test
  discipline.
- "Let's mock the renderer for speed on BEAM" proposals are
  declined. Speed comes from mock-mode in the real binary,
  which is already fast; the cost of a pure-Gleam mock is the
  bug class it hides.
- Coverage as a percentage is a non-goal (see
  `goals-and-non-goals.md`). Coverage of real surfaces is what
  matters; the integration spine is what produces it.
- Tests that rely on internal process structure or peek at
  supervisor children are brittle and get rewritten to use the
  public test framework.
