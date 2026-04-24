# Wire Protocol

The wire protocol defines the message format between the Gleam
SDK and the Rust renderer. It is language-agnostic and shared
across all Plushie SDKs. This page covers the Gleam perspective:
how the SDK encodes, decodes, frames, and manages the protocol
lifecycle.

For the complete message format specification (every field,
every patch operation, every event family), see the
[Renderer Protocol Spec](https://github.com/plushie-ui/plushie-rust/blob/main/docs/protocol.md).
It is the source of truth; this page does not duplicate it.

## Wire formats

Two codecs carry the same message structures. The choice is
declared on `StartOpts.format` or `ConnectOpts.format` and
defaults to `Msgpack`:

```gleam
import plushie
import plushie/protocol

plushie.StartOpts(..plushie.default_start_opts(), format: protocol.Json)
```

`protocol.Format` is a sum type with `Json` and `Msgpack`
variants. It lives in `plushie/protocol`.

### MessagePack (default)

Each message is prefixed with a 4-byte big-endian unsigned
integer declaring the payload size:

```
<<size:32-big, payload:bytes-size(size)>>
```

The bridge opens the Erlang Port with `{packet, 4}`, so the BEAM
handles framing automatically in both directions. For custom
transports (iostream adapters, socket channels), use
`plushie/transport/framing.encode_packet/1` and
`decode_packets/1`, which produce and consume the same shape
natively in Gleam `BitArray`.

MessagePack is the efficient choice for binary payloads (image
bytes, pixel buffers, screenshots) and high-rate updates.

### JSONL

Each message is a single JSON object terminated by `\n`.
Messages must not contain embedded newlines.

The bridge opens the Port with `{line, 65536}`. For custom
transports, use `framing.encode_line/1` and `decode_lines/1`.
Binary data (images, screenshots) is base64-encoded
(`BitArray` values are encoded with `bit_array.base64_encode`
at the boundary; decoded values arrive as base64 strings until
the decoder routes them through a typed field).

JSONL is useful for debugging. Combine it with
`RUST_LOG=plushie=debug`:

```bash
RUST_LOG=plushie=debug gleam run -m plushie/gui --json 2>protocol.log
```

### Format auto-detection

The renderer auto-detects the codec from the first byte of
stdin: `0x7B` (`{`) means JSONL, anything else means
MessagePack. The renderer's `--json` and `--msgpack` flags
override the peek. The Gleam SDK does not auto-detect; it
always declares the codec explicitly when opening the
transport.

### Maximum message size

The per-message cap is 64 MiB (`framing.max_message_size`).
Both the renderer and the Gleam framing layer reject messages
that exceed the cap. On the Gleam side, oversized frames
surface as `FramingError.BufferOverflow(size, limit)` on both
the encode and decode paths.

## Protocol version

The current protocol version is `1`. It is carried in the
`settings` message under `protocol_version` and echoed in the
renderer's `hello` response under `protocol`. A mismatch means
an SDK / renderer version skew.

Read the pinned version programmatically with
`plushie/protocol.protocol_version`.

When the renderer's `hello` reports a `protocol` field that
differs from `protocol.protocol_version`, the runtime
constructs `event.ProtocolVersionMismatch(expected, got)` and
routes it through the normal event path as
`Error(ProtocolVersionMismatch(..))` before stopping. The app
observes the typed variant in `update` before the runtime
exits.

## Startup handshake

The SDK and renderer follow a fixed sequence:

1. The SDK sends `settings` first.
   `protocol.encode_settings/4` serializes the app's
   `Settings` record plus the pinned protocol version, an
   optional auth token, and any `required_widgets`. The
   bridge writes this as the first wire message.
2. The renderer peeks the first byte of stdin and locks in
   the codec.
3. The renderer validates `settings.protocol_version`.
4. The renderer sends `hello`. Fields: `protocol`, `version`,
   `name`, `mode` (`"windowed"`, `"headless"`, `"mock"`),
   `backend`, `transport`, `native_widgets`, `widgets`. The
   decoded form is `decode.Hello { protocol, version, name,
   mode, backend, transport, native_widgets, widgets }`.
5. The SDK sends a `snapshot`. The runtime calls `view`,
   normalizes the tree via `plushie/tree.normalize`, and
   writes the full tree via `protocol.encode_snapshot/3`.
6. Normal exchange begins.

If the renderer crashes and the bridge restarts it (see
[Bridge restart](#bridge-restart) below), the handshake
repeats from step 1.

## Encoding (SDK to renderer)

`plushie/protocol/encode` exposes one function per outbound
message type. Each function returns `Result(BitArray,
EncodeError)` so serialization failures are inspectable.

| Function | Message `type` | When sent |
|---|---|---|
| `encode_settings` | `settings` | Startup, renderer restart |
| `encode_snapshot` | `snapshot` | First render, renderer restart |
| `encode_patch` | `patch` | Incremental tree updates |
| `encode_effect` | `effect` | Platform effect requests |
| `encode_subscribe` | `subscribe` | Subscription activation |
| `encode_unsubscribe` | `unsubscribe` | Subscription removal |
| `encode_command` | `command` | Widget-targeted command |
| `encode_commands` | `commands` | Batch of widget-targeted commands |
| `encode_widget_op` | `widget_op` | Global widget op (`focus_next`, `announce`, ...) |
| `encode_window_op` | `window_op` | Window open, close, configure |
| `encode_system_op` | `system_op` | System-wide operation |
| `encode_system_query` | `system_query` | System-wide query |
| `encode_image_op` | `image_op` | In-memory image lifecycle |
| `encode_advance_frame` | `advance_frame` | Manual frame step (test, headless) |
| `encode_register_effect_stub` | `register_effect_stub` | Register a stubbed effect response |
| `encode_unregister_effect_stub` | `unregister_effect_stub` | Remove a registered stub |
| `encode_interact` | `interact` | Test interaction (click, type, ...) |

Every outbound message carries a `type` field identifying the
message kind and a `session` field (see
[Session multiplexing](#session-multiplexing)).

### Encoding boundary

Widget builders encode typed Gleam values (`Length`, `Color`,
`Padding`, `Border`, ...) to `PropValue` primitives inside
each widget module's `build/1`. By the time a `Node` reaches
the tree, its props are already wire-compatible. Tree
normalization handles scoped IDs and a11y reference
resolution only; `protocol/encode` serializes the `PropValue`
tree to wire bytes and does not perform type-to-primitive
conversion.

The `node_to_prop_value/1` helper maps the `kind` field on
`Node` to the wire field `"type"` and drops the runtime-only
`Meta` field, which carries widget state and definitions that
the renderer does not understand.

### PropValue

`plushie/node.PropValue` is the common primitive type used for
every wire value:

```gleam
pub type PropValue {
  StringVal(String)
  IntVal(Int)
  FloatVal(Float)
  BoolVal(Bool)
  NullVal
  BinaryVal(BitArray)
  ListVal(List(PropValue))
  DictVal(Dict(String, PropValue))
  OpaqueVal(Dynamic)
}
```

`OpaqueVal` is runtime-only and is always dropped at the wire
boundary (`NullVal` under JSONL, `Nil` under MessagePack).
`BinaryVal` maps to native bytes under MessagePack and to a
base64 string under JSONL. Non-finite floats (`NaN`,
`Infinity`) are serialized as null.

## Decoding (renderer to SDK)

`plushie/protocol/decode.decode_message/2` takes raw wire bytes
and the chosen `Format`, and returns
`Result(InboundMessage, DecodeError)`. The decoder is
codec-symmetric: MessagePack bytes go through `glepack`, JSONL
bytes through `gleam/json`, and both converge on an internal
`PropValue` tree before dispatch.

`InboundMessage` is the typed outcome:

| Variant | Wire `type` | Delivered via |
|---|---|---|
| `Hello` | `hello` | Bridge stores, forwards to runtime |
| `EventMessage(Event)` | `event`, `diagnostic`, `op_query_response` | `update/2` |
| `EffectResponseRaw` | `effect_response` | Runtime maps wire id to tag, typed-decodes the payload, delivers `Effect(EffectEvent)` |
| `EffectStubAck` | `effect_stub_register_ack`, `effect_stub_unregister_ack` | Resolves pending stub registration |
| `InteractStep` | `interact_step` | Test backend processes intermediate events |
| `InteractResponse` | `interact_response` | Test backend resolves the pending interaction |

`session_error` and `session_closed` also route through
`EventMessage`, producing `Event.Session(SessionError(..))`
and `Event.Session(SessionClosed(..))` respectively.

### Event dispatch

The `event` wire message carries a `family` field
(`"click"`, `"input"`, `"key"`, `"resize"`, ...). The decoder
dispatches on `family` and constructs the typed `Event`
variant. See [Events reference](events.md) for the full event
taxonomy.

Unknown message types fail the decode with
`DecodeError.UnknownMessageType(String)`; unknown event
families fail with `DecodeError.UnknownEventFamily(String)`.

### Diagnostics

Diagnostic messages (`type: "diagnostic"`) carry an inner
`kind` and are decoded into a typed `event.Diagnostic`
variant wrapped in `Error(Diagnostic(..))`. Unknown diagnostic
kinds fail the decode with `DecodeError`; this is intentional
so version skew is loud rather than silent. Diagnostic
variants mirror the renderer's `plushie-core::Diagnostic`
enum.

## Snapshots vs patches

The runtime chooses between a snapshot and a patch:

- **Snapshot**: sent when there is no previous tree to diff
  against (startup, renderer restart). Resets all
  renderer-side caches.
- **Patch**: sent when the tree changes incrementally.
  `plushie/tree.diff` compares the old and new normalized
  trees and produces a list of `patch.PatchOp` values. If
  the diff is empty, no message is sent.

### Patch ops

`patch.PatchOp` variants map to wire op strings:

| Variant | Wire `op` | Fields |
|---|---|---|
| `ReplaceNode` | `replace_node` | `path`, `node` |
| `UpdateProps` | `update_props` | `path`, `props` |
| `InsertChild` | `insert_child` | `path`, `index`, `node` |
| `RemoveChild` | `remove_child` | `path`, `index` |

`path` is a `List(Int)` of child indices from the root, encoded
on the wire as a JSON or MessagePack integer array.
`UpdateProps` uses an explicit `NullVal` value to signal prop
removal; the renderer clears the prop on its retained node.

See the
[Renderer Protocol Spec](https://github.com/plushie-ui/plushie-rust/blob/main/docs/protocol.md)
for the authoritative op ordering rules.

## Session multiplexing

Every wire message carries a `session` field (string). In
single-session mode (the default), this is the empty string.
In multiplexed mode (`--max-sessions N` on the renderer), each
concurrent session is isolated by its session ID.

Session lifecycle:

- Sessions are created implicitly on first message with a
  previously-unseen session ID.
- Reset is a message of `type: "reset"` carrying the session
  id; the renderer replies with `reset_response` and tears
  down the session.
- `session_error` surfaces faults as
  `Event.Session(SessionError(session, code, error))`.
  `session_closed` surfaces cleanup as
  `Event.Session(SessionClosed(session, reason))`.

The Gleam SDK sends a single empty session ID by default. The
test session pool (`plushie/testing/session_pool`) is the
current multiplexed-mode caller: it runs a shared renderer
with `--mock --max-sessions N` and registers new sessions
per test, sending `reset` on unregister and waiting for
`reset_response` before reusing the ID.

## The interact protocol

Test interactions (`click`, `type_text`, etc.) use a
synchronous request / response protocol:

1. The SDK sends an `interact` message with an action,
   selector, and payload.
2. The renderer resolves the selector, simulates the
   interaction, and replies with zero or more `interact_step`
   messages carrying intermediate events.
3. The renderer sends a final `interact_response` carrying
   the last batch of events.
4. The test backend feeds every event through `update` and
   returns control to the test process.

The runtime pins the pending request ID and matches it
against `InteractResponse.id` so a stale response from a
previous interaction cannot resolve the current call.

See [Testing reference](testing.md) for the test facade
built on top of this protocol.

## Transport modes

Transport is selected via `StartOpts.transport`. The type
lives in `plushie.gleam`:

```gleam
pub type Transport {
  Spawn
  Stdio
  Iostream(adapter: Subject(bridge.IoStreamMessage))
}
```

- `Spawn` (default): the SDK process spawns the renderer
  binary as a child process, communicating over
  child-process stdin and stdout via an Erlang Port.
- `Stdio`: the SDK process reads and writes its own stdin
  and stdout. Used when the renderer spawns the SDK process
  (for example, `plushie-renderer --exec`).
- `Iostream`: the SDK sends and receives wire bytes through
  a user-supplied adapter process. Used for custom
  transports (TCP sockets, SSH channels, WebSockets).

### iostream adapter contract

The adapter is a Gleam process that accepts
`bridge.IoStreamMessage` and delivers data back to the bridge
as `bridge.BridgeMessage`:

| Direction | Message | Meaning |
|---|---|---|
| Bridge to adapter | `IoStreamBridge(bridge)` | Registration; the adapter stores the bridge subject |
| Bridge to adapter | `IoStreamSend(data)` | Wire bytes to send over the transport |
| Adapter to bridge | `IoStreamData(data)` | Wire bytes received from the transport |
| Adapter to bridge | `IoStreamClosed` | Transport closed |

The adapter owns framing. For byte-stream transports (TCP,
SSH), use `plushie/transport/framing` on both the encode and
decode sides to honor the 64 MiB cap. The built-in
`plushie/socket_adapter` is an example iostream adapter over
`gen_tcp` and Unix domain sockets, driven by
`plushie/connect`.

## Bridge restart

When the Rust binary exits with a non-zero status under the
`Spawn` transport, the bridge restarts it with exponential
backoff (100ms base, 5s cap, 5 consecutive failures
allowed). On a successful restart: settings are re-sent, the
view is re-rendered as a fresh snapshot, subscriptions and
windows are re-synced, stale coalescable events are
discarded, and pending effects fail with
`renderer_restarted`. The app's model is preserved across
restarts.

A clean exit (status 0) stops the runtime without a
restart.

Transient messages sent while the port is down (effects,
widget ops, image ops, widget commands, `interact`,
`advance_frame`, stub registration) are queued in the bridge
and flushed after the runtime signals resync is complete.
Rebuildable messages (settings, snapshots, patches,
subscriptions, window ops) are dropped during the outage
because the runtime rebuilds them on resync.

## See also

- [Events reference](events.md)
- [Commands reference](commands.md)
- [Subscriptions reference](subscriptions.md)
- [Configuration reference](configuration.md)
- [Renderer Protocol Spec](https://github.com/plushie-ui/plushie-rust/blob/main/docs/protocol.md)
