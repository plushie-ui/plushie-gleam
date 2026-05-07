# DSL discipline

Gleam has no macros. The "DSL" in plushie-gleam is a layered
set of library functions over typed builders: each widget has
an opaque builder (`button.new(id, label) |> button.width(Fill)
|> button.build()`) and an `Opt`-list shorthand exposed through
`plushie/ui` (`ui.button("id", "label", [button.Width(Fill)])`).
There is no codegen, no compile-time hook beyond what the
compiler already gives every Gleam library.

This doc describes the posture for adding to the builder
surface, deciding what the type system enforces vs what is
runtime-checked, and keeping public APIs honest.

## What the DSL is for

A user composing a UI imports either the per-widget module
(for the chained-builder style) or `plushie/ui` (for the
`Opt`-list style). The shape is:

- **Per-widget builders** (`plushie/widget/*`): opaque types
  with `new(id, ...)`, chainable setters, and `build()`. The
  setters take typed values; invalid combinations are
  rejected at the type system, not at runtime.
- **`plushie/ui` shorthand**: convenience functions that take
  a `List(Opt)` of typed options specific to that widget,
  giving the same compile-time validation through a different
  syntactic shape.
- **Property types in `plushie/prop/*`**: `Length`, `Color`,
  `Padding`, `Border`, `Theme`, etc. Each is a custom type or
  parameterized record; values are constructed through named
  functions (`length.fill()`, `padding.all(16.0)`,
  `color.rgb(...)`) and encoded to wire form by
  `widget/*.build()`.
- **Per-target stability**: the same builder API works on both
  BEAM and JS. A new builder cannot land on one target only.

The DSL is not a backdoor for arbitrary code generation. There
is no codegen; what a user writes is exactly the function
calls they invoke.

## When a new builder option earns its place

The DSL is permissive about adding widgets (each widget is its
own module; new widgets are not a stewardship-level question).
It is conservative about adding new options to existing
widgets, new helpers in `plushie/ui`, new property types, and
new builder patterns.

A new builder option earns its place when:

- The corresponding renderer-side prop or behavior already
  exists (or is landing in lockstep) and the wire shape is
  defined in `plushie-rust/docs/protocol.md`.
- At least two existing or imminent users want it.
- The form replaces a runtime construct that is harder to read
  or harder to validate at the call site.
- A meaningful class of bugs becomes detectable at compile
  time that runtime checks would catch only on first render.
- The generated `gleam docs` output reads as cleanly as the
  surrounding API. Doc comments explain intent, not mechanism.

A new builder option does not earn its place when:

- The argument is "we could express this as a custom type."
  Type-level structure has costs (compilation seconds, harder
  error attribution when types compose, more shapes for
  readers to learn); the bug class has to be real and
  recurring.
- The argument is "this would let users write less code." If
  the existing form already reads cleanly, fewer characters is
  not the bar.
- The argument is "this would be more idiomatic in Gleam."
  See `posture.md`. Cross-SDK shape is the constraint; Gleam
  idiom is downstream of that.

A new builder option is rejected when:

- It hides indirection that a reader of the call site would
  not expect.
- The compile error it produces points at the SDK rather than
  the user's source line.
- The shape diverges from the equivalent option on the same
  widget in plushie-elixir or plushie-rust.

## Type system vs runtime checks

Type-level enforcement is welcome when it catches a real bug
class with clear compiler errors:

- Widget option types resolve at compile time. An
  `Image(content_fit.ContentFit)` option cannot be passed a
  `Length`; the compiler refuses.
- Opaque builder types prevent constructing an invalid widget
  state from outside the module. `Button` is opaque; the only
  way to get one is `button.new` plus the setters.
- Custom-type unions enclose closed sets (event variants,
  command shapes, theme presets); adding a value outside the
  set requires a compile-touching change in the SDK.
- Parameterized types (`Command(msg)`, `App(model, msg)`,
  `Instance(model)`) carry the user's types through to
  consumer call sites without `Dynamic` coercion.

Type-level enforcement is not welcome when:

- The check requires understanding values only available at
  runtime (event content, model shape, dynamic IDs).
- The type would force every user to thread a phantom
  parameter through their code for a constraint two users
  care about.
- The same bug class is catchable cleanly at runtime with a
  clearer error message.

Runtime validation that the SDK relies on:

- `tree.normalize` validates window-node positioning and
  scoped-ID uniqueness; diagnostics surface as
  `event.Diagnostic` variants.
- `protocol/decode` validates incoming wire messages against
  the closed event-variant set; unknown variants surface as
  `UnknownMessageType` rather than passing through opaque.
- `transport/framing` rejects oversized frames with
  `BufferOverflow`.
- `widget/build` (and per-widget `build`) enforces the
  encoding-at-build-time invariant: prop values reach the tree
  already encoded; deferred encoding is forbidden.

## Generated docs are what users read

`gleam docs build` is the public surface. Doc comments are
the API:

- Public functions and types have `///` doc comments. The
  comments describe what the function does, what its
  arguments mean, and any non-obvious constraints. They do
  not describe implementation.
- Internal modules and functions are not exported; if
  something is not exported, it is internal regardless of
  whether it has a doc comment.
- Module-level `////` comments describe the module's purpose
  and the user's entry points.
- Examples in doc comments are kept compilable where
  practical; doc tests are not yet a thing in Gleam, but
  examples that drift become a discoverable bug.

A module change that breaks `gleam docs build` is a real
regression. A doc comment that describes how the function
works internally rather than what the user gets is a doc bug;
rewrite to user-facing.

## No general-purpose coercion

Two specific rules earn explicit mention because the codebase
forbids them (see also `simplicity.md`):

- **No `coerce(value: a) -> b` or `unsafe_coerce`**. These
  bypass the type system entirely. When type information must
  cross a boundary (process messages, FFI, Dynamic payloads),
  use a narrow function with a specific signature that names
  the boundary: `event_to_msg`, `from_dynamic`,
  `model_to_dynamic`, etc. Each is private, has a small
  number of call sites, and the name explains why it exists.
- **No internal `Dynamic`.** `Dynamic` lives at wire-edge
  decode, async result payloads, and `app_opts`. Internal
  modules pass typed values. A new internal call site that
  takes `Dynamic` is a design problem; the type upstream
  wants to be parameterized.

## Errors point at the call site

A compiler error from a builder that points at the SDK's
implementation rather than the user's call site is broken
(within the limits of what the Gleam compiler emits). The
user wants to know which line of their code is wrong, not
which line of the SDK is doing the checking.

A useful error message for a runtime diagnostic:

- Names what is wrong in the user's terms (the field name,
  the widget name, the container name).
- Names what was expected (the supported types, the supported
  containers, the required form).
- Carries enough context (window ID, scoped ID, type name)
  for the user to find the call site.

Vague diagnostics from the runtime are bug-class. They cost
users time and they cost us issue triage.

## What this looks like in practice

- A user proposes "add a `Disabled(Bool)` option to button."
  Real bug class? Tracking enabled state through user model
  is fine; renderer-side disabled is a meaningful UX feature.
  Two users? Yes. Cross-SDK parity? Already exists in elixir,
  rust, typescript. Outcome: do.
- A user proposes "add a phantom `state: Built` parameter to
  the builder so `build()` can only be called once." Type-
  level safety? Marginal. Real bug class? Builders are local;
  re-calling `build()` is a rare bug. Cost? Every user threads
  the phantom. Outcome: decline; the cost outweighs the win.
- A user proposes "let `ui.text` accept either a String or a
  list of styled spans." Real cross-SDK shape? Rich text is
  its own widget (`rich_text`), not an overload of `text`.
  Outcome: decline; route to `rich_text` instead.
- A user proposes "auto-derive `cast` from a schema for new
  prop types." No codegen. Outcome: not applicable; Gleam
  does not have macros, and adding a derive macro to the SDK
  is a much larger question than this doc covers.
