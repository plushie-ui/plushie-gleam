# Shared State

The pad is feature-complete. This chapter takes it one step
further: make the authoritative model live in a single process,
and let multiple renderers attach to it over the wire. One app,
many windows, real-time updates.

The SDK provides the pieces to wire this up: stdio transport, a
socket transport, and `plushie.dispatch_event` for injecting
broadcasts into a runtime. It does not provide a turn-key SSH
server or a "collaboration" module. Those are app-level concerns
that sit on top of the transports documented here.

## Goal

One authoritative process owns the model. Each connected renderer
gets its own `plushie` runtime talking to it. When any client
produces an event that mutates state, the authoritative process
re-broadcasts the new model to every attached runtime. Each
runtime calls `update` and `view`, diffs against its local tree,
and sends only the changed patches to its renderer.

```
 renderer 1 <---stdio---> runtime 1 (tree diff, patch)
                              \
                               \--- dispatch Broadcast --+
                                                         |
 renderer 2 <---stdio---> runtime 2 (tree diff, patch)   |
                              \                          |
                               \--- dispatch Broadcast --+
                                                         |
                                                    Shared actor
                                                    (authoritative
                                                     model)
```

Each runtime is a full Elm loop: its own subscriptions, event
coalescing, error isolation. The shared actor only holds the
model and broadcasts.

## Transport modes for remote renderers

Two SDK wrappers fit this pattern.

`plushie/stdio.run` reads and writes the wire protocol on the
BEAM's own stdin and stdout. The renderer is the parent. Use this
when the renderer spawns the Gleam process remotely, typically
over SSH:

```gleam
import plushie/stdio

pub fn main() {
  stdio.run(pad.app(), stdio.default_opts())
}
```

`plushie/connect.run` connects to an already-running renderer via
Unix socket or TCP. The renderer listens; the Gleam process is
the client. Useful when a relay in front of the renderer accepts
connections from multiple clients:

```gleam
import plushie/connect

pub fn main() {
  connect.run(pad.app(), connect.default_opts())
}
```

Both wrappers delegate to `plushie.start` with the right
`transport` value (`Stdio` or `Iostream(adapter)`). See the
[Configuration reference](../reference/configuration.md) for the
full option tables.

## Broadcast as a custom message

The model updates in the shared actor. Each runtime needs a way
to accept the new model without re-running app logic. Define a
message variant for the broadcast:

```gleam
import plushie/event.{type Event}

pub type Msg {
  Local(Event)
  Broadcast(Model)
}
```

Build the app with `app.application` so the runtime can map
renderer events to `Local(event)`:

```gleam
import plushie/app

pub fn app() {
  app.application(init, update, view, Local)
}
```

Handle the broadcast variant in `update` by replacing the local
model with the authoritative one:

```gleam
import plushie/command

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  case msg {
    Broadcast(new_model) -> #(new_model, command.none())
    Local(event) -> handle_event(model, event)
  }
}
```

`Broadcast` does not run the rest of the app's logic. It is a
pure state replacement.

## Dispatching broadcasts into a runtime

`plushie.dispatch_event(instance, event)` injects an event into
a running runtime's message loop, bypassing the renderer. The
runtime treats it like any other event: widget handlers,
`on_event` mapping, `update`, `view`, diff, patch.

To dispatch a `Broadcast`, wrap it in an `Event` variant the
runtime accepts. `event.Custom(tag, payload)` is the intended
escape hatch:

```gleam
import gleam/dynamic
import plushie
import plushie/event

pub fn broadcast(instance, model: Model) {
  plushie.dispatch_event(
    instance,
    event.Custom(tag: "broadcast", payload: dynamic.from(model)),
  )
}
```

The `on_event` mapper decodes the payload back to a `Msg`:

```gleam
fn on_event(ev: Event) -> Msg {
  case ev {
    event.Custom(tag: "broadcast", payload:) ->
      Broadcast(decode_model(payload))
    other -> Local(other)
  }
}
```

Every broadcast goes through the same `update` that user events
do, the tree diffs, and only the changed patches reach the
renderer. No manual snapshots.

## Shared actor

The authoritative process is a `gleam_otp` actor that holds the
model and a list of connected runtime instances. When any client
produces a user event, it goes to this actor first; the actor
runs `update`, stores the new model, and dispatches a `Broadcast`
to every attached runtime.

```gleam
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import plushie.{type Instance}

pub type Request {
  Attach(Subject(Nil), Instance(Model))
  Detach(Instance(Model))
  Apply(event.Event)
}

type State {
  State(model: Model, clients: List(Instance(Model)))
}

fn handle(state: State, req: Request) {
  case req {
    Attach(reply, instance) -> {
      broadcast_to(instance, state.model)
      process.send(reply, Nil)
      actor.continue(
        State(..state, clients: [instance, ..state.clients]),
      )
    }

    Detach(instance) -> {
      let clients = list.filter(state.clients, fn(i) { i != instance })
      actor.continue(State(..state, clients: clients))
    }

    Apply(event) -> {
      let new_model = apply_safely(state.model, event)
      list.each(state.clients, broadcast_to(_, new_model))
      actor.continue(State(..state, model: new_model))
    }
  }
}
```

`apply_safely` runs the same rules the app's `update` would,
minus the `Broadcast` case, inside `platform.try_call` so that
one client's bad event cannot crash the shared actor:

```gleam
import plushie/platform

fn apply_safely(model: Model, event: event.Event) -> Model {
  case platform.try_call(fn() { apply_event(model, event) }) {
    Ok(new_model) -> new_model
    Error(_) -> model
  }
}
```

Keeping `apply_event` in one place lets the shared actor and the
app's own update stay in sync: write the rules once, call them
from both sides.

## Attaching a runtime

Each connected renderer starts its own runtime, then asks the
shared actor to attach it. The initial model comes from the actor
so the client starts from authoritative state:

```gleam
import plushie

pub fn attach_client(shared, app) {
  let assert Ok(instance) =
    plushie.start(
      app,
      plushie.StartOpts(
        ..plushie.default_start_opts(),
        transport: plushie.Stdio,
      ),
    )

  let reply = process.new_subject()
  process.send(shared, Attach(reply, instance))
  let _ = process.receive(reply, 1000)

  instance
}
```

The `Attach` request seeds the runtime with the current model by
dispatching a broadcast before returning. From there, every state
change flows through the shared actor.

## Routing renderer events

For shared state we want the renderer event to hit the shared
actor first, so `update` runs in exactly one place. Route it in
the `on_event` mapper: forward state-changing events to the
shared actor and return a no-op locally. Cosmetic events (focus,
scroll) can still run locally without touching the shared model.

```gleam
fn on_event(shared: Subject(Request)) -> fn(Event) -> Msg {
  fn(ev) {
    case ev {
      event.Custom(tag: "broadcast", payload:) ->
        Broadcast(decode_model(payload))

      _ -> {
        process.send(shared, Apply(ev))
        Local(ev)
      }
    }
  }
}

pub fn app_for(shared: Subject(Request)) {
  app.application(init, update, view, on_event(shared))
}
```

Each client runs the same app definition; the closure is the only
per-client binding.

## Running over SSH

Gleam does not ship an SSH server helper. The practical setup is
to let the renderer spawn the app over SSH. The renderer already
supports this: `plushie-renderer --exec "..."` spawns a command
and treats its stdio as the wire protocol.

On the server, the user's login shell (or a `ForceCommand`
directive) runs the app in stdio mode:

```bash
exec plushie-gleam-pad stdio
```

From a client:

```bash
plushie --exec "ssh pad-server plushie-gleam-pad stdio"
```

The renderer runs locally, the Gleam process runs on the server,
and SSH carries the wire protocol in between. `stdio.run` picks
up the BEAM's stdin and stdout; SSH framed it for us.

For multi-client collaboration on a single shared model, a
dedicated host-side process listens for SSH sessions and hands
each one off to a runtime attached to the shared actor. Building
that plumbing (SSH daemon, channel-per-client, per-user
authentication) is regular BEAM work on top of the `ssh` Erlang
module, accessed through `@external` functions. The SDK pieces
(`stdio.run`, `plushie.start` with `Iostream`, `dispatch_event`)
do not change; only the transport host does.

## Collaborative mode for the pad

Evolve the pad into a minimal collaborative binary. A `--collab`
flag boots the shared actor and listens for clients on a local
socket. Each connection attaches a new runtime:

```gleam
import gleam/erlang/process
import plushie_pad/shared

pub fn main() {
  case argv() {
    ["--collab"] -> run_collab()
    _ -> plushie_pad.main()
  }
}

fn run_collab() {
  let assert Ok(shared_actor) = shared.start(shared.initial_model())
  listen_and_attach("/tmp/plushie-pad.sock", shared_actor)
  process.sleep_forever()
}
```

The details of `listen_and_attach` are app-level: accept a
socket, hand each connection to a `socket_adapter`, start
`plushie` with `Iostream(adapter)`, register the instance with
`shared_actor`. All the moving parts are public; none of them
require SDK changes.

Connect two renderers:

```bash
plushie --connect /tmp/plushie-pad.sock &
plushie --connect /tmp/plushie-pad.sock &
```

Edit in one, watch the other update. The wire protocol, the
renderer binary, and the `view` function are the same across
clients. Only the transport and the routing of events change.

## Per-client state

Some state belongs to a single client: a "dark mode" toggle, the
currently focused note, the scroll position. The broadcast above
replaces the whole model, which would clobber those fields.

Split the model into shared and local parts. The broadcast
carries only the shared part; `update` merges it into the local
model without touching local fields:

```gleam
pub type Model {
  Model(shared: SharedModel, local: LocalModel)
}

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  case msg {
    Broadcast(new_shared) ->
      #(Model(..model, shared: new_shared), command.none())
    Local(event) -> handle_event(model, event)
  }
}
```

An alternative is to tag each broadcast with the originator's
client ID so the originator can skip re-applying its own change.
The SDK does not enforce either pattern.

## Verifying it

The shared actor is a plain `gleam_otp` actor and tests without
any rendering. Use `plushie/testing/support` to start a runtime
against the mock backend, then drive events through the actor:

```gleam
import plushie/testing/support

pub fn broadcast_test() {
  let assert Ok(shared_actor) = shared.start(shared.initial_model())
  let rt = support.start(app_for(shared_actor), [])

  process.send(shared_actor, Apply(save_event))

  let assert Ok(_) =
    support.await(
      rt,
      fn(model) { model.shared.status == Saved },
      500,
    )

  support.stop(rt)
}
```

The runtime receives the broadcast, `update` swaps in the new
shared model, `view` runs, and the support harness asserts the
resulting state.

## Wrap-up

The guides end here. You have an app that can draw widgets,
handle input, run async work, animate, test itself, and share
state across connected renderers. The
[reference docs](../reference/built-in-widgets.md) cover each
area in the depth this walkthrough skipped: every widget opt,
every event shape, every command constructor, every subscription
key. When you need specifics, that is where to look next.
