# Running plushie

Plushie's **renderer** draws windows and handles input. Your Gleam
code (the **host**) manages state and builds the UI tree. They talk
over a wire protocol -- locally through a pipe, remotely over SSH,
or through any transport you provide. This guide covers all the ways
to connect them.

## Local desktop

The simplest setup: the host spawns the renderer as a child process.

<!-- test: running_gui_default_opts_test -- keep this code block in sync with the test -->
```gleam
// src/my_app/main.gleam
import plushie/gui

pub fn main() {
  gui.run(my_app.app(), gui.default_opts())
}
```

Then run:

```sh
gleam run -m my_app/main
```

The renderer is resolved automatically. For most projects,
`gleam run -m plushie/download` fetches a precompiled renderer and you're done.
If you have native Rust extensions, `gleam run -m plushie/build` compiles a
custom renderer. You can also set `PLUSHIE_BINARY_PATH` explicitly.

### Dev mode

Set `dev: True` in `GuiOpts` to enable live reload. Edit code, save,
see the result instantly. The model state is preserved across reloads.

<!-- test: running_gui_opts_with_dev_mode_test -- keep this code block in sync with the test -->
```gleam
import plushie/gui

pub fn main() {
  let opts = gui.GuiOpts(..gui.default_opts(), dev: True)
  gui.run(my_app.app(), opts)
}
```

### Exec mode

The renderer can spawn the host instead of the other way around. This
is useful when plushie is the entry point (a release binary or launcher)
and it's the foundation for remote rendering over SSH.

```sh
plushie --exec "gleam run -m my_app/stdio_main"
```

Where `stdio_main` uses stdio transport:

```gleam
// src/my_app/stdio_main.gleam
import plushie/stdio

pub fn main() {
  stdio.run(my_app.app(), stdio.default_opts())
}
```

The renderer controls the lifecycle. When the user closes the window,
the renderer closes stdin, and the plushie process exits cleanly.

### Connect mode

Instead of the renderer spawning the host (exec/stdio), the host can
connect to an already-running renderer via Unix socket or TCP. The
renderer starts with `plushie --listen` and either spawns the host
(setting `PLUSHIE_SOCKET` and `PLUSHIE_TOKEN` in the environment) or
prints connection info for manual use.

```gleam
// src/my_app/connect_main.gleam
import plushie/connect

pub fn main() {
  connect.run(my_app.app(), connect.default_opts())
}
```

Socket address resolution:

1. `--socket` CLI flag
2. `PLUSHIE_SOCKET` environment variable
3. Error

Token resolution:

1. `--token` CLI flag
2. `PLUSHIE_TOKEN` environment variable
3. JSON line from stdin (1 second timeout)
4. No token (renderer decides)

Address format: paths starting with `/` are Unix sockets, `:4567` is
TCP localhost, `host:4567` is TCP on a specific host.

## Remote rendering

Your host runs on a server. You want to see its UI on your laptop.
The renderer runs locally (where your display is), the host runs
remotely (where the data is), and SSH connects them:

```
[your laptop]                    [server]
renderer        <--- SSH --->    host
  draws windows                    init/update/view
  handles input                    business logic
```

Your `init`/`update`/`view` code doesn't change at all.

### Prerequisites

- **Your laptop**: the `plushie` renderer installed and on your PATH.
  Download from the GitHub releases page, or build with
  `cargo install plushie` if you have a Rust toolchain.
- **The server**: your Gleam project deployed with its dependencies.
  The server does NOT need the renderer or a display server.
- **SSH access**: you can `ssh user@server` from your laptop.

### Quick start

```sh
plushie --exec "ssh user@server 'cd /app && gleam run -m my_app/stdio_main'"
```

The renderer on your laptop spawns an SSH session, which starts the
host on the server. The wire protocol flows through the SSH tunnel.
Each connection starts a fresh BEAM on the server, so there's a 1-2
second startup overhead.

### In-BEAM Erlang SSH

If your server already runs a BEAM (a web service, a data
pipeline, an embedded device), you can skip that startup entirely.
OTP includes a built-in SSH server. Start it in your supervisor, and
the renderer connects directly to the running VM. No new process, no
compilation, instant startup.

This gives you access to everything in the running VM: ETS tables,
processes, your database pool. It's the path to building
dashboards for live server state, admin tools backed by real data,
and diagnostic UIs for embedded devices.

Setting this up requires familiarity with OTP's `:ssh` application.
The [custom transports](#example-erlang-ssh-channel-adapter) section
has a full SSH channel adapter example with commentary.

### Binary distribution

The renderer always runs on the **display machine** (your laptop,
not the server). How you get it there depends on your project:

| Your project uses | Renderer needed | How to get it |
|---|---|---|
| Built-in widgets only | Precompiled | `gleam run -m plushie/download` or GitHub release |
| Pure Gleam extensions | Precompiled | Same -- composites don't need a custom build |
| Native Rust extensions | Custom build | `gleam run -m plushie/build` targeting your laptop's architecture |

The server doesn't need the renderer at all. It only needs your
Gleam project and its dependencies.

## Resiliency

Things go wrong. Renderers crash, code has bugs, networks drop.
Plushie handles these without losing your model state.

### Renderer crashes

If the renderer crashes (segfault, GPU error, out of memory), the
host detects it and restarts automatically with exponential backoff.
Your model state is preserved -- the new renderer receives fresh
settings, a full snapshot of the current UI, and re-synced
subscriptions and windows. The user sees a brief flicker, then the
UI is back.

The host retries up to 5 times (100ms, 200ms, 400ms, 800ms, 1.6s).
If all retries fail, it logs troubleshooting steps and the plushie
process stops. The rest of your application is unaffected -- only
the plushie process exits. A successful connection resets the
retry counter, so intermittent crashes get a fresh budget each time.

### Exceptions in your code

If `update` or `view` raises, the runtime catches it, logs the
error with a full stacktrace, and keeps the previous model state.
The window stays open and continues responding to events. You don't
need try/rescue in your callbacks.

After 100 consecutive errors, log output is suppressed to prevent
flooding, with periodic reminders every 1000 errors. Telemetry
events continue firing for monitoring.

### Network drops

When an SSH connection drops, both sides detect the broken pipe:

- **The renderer** sees the host's stdout close. It can display an
  error or retry the connection.
- **The host** sees stdin close. Without daemon mode, the plushie
  process exits (the rest of your service is unaffected). With
  daemon mode, plushie keeps running with the model preserved.

When a new renderer connects (another SSH session), the host sends a
snapshot of the current state. No restart, no state loss, no cold
start.

<!-- test: running_start_opts_stdio_daemon_test -- keep this code block in sync with the test -->
```gleam
import plushie
import plushie/app

let start_opts =
  plushie.StartOpts(
    ..plushie.default_start_opts(),
    transport: plushie.Stdio,
    daemon: True,
  )
let _ = plushie.start(my_app.app(), start_opts)
```

### Window close

When the user closes the last window, your `update` receives the
event. You can save state, persist data, or show a confirmation
dialog. In non-daemon mode, the plushie process exits. In daemon mode,
plushie keeps running and waits for a new renderer to connect.

## Event rate limiting

Over a network, continuous events like mouse moves, scroll, and
slider drags can overwhelm the connection. A standard mouse generates
60+ events per second; a gaming mouse can hit 1000. Rate limiting
tells the renderer to buffer these and deliver at a controlled
frequency. Discrete events like clicks and key presses are never
rate-limited.

Rate limiting is useful locally too -- a dashboard doesn't need 1000
mouse move updates per second even on a fast machine.

### Global default

Set `default_event_rate` in your app's `settings` callback:

<!-- test: running_settings_default_event_rate_test -- keep this code block in sync with the test -->
```gleam
fn settings() -> app.Settings {
  app.Settings(..app.default_settings(), default_event_rate: Some(60))
  // 60 events/sec -- good for most cases
}
```

For a monitoring dashboard:

<!-- test: running_settings_low_event_rate_test -- keep this code block in sync with the test -->
```gleam
fn settings() -> app.Settings {
  app.Settings(..app.default_settings(), default_event_rate: Some(15))
}
```

### Per-subscription

Override the global rate for specific event sources:

<!-- test: running_subscription_mouse_move_with_rate_test -- keep this code block in sync with the test -->
```gleam
import plushie/subscription

fn subscribe(_model: Model) -> List(subscription.Subscription(Event)) {
  [
    subscription.on_mouse_move("mouse", MaxRate(30)),
    subscription.on_animation_frame("frame", MaxRate(60)),
    subscription.on_mouse_move("capture", MaxRate(0)),  // capture only, no events
  ]
}
```

### Per-widget

Override the rate on individual widgets:

```gleam
ui.slider("volume", #(0.0, 100.0), model.volume, [ui.event_rate(15)])
ui.slider("seek", #(0.0, float.to_float(model.duration)), model.position, [ui.event_rate(60)])
```

### Latency and animations

| Transport | Localhost | LAN | WAN |
|---|---|---|---|
| Port (local) | < 1ms | -- | -- |
| SSH | -- | 1-5ms | 20-150ms |

On a LAN, animations are smooth and interactions feel instant. Over a
WAN (50ms+), user interactions have a visible round-trip delay. Design
for this by keeping UI responsive to local input (hover effects, focus
states) and accepting that model updates lag by the round-trip time.

## Custom transports

For advanced use cases, the iostream transport lets you bridge any
I/O mechanism to plushie. Write an adapter process that speaks a simple
four-message protocol, and plushie handles the rest. Most projects
don't need this -- the built-in local and SSH transports cover the
common cases.

### The protocol

| Direction | Message | Purpose |
|---|---|---|
| Bridge -> Adapter | `{:iostream_bridge, bridge_pid}` | Init handshake. Adapter stores the pid. |
| Adapter -> Bridge | `{:iostream_data, binary}` | One complete protocol message. |
| Bridge -> Adapter | `{:iostream_send, iodata}` | Protocol message to send. |
| Adapter -> Bridge | `{:iostream_closed, reason}` | Transport closed. Bridge shuts down. |

The Bridge monitors the adapter process. If it exits, the Bridge
shuts down and notifies the runtime.

### Example: TCP adapter

A minimal adapter for TCP sockets. This is Erlang-level code since
custom transports interact directly with OTP primitives:

```erlang
-module(my_tcp_adapter).
-behaviour(gen_server).

-export([start_link/1, init/1, handle_info/2, handle_cast/2]).

start_link(Socket) ->
    gen_server:start_link(?MODULE, Socket, []).

init(Socket) ->
    inet:setopts(Socket, [{active, true}]),
    {ok, #{socket => Socket, bridge => undefined, buffer => <<>>}}.

%% Bridge registered itself on init
handle_info({iostream_bridge, BridgePid}, State) ->
    {noreply, State#{bridge := BridgePid}};

%% Bridge wants to send data to the renderer
handle_info({iostream_send, IoData}, #{socket := Socket} = State) ->
    gen_tcp:send(Socket, plushie_framing:encode_packet(IoData)),
    {noreply, State};

%% TCP data arrived -- decode frames and forward complete messages
handle_info({tcp, _Socket, Data}, #{bridge := Bridge, buffer := Buf} = State) ->
    {Messages, NewBuf} = plushie_framing:decode_packets(<<Buf/binary, Data/binary>>),
    [Bridge ! {iostream_data, Msg} || Msg <- Messages],
    {noreply, State#{buffer := NewBuf}};

%% TCP closed -- tell the Bridge
handle_info({tcp_closed, _Socket}, #{bridge := Bridge} = State) ->
    case Bridge of
        undefined -> ok;
        Pid -> Pid ! {iostream_closed, tcp_closed}
    end,
    {stop, normal, State}.
```

### Example: Erlang SSH channel adapter

This adapter uses OTP's built-in `:ssh` server to accept renderer
connections directly into a running BEAM. It requires familiarity with
the `:ssh_server_channel` behaviour.

First, start an SSH daemon in your supervisor:

```erlang
ssh:daemon(2022, [
    {system_dir, "/etc/plushie_ssh"},
    {user_dir, "~/.ssh"},
    {subsystems, [{"plushie", {my_ssh_channel, []}}]}
]).
```

Then implement the channel handler. The key callbacks:

- `handle_msg({:ssh_channel_up, ...})` fires when the SSH channel
  opens. This is where you start the host with iostream transport.
- `handle_ssh_msg({:ssh_cm, _, {:data, ...}})` fires when bytes
  arrive from the renderer. Decode frames and forward to the Bridge.
- `handle_msg({:iostream_send, ...})` fires when the Bridge has
  data for the renderer. Encode and write to the SSH channel.
- `handle_msg({:iostream_bridge, pid})` fires during startup.
  Store the Bridge pid for forwarding.

```erlang
-module(my_ssh_channel).
-behaviour(ssh_server_channel).

-export([init/1, handle_ssh_msg/2, handle_msg/2]).

init(_Args) ->
    {ok, #{bridge => undefined, conn => undefined, channel => undefined, buffer => <<>>}}.

%% Renderer data arrived over SSH -- decode and forward to Bridge
handle_ssh_msg({ssh_cm, _Conn, {data, _Channel, 0, Data}},
               #{bridge := Bridge, buffer := Buf} = State) ->
    {Messages, NewBuf} = plushie_framing:decode_packets(<<Buf/binary, Data/binary>>),
    [Bridge ! {iostream_data, Msg} || Msg <- Messages],
    {ok, State#{buffer := NewBuf}};

%% Bridge registered itself during plushie.start
handle_msg({iostream_bridge, BridgePid}, State) ->
    {ok, State#{bridge := BridgePid}};

%% Bridge wants to send data to the renderer
handle_msg({iostream_send, IoData}, #{conn := Conn, channel := Ch} = State) ->
    Framed = plushie_framing:encode_packet(IoData),
    ssh_connection:send(Conn, Ch, Framed),
    {ok, State};

%% SSH channel is ready -- start the host
handle_msg({ssh_channel_up, Channel, Conn}, State) ->
    {ok, _Pid} = plushie:start(my_app:app(), #{
        transport => {iostream, self()},
        format => msgpack
    }),
    {ok, State#{conn := Conn, channel := Channel}}.
```

### Framing

Raw byte streams (SSH channels, raw sockets) need message boundaries.
The plushie framing module handles this. Transports with built-in
framing (Erlang Ports, `gen_tcp` with `{packet, 4}`) don't need it.

```
MessagePack: 4-byte big-endian length prefix
JSON: newline-delimited
```

## Testing

See [Testing](testing.md) for the full guide. Quick summary:

```sh
gleam test                                         # compile + run tests
./bin/preflight                                     # format check, compile, test
PLUSHIE_TEST_BACKEND=headless gleam test             # real rendering, no display
PLUSHIE_TEST_BACKEND=windowed gleam test             # real windows (needs display)
```

## How props reach the renderer

You don't need to understand this to use plushie. It's here for when
you're debugging wire format issues or writing extensions.

When you return a tree from `view`, it passes through four stages
before reaching the wire:

1. **Widget builders** (`plushie/ui` functions, `plushie/widget/*` modules)
   return `Node` values with typed Gleam values -- custom types, strings,
   floats.

2. **Widget build** (`build()` functions) convert typed builder state
   to `Node` records with `PropValue` dictionaries. Values are already
   encoded to wire-compatible primitives at this stage.

3. **Tree normalization** (`plushie/tree.normalize`) walks the tree and
   resolves scoped IDs, a11y cross-references (`labelled_by`,
   `described_by`, `error_message`), and applies ID prefixing.

4. **Protocol encoding** serializes the PropValue tree to MessagePack
   or JSON.

Each stage has one job. Widget builders don't worry about wire format.
The PropValue encoding doesn't know about serialization. And the protocol
layer doesn't know about widget types.

If you call `build()` on a widget directly (e.g., in tests), you get
the stage-2 output -- string keys, `PropValue` values. After `normalize`,
scoped IDs are resolved. After protocol encoding, the tree is bytes on
the wire. This matters when writing assertions: `build()` output has
`StringVal("fill")`, the wire has `"fill"`.

## Next steps

- [Getting started](getting-started.md) -- setup, first app
- [Commands and subscriptions](commands.md) -- event rate limiting details
- [Testing](testing.md) -- test framework
- [Extensions](extensions.md) -- custom widgets, CoalesceHint for throttling
- [Collab demo](https://github.com/plushie-ui/plushie-demos/tree/main/gleam/collab) -- the same app running in 6 transport modes (native, stdio, WASM, WebSocket, SSH)
