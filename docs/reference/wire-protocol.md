# Wire Protocol

The wire protocol defines the message format between the Gleam SDK and
the Rust renderer. The protocol is language-agnostic and shared across
all Plushie SDKs.

For the complete message format specification, see the
[Renderer Protocol Spec](https://github.com/plushie-ui/plushie-renderer/blob/main/docs/protocol.md).

## Wire formats

Two formats carry the same message structures. Controlled by the `Format`
option on `plushie.start`.

### MessagePack (default)

Each message is prefixed with a 4-byte big-endian unsigned integer
indicating the payload size:

```
<<size:32-big, payload:bytes(size)>>
```

The Bridge opens the Erlang Port with `{packet, 4}`, handling framing
automatically. For custom transports, use
`plushie/transport/framing.encode_packet` and `decode_packets`.

### JSON (JSONL)

Each message is a single JSON object terminated by `\n`. For custom
transports, use `plushie/transport/framing.encode_line` and
`decode_lines`.

JSON is human-readable, useful for debugging. Combine with
`RUST_LOG=plushie=debug`.

### Maximum message size

64 MiB. Messages exceeding this are rejected by the renderer.

## Protocol version

The current protocol version is `1`. Sent in the `settings` message and
returned in the renderer's `hello` response.

Read the version programmatically: `plushie/protocol.protocol_version`.

## Startup handshake

1. SDK sends Settings (protocol version + app settings)
2. Renderer auto-detects format, reads Settings
3. Renderer sends Hello (version, mode, extensions)
4. SDK sends Snapshot (full tree)
5. Normal exchange begins

## Outbound messages (SDK -> renderer)

| Type | Purpose |
|---|---|
| `settings` | Startup config (nested under `"settings"` key) |
| `snapshot` | Full tree |
| `patch` | Incremental update (ops with `List(Int)` paths) |
| `widget_op` | Focus, scroll, select, cursor, announce |
| `window_op` | Window open, close, update |
| `subscribe` / `unsubscribe` | Event source management |
| `effect` | Platform request (file dialog, clipboard) |
| `image_op` | Image create/update/delete |
| `extension_command` | Native widget action |
| `advance_frame` | Test/headless tick |

## Inbound messages (renderer -> SDK)

| Type | Purpose |
|---|---|
| `hello` | Handshake (protocol version check) |
| `event` | User interaction (dispatched by family) |
| `effect_response` | Platform result |
| `interact_response` | Test interaction result |

## Snapshots vs patches

The Runtime decides whether to send a snapshot (no previous tree) or
a patch (incremental changes via `plushie/tree.diff`). Empty diffs
produce no wire traffic.

## Session multiplexing

Every message carries a `session` field. Single-session mode uses `""`.
The test session pool uses unique session IDs for isolation.

## iostream adapters

Custom transports use `Iostream(pid)` and implement a message protocol
for bidirectional communication. See the
[Configuration reference](configuration.md).

## See also

- `plushie/protocol` - encode/decode
- `plushie/transport/framing` - frame encode/decode
- `plushie/bridge` - transport management
- [Configuration](configuration.md)
