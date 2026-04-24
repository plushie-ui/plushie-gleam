# Introduction

## What is Plushie?

Plushie is a native desktop GUI platform with SDKs for multiple languages.
This guide covers the Gleam SDK.

When you build an app with Plushie, you get real native windows, not
Electron, not a web view. Your application is a Gleam process running on
the BEAM that owns all the state. A separate Rust binary handles rendering,
input, and platform integration.

The renderer is built on [Iced](https://github.com/iced-rs/iced), a mature
cross-platform GUI toolkit for Rust. It provides GPU-accelerated rendering,
a software fallback for headless environments, and full accessibility support
including keyboard navigation and screen reader integration. You never
interact with Iced directly. Plushie handles the communication, and you can
write everything in Gleam.

## The Elm architecture

Plushie follows the Elm architecture, a pattern for building UIs around
one-way data flow. If you have used Elm, Redux, or LiveView, the shape will
feel familiar. It is the same model/update/view cycle, just running on the
desktop instead of the browser.

There are three pieces:

**Model** - your application state. It can be any Gleam type: a record, a
tuple, a single integer, a custom sum type. Plushie does not impose a
schema. Whatever your `init` callback returns becomes the initial model, and
the `App(model, msg)` value carries that type through the runtime.

**Update** - a function that receives the current model and a message, then
returns the next model paired with a `Command(msg)`. Messages come from user
interaction (a button click, a key press), from the system (a window
resized, a timer fired), or from your own async work. The update function is
where all state transitions happen.

**View** - a function that takes the current model and returns a `List(Node)`
of top-level windows describing what should be on screen. The runtime calls
`view` after every successful update. You never mutate the UI directly; you
return a description of what the screen should look like based on the
current state. A single-window app returns a one-element list. Returning an
empty list closes every window and shuts the app down cleanly.

The cycle looks like this:

    event -> update -> new model -> view -> UI tree -> render

This is the entire control flow. Events go in, state comes out, the view
reflects it. There is no two-way binding and no hidden mutation. When
something looks wrong on screen, you look at the model. When the model is
wrong, you look at the message that changed it. Every bug has a short
trail.

Plushie also supports [subscriptions](../reference/subscriptions.md),
declarative specs for ongoing event sources like timers, keyboard shortcuts,
and window events. Your app declares which subscriptions are active based on
the current model, and the runtime starts and stops them automatically.

One-off side effects (HTTP fetches, file dialogs, clipboard writes, window
operations) are expressed as [commands](../reference/commands.md) returned
from `update`. The runtime executes them and feeds results back as events.

This architecture makes your application predictable and testable. You can
test your entire UI through the real renderer binary (clicking buttons,
typing text, asserting on screen content) without mocking anything.

## How it works

Your Gleam application and the renderer run as two OS processes that
exchange messages over stdio by default, though other transports are
available for remote and embedded scenarios.

Your application builds UI trees using the typed widget builders in
`plushie/ui` and `plushie/widget/*`. The runtime, an OTP-supervised actor,
manages the model and runs the update/view cycle. When `view` produces a new
tree, the runtime diffs it against the previous one and sends only the
changes to the renderer over a wire protocol (MessagePack by default, with a
JSON option for debugging).

The renderer receives patches, updates its internal widget tree, and
renders frames. When the user interacts with the UI (clicking a button,
typing in an input, resizing a window), the renderer sends
[events](../reference/events.md) back over the same connection. The runtime
decodes them and feeds them into your `update` callback, and the cycle
continues.

The two-process split gives you resilience. If the renderer crashes, Plushie
restarts it with exponential backoff and re-syncs your application state.
Your model is never lost. If your update callback panics, the OTP supervisor
catches it, logs the error, and the runtime recovers to the previous state.
Neither process can take the other down.

Because the two processes communicate over a byte stream, they do not need
to run on the same machine. Your Gleam application can run on a server or
embedded device with no display and no GPU, just the BEAM. The renderer
runs wherever there is a screen. This is how you build desktop UIs for
headless infrastructure, remote sessions over SSH, or IoT devices.

## What you can build

Plushie is a general-purpose desktop toolkit:

- **Desktop tools and utilities**: file managers, text editors, system
  monitors, anything you would reach for a native toolkit for.
- **Dashboards and data visualization**: connect to your Gleam or Erlang
  backend directly, no API layer needed. The full
  [built-in widget catalog](../reference/built-in-widgets.md) covers tables,
  charts via canvas, progress bars, and input controls.
- **Creative applications**: the canvas system supports custom 2D drawing
  with shapes, paths, transforms, and interactive elements.
- **Multi-window applications**: your `view` returns a `List(Node)` of
  windows, each with its own layout, managed from a single model. See the
  [app lifecycle reference](../reference/app-lifecycle.md) for the full
  signature.
- **Reusable widget libraries**: compose existing widgets in pure Gleam,
  draw fully custom visuals with the canvas (including click, hover, drag,
  and keyboard interaction), or write Rust-backed native widgets when you
  need custom GPU rendering.
- **Remote rendering**: run your logic on a server or embedded device and
  render on a local display over SSH, as described above.

## What we will build in this guide

Throughout these chapters, we will build **Plushie Pad**, a live widget
editor for experimenting with the Plushie API.

The finished application has two panes. On the left, you write Plushie
widget code. On the right, you see it rendered in real time. An event log at
the bottom shows every event that fires as you interact with the rendered
output.

Each chapter adds a feature to the pad: events, layout, styling, animation,
subscriptions, canvas drawing, custom widgets, testing, and more. By the
final chapter, you will have a fully-featured editor that doubles as a
personal playground for trying out any part of the API.

Plushie Pad compiles code typed into the editor at runtime. BEAM ships with
an Erlang compiler, but there's no Gleam compiler we can call from a running
program, so experiments are written in Erlang. If you haven't used Erlang
before, copy the snippets as-is and they'll work. When you're ready to
understand what's happening under the hood, the
[Erlang interop reference](../reference/erlang-interop.md) covers the
Gleam-to-Erlang mapping.

Plushie supports hot code reloading. As you work through the guide, keep
the pad running. Every change you make shows up instantly. Each chapter
adds a new capability, and you will see it appear the moment you save.

Let's get started.

---

Next: [Getting Started](02-getting-started.md)
