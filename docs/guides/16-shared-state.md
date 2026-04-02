# Shared State

Plushie apps communicate with the renderer over a byte stream. By default
that stream is stdio to a local process, but it can be any transport,
including an SSH channel. This enables collaborative, multi-session apps.

## Architecture

```
 ssh client 1 --SSH--+
                     +-- Shared OTP actor -- app.update
 ssh client 2 --SSH--+        |
                         broadcasts
                         model to all
```

Each client gets an SSH channel adapter that speaks the Plushie wire
protocol. Events from any client go through `update`, and the new model
is broadcast to everyone.

## The iostream transport

Plushie supports `Iostream(pid)` as a transport mode. The `pid` is a
process that bridges between the wire protocol and an arbitrary transport
(SSH channel, TCP socket, Unix socket). The adapter process handles these
messages:

| Direction | Message | Description |
|---|---|---|
| Bridge -> Adapter | `iostream_bridge` | Adapter stores the bridge pid |
| Bridge -> Adapter | `iostream_send` | Protocol data to write |
| Adapter -> Bridge | `iostream_data` | Complete protocol message received |
| Adapter -> Bridge | `iostream_closed` | Transport closed |

The adapter is responsible for framing. `plushie/transport/framing`
provides frame encode/decode for length-prefixed byte streams.

## Socket adapter

`plushie/socket_adapter` provides a gen_tcp-based iostream bridge actor
for socket-based transports. The `plushie/connect` module provides the
entry point for socket-based connections.

## Starting a shared app

```gleam
import plushie
import plushie/app

// Create the shared state actor
let assert Ok(shared) = start_shared_server(my_app)

// For each connecting client:
let assert Ok(adapter) = socket_adapter.start(client_socket)
let assert Ok(_) = plushie.start(my_app, [
  plushie.Transport(plushie.Iostream(adapter)),
])
```

The wire protocol is identical regardless of transport. Your Gleam code
runs on the server; the renderer runs wherever there is a screen.

---

You now have a comprehensive overview of Plushie's capabilities. The
[reference docs](../reference/built-in-widgets.md) cover each topic
in depth when you need it.
