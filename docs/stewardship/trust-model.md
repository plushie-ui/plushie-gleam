# Trust model

What plushie-gleam's role is in the wider Plushie trust model,
what it implements on its own side, and where the broader picture
lives. The authoritative trust-model doc lives in plushie-rust
(`docs/stewardship/trust-model.md`); this doc describes the host
SDK's half.

## The asymmetric model

Plushie's wire boundary is asymmetric:

- **Renderer-to-host.** Closed and typed. The renderer can only
  push the fixed enumeration of event variants and structured
  responses defined by the wire protocol. There is no opaque-blob
  path, no string-eval, no generic "run this on the host"
  instruction. The host is therefore structurally protected from
  a compromised or malicious renderer. The remote-rendering use
  case relies on this.
- **Host-to-renderer.** Broader by design. The host asks the
  renderer to load fonts and images by path, render screenshots,
  exercise effects (clipboard, file dialogs, notifications),
  spawn subprocesses in `--exec` mode. A compromised host can
  drive the full operation set against the user's machine
  wherever the renderer runs. Bounding this is the
  capability-manifest direction in plushie-rust's roadmap, not
  current work.

plushie-gleam is on the trusted side of this boundary. The
runtime, the bridge, the widget builders, and user code all run
as the host. Concerns that frame the host as adversary are out
of scope under the current model.

## What plushie-gleam implements on its side

Renderer-to-host integrity depends on the host SDK actually
holding up the closed-shape contract on the receiving end.
plushie-gleam's load-bearing pieces:

- **Typed event decoding.** `plushie/protocol/decode` parses
  incoming messages against the fixed event variant set. Unknown
  variants surface as `UnknownMessageType` diagnostics; they are
  not silently forwarded to user code as opaque maps. An unsafe
  decoder shape that passed arbitrary structures through to
  `update` would undermine the host-protection claim.
- **Effect and query response correlation.** Effect commands
  carry a request ID and a timeout. Responses are routed back to
  the originating tag only after the request ID matches an
  outstanding request. Stale or unknown IDs are dropped. A
  spoofable correlation (delivering by tag without checking the
  ID) would let a malicious renderer drive the wrong handler.
- **No host-side eval surface.** The runtime never evaluates
  data sourced from the renderer as code. Strict event variants
  parse through closed unions in `event.gleam`; unknown
  diagnostic codes surface as their stable string code, not as
  an executable hook. The codec uses typed Gleam custom types
  end-to-end on the SDK side; there is no `apply`-shaped path
  from wire content to a host function.
- **No general-purpose coercion.** The codebase forbids
  `coerce` / `unsafe_coerce` shapes (see `posture.md`). Each
  boundary that crosses Dynamic to typed has a narrow,
  named function with a specific signature, so a renderer-
  controlled value never lands in an `a -> b` cast.
- **App-level hygiene is the app's choice.** An app that wires
  user-provided event content into shell-out commands or
  filesystem paths is making its own choice. The protocol
  cannot enforce app-side hygiene.

## What is not protected today

- **DoS and resource exhaustion.** A malicious renderer can flood
  typed events at the protocol rate. The runtime has frame-level
  coalescing for high-frequency event types and configurable
  `default_event_rate`; a host SDK still has to handle the
  firehose gracefully (see `resilience.md`).
- **Host-to-renderer surface.** Effect dispatch, file path
  inputs, and `--exec` spawn are full-trust today. Bounding them
  is the capability-manifest direction in plushie-rust.
- **Same-access channels.** A user with shell access on the
  machine running the host can read its memory and files
  directly. plushie-gleam does not protect against the user
  acting on themselves.
- **JS target sandbox.** The JS runtime runs inside whatever
  page or worker hosts it. Plushie does not add additional
  isolation beyond what the host environment provides.

## Channel posture

The wire protocol is byte-stream agnostic. Confidentiality and
integrity are delegated to the outer transport (OS pipe, named
pipe, SSH, mTLS, WebSocket+TLS). The wire is not its own crypto
layer, by design. Proposals to add per-message MACs or encrypted
fields to the wire format are misframed; that responsibility
belongs with the outer transport.

The session token at the wire boundary binds a host to a
particular renderer instance. It is not a confidentiality
mechanism.

## Implications

- Work that loosens renderer-to-host integrity (an unsafe
  decoder shape, an opaque-blob delivery path, spoofable
  response correlation, a `coerce` shape, an eval-from-wire
  hook) is a deliberate decision, not a routine refactor;
  default to no.
- Memory-corruption or RCE-shaped findings on either side are in
  scope today regardless of the broader capability-manifest
  direction.
- Host-to-renderer concerns (file path inputs, effect dispatch,
  spawn surface) defer to the capability-manifest roadmap in
  plushie-rust.
- Wire-level confidentiality or integrity expectations belong
  with the outer transport.
- DoS and resource-exhaustion concerns are low priority;
  configurable knobs (`default_event_rate`, per-subscription
  `max_rate`) are preferred over aggressive defaults.
