# Simplicity

The bar code in plushie-gleam has to clear, and the recurring
tradeoffs about structure and abstraction that decide what
earns its place. The other stewardship docs
(`performance-bar.md`, `resilience.md`, `test-discipline.md`,
`dsl-discipline.md`) each carry a flavor of this implicitly;
this doc states it directly so questions about "should we
extract this" or "is this clear enough" have an explicit
reference.

This is not a style guide. Naming, formatting, and language-
specific idioms live in `gleam format` and the project's
conventions. This doc is about the posture above those: when
to add complexity, when to refuse it, what clarity costs, and
what readability buys.

## Clarity is a constraint, not an aspiration

Code in plushie-gleam has to read clearly to a Gleam engineer
who has not been in this codebase before. "It compiles" is the
floor; "it can be understood without context" is the bar.

Every reader pays the cost of obscure code. The author writes
it once; many readers will read it. Small clarity wins compound
across hundreds of files; small obscurity losses compound the
other way. Same compounding argument that drives the
lightweight-by-default stance in `performance-bar.md`, applied
to reader cost instead of CPU cost.

The bar is not negotiable. Optimizations, abstractions,
defensive layers, refactors, and builder additions all have to
clear it; the readability test wins ties.

## Abstraction has to earn its place

Extracting a helper, a module, a parameterized type, a custom
type, a builder pattern: each carries cost. A reader has to
follow the indirection, hold the abstraction's contract in
their head, and decide whether what the call site shows
reflects what the abstraction does inside. The benefit has to
clearly outweigh that cost.

Working rules:

- **Three similar lines is better than a premature
  abstraction.** Two pieces of code that look similar today
  might diverge tomorrow; extracting them now locks them
  together for reasons that may not survive contact with
  future requirements.
- **By the third use of a similar pattern, the abstraction
  earns consideration.** Not commitment, consideration. The
  question is whether the three uses are the same concept or
  three coincidentally similar ones.
- **An abstraction with one user is a costume, not an
  abstraction.** Single-use indirection is overhead. A
  parameterized type with one concrete instantiation, a
  helper with one call site, a behaviour-shaped record with
  one implementation.
- **"We might need this someday" is a reason not to extract.**
  Generic code written for hypothetical future users is the
  recurring source of half-built abstractions that nobody
  fully understands later. The widget builder layer is
  especially vulnerable here; see `dsl-discipline.md`.
- **Generic where specific would do is harder to read.** A
  concrete custom type beats a parameterized one when the
  parameterization does not have at least two real uses.
  `Command(msg)` is parameterized because every app
  parameterizes it; `Instance(model)` is parameterized because
  the model type flows through. A new generic with one use
  site is overhead.

These are working positions, not absolute rules. The burden is
on the proposed abstraction to push against them.

## Local complexity over global complexity

A 200-line function that does one thing clearly is preferable
to the same logic spread across five files in pursuit of
"smaller functions." Locality is a feature: a reader can hold
the whole thing in view. Following control flow across ten
indirections costs more than reading a longer linear sequence.

Module size on its own is not a problem. A large module is not
an invitation to split unless a real change is forced to bend
around its existing shape. Refactoring without a forcing
function is a non-goal (`goals-and-non-goals.md`); this is one
of the places that rule shows up most often. The runtime is
large because the runtime does a lot; that is fine.

Files split for the sake of "smaller files" frequently end up
with cross-file dependencies that obscure the same logic the
single file made obvious. Cohesion across a file beats brevity
of any one file.

## Functional flavor

The codebase is functional by design; Gleam is too. The Elm-
architecture pattern (`init/update/view`) is the SDK's
structural backbone for a reason. The recurring choices that
follow:

- **Pure functions where possible.** Side effects push to the
  edges (Bridge owns I/O on BEAM; the runtime executes
  commands; the rest is functional). `update` is pure: it
  returns a new model and commands; the runtime performs the
  commands.
- **Immutable data.** Gleam is immutable by default; the
  codebase keeps it that way. Mutability lives in clearly
  marked places (the FFI-backed JS handle state; the BEAM
  process state behind an actor) and not as ergonomics for
  "just mutate this."
- **Pattern matching over branching.** `case` on custom-type
  variants beats nested `if` chains where the shapes are
  stable. Multiple function signatures via guards beat a
  single function with branching when the shapes are stable.
- **Sum types over flag-based state machines.** A union of
  named variants (`Widget(WidgetEvent)`, `Key(KeyEvent)`,
  `Window(WindowEvent)`, etc.) beats a generic event record
  with three booleans and an unwritten rule about which
  combinations are valid. Variants make invalid shapes
  unconstructable.
- **Errors as values.** `Result(t, e)` for recoverable
  conditions; `panic`/`todo` only for genuinely unreachable
  states. The runtime never raises across the Elm loop on
  BEAM; on JS, callbacks that throw enter through a guarded
  dispatch path that converts to typed events.
- **Pipelines where they read top-down.** A pipe that flows
  through builder transformations is clearer than nested
  calls; a pipe that requires the reader to mentally re-thread
  arguments is not. The threshold is the reader, not the line
  count. Builder pipelines (`button.new(id, label) |>
  button.width(Fill) |> button.build()`) are the canonical
  good shape.
- **Composition over inheritance-shaped patterns.** Custom
  types and parameterized records compose; there is no
  inheritance to compose against. Records-of-functions
  (`TestBackend`) are used where dynamic dispatch over a
  closed set of implementations is genuinely needed; they are
  not a default.

Gleam idiom prevails on syntax (snake_case, qualified
imports, custom types for enums, pipelines, opaque types for
invariants). The concept-level patterns above converge with
the rest of the project ecosystem (see `posture.md` on the
cross-SDK story).

## Use the type system, do not bypass it

Two specific rules earn explicit mention because the codebase
forbids them:

- **No `coerce(value: a) -> b` or `unsafe_coerce`.** These
  bypass the type system entirely and make bugs invisible.
  When type information must cross a boundary (process
  messages, FFI, Dynamic payloads), use a narrow function
  with a specific signature that names the boundary. Examples
  in the codebase: `event_to_msg`, `from_dynamic`,
  `model_to_dynamic`. Each is private, has a small number of
  call sites, and the name explains why it exists.
- **No internal `Dynamic`.** `Dynamic` lives at wire-edge
  decode (`protocol/decode`), async result payloads, and the
  `app_opts` parameter. Internal modules pass typed values.
  A new internal call site that takes `Dynamic` is a design
  problem; the type upstream wants to be parameterized.

## Comments earn their place too

Code should explain itself. Comments answer questions the code
cannot:

- A non-obvious constraint or invariant the surrounding code
  holds.
- A surprising or subtle behavior a reader might trip on.
- A workaround for a specific external issue that the reader
  needs to understand to evaluate the code.

Comments are not for explaining what the next line does. If a
comment is needed to explain what, the code itself usually
wants to be clearer.

`///` doc comments are documentation, not comments; they have
a different purpose and a different bar. Public functions and
types have doc comments that read as user-facing
documentation.

## Implications

- Abstractions added without justifying use are declined,
  even when technically correct.
- Refactors that fragment a coherent module into smaller
  files without a forcing function are declined.
- Half-built abstractions (extracted but only partially
  applied, or extracted with planned consumers never
  arriving) are bug-class. Either complete the application
  or fold the abstraction back into the call sites.
- Reviewer comments of the form "I had to re-read this three
  times" are first-class and earn a rewrite, regardless of
  whether the code is correct as written.
