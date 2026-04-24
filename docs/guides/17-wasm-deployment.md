# WASM Deployment

Plushie compiles for two targets. Until now the guides have
assumed the BEAM target: a Gleam app that owns its model on the
Erlang VM and drives a native renderer process over stdin/stdout.
The JavaScript target takes a different approach. Your whole app,
model and update loop and view, compiles to JavaScript and runs
inside the browser. The renderer rides along as a WebAssembly
module in the same page.

There is no backend. No WebSocket. The Elm loop and the renderer
are both client-side, talking to each other across a JS function
call boundary.

## When to reach for it

The JS target is the right choice when you want the same Plushie
app to run in a browser tab. The wrong choice when you need
multi-window, native file dialogs, or the filesystem APIs that
the desktop runtime exposes. See the limitations section below
before committing.

## Prerequisites

- A working BEAM toolchain (you still build source with `gleam
  build --target=javascript`).
- `wasm-pack` on `PATH` to compile the renderer.
- A local plushie-rust checkout; WASM renderer builds always run
  from source. Point at it with `PLUSHIE_RUST_SOURCE_PATH`.
- A static file server or CDN for serving the compiled output.

The SDK ships no precompiled WASM by default. Download one with
`gleam run -m plushie/download -- --wasm` for released versions,
or build your own.

## Opting into the WASM artifact

Add `"wasm"` to `artifacts` in `gleam.toml`. The default is
`["bin"]`, which only produces the native renderer.

```toml
[plushie]
artifacts = ["bin", "wasm"]
wasm_dir = "priv/static/wasm"
```

`wasm_dir` is the destination for `plushie_renderer_wasm.js` and
`plushie_renderer_wasm_bg.wasm`. If you omit it, the files land
in `priv/wasm/`. See the [Configuration reference](../reference/configuration.md)
for the full `[plushie]` section.

## Building the renderer

```bash
PLUSHIE_RUST_SOURCE_PATH=~/projects/plushie-rust \
  gleam run -m plushie/build -- --wasm

# Production build, optimized
PLUSHIE_RUST_SOURCE_PATH=~/projects/plushie-rust \
  gleam run -m plushie/build -- --wasm --release

# Build native and WASM together
PLUSHIE_RUST_SOURCE_PATH=~/projects/plushie-rust \
  gleam run -m plushie/build -- --bin --wasm
```

See the [CLI commands reference](../reference/cli-commands.md)
for the full flag list.

## Compiling your app to JS

Gleam's JavaScript target compiles all the pure Plushie modules
(widgets, props, tree, protocol, events, commands) plus the
target-specific `plushie_web` entry point.

```bash
gleam build --target=javascript
```

Output lands under `build/dev/javascript/<your_project>/`. The
entry point you import from HTML is whichever module contains
your `main`.

## The HTML shim

The browser needs to load three things in order: the WASM module
(so the renderer constructor exists), the generated JS bundle for
your Gleam code, and a small shim that wires them together.

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Counter</title>
  <style>
    body { margin: 0; overflow: hidden; }
    canvas { width: 100vw; height: 100vh; display: block; }
  </style>
</head>
<body>
  <canvas id="plushie-canvas"></canvas>
  <script type="module">
    import init, { PlushieApp } from "./wasm/plushie_renderer_wasm.js";
    import { setPlushieAppConstructor }
      from "./build/dev/javascript/plushie_gleam/plushie_bridge_web_ffi.mjs";
    import { main }
      from "./build/dev/javascript/my_app/my_app.mjs";

    await init();
    setPlushieAppConstructor(PlushieApp);
    main();
  </script>
</body>
</html>
```

`setPlushieAppConstructor` must be called after `init()` resolves
and before `main()` runs. The constructor is the `PlushieApp`
class exported by the wasm-bindgen glue; the SDK uses it to
instantiate the renderer when `plushie_web.start` runs.

## The Gleam entry point

The JS entry point mirrors the BEAM one, but lives in
`plushie_web` instead of `plushie`.

```gleam
import plushie_web
import plushie/app.{type App}
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/ui
import plushie/widget/window
import gleam/int

pub type Model {
  Model(count: Int)
}

pub fn main() {
  let counter = app.simple(
    fn(_) { #(Model(0), command.none()) },
    fn(model, event) {
      case event {
        WidgetClick(id: "inc", ..) ->
          #(Model(model.count + 1), command.none())
        _ -> #(model, command.none())
      }
    },
    fn(model) {
      [
        ui.window("main", [window.Title("Counter")], [
          ui.text_("count", "Count: " <> int.to_string(model.count)),
          ui.button_("inc", "+"),
        ]),
      ]
    },
  )
  let assert Ok(_instance) =
    plushie_web.start(counter, plushie_web.default_start_opts())
}
```

`plushie_web.start` returns `Result(WebInstance(model),
WebStartError)`. The only error variant today is `WasmInitFailed`,
reported when the WASM module is missing or rejects the settings
message. Use `plushie_web.start_error_to_string` for a human
string.

`WebInstance(model)` has the same shape as the BEAM `Instance`:
`get_model`, `get_tree`, `dispatch_event`, and `stop`.

## Serving the output

The compiled JS and the `.wasm` binary are static assets. Any
HTTP server works. The `.wasm` file should be served with the
`application/wasm` MIME type; most servers already do this, but
check if loading stalls.

```bash
cd build/dev/javascript && python3 -m http.server 8080
```

For production, enable gzip or brotli compression on the
renderer's `.wasm`. It compresses well and dominates page weight
on first load.

## Limitations vs the native runtime

The JS target is not a drop-in replacement for native. These
differences are architectural, not bugs:

- **Single window.** WASM renders into one `<canvas>` element.
  If your `view` returns a list with more than one top-level
  `ui.window` node, the runtime logs a `MultipleTopLevelWindows`
  diagnostic and collapses peers into the first window.
- **No native file dialogs.** `effect.file_open`,
  `effect.file_save`, and the directory variants return
  `EffectUnsupported` on WASM. Use browser APIs (`<input
  type="file">`, the File System Access API) via FFI if you
  need file input.
- **Clipboard is gesture-gated.** Browsers only allow clipboard
  reads and writes during a user gesture. Commands dispatched
  outside that window will reject.
- **No system notifications.** The Web Notifications API is
  available but Plushie does not call it; wire it up through
  FFI if needed.
- **No native widgets.** Widget crates listed under `[plushie]
  native_widgets` only compile into the desktop renderer.
- **No OTP.** Subscriptions still work, commands still work,
  async tasks still work (via `Promise`), but there is no
  supervision tree and no bridge restart. If the WASM module
  crashes, the page is done; reload.

The wire protocol itself is identical. `plushie_web` uses the
JSON format; MessagePack is BEAM-only. See the
[Wire Protocol reference](../reference/wire-protocol.md) for the
format details.

## Development workflow

The fastest iteration loop uses the native runtime. `gleam run
-m plushie/gui` launches a real window, the dev server watches
`src/`, and hot reload swaps modules on save. That loop catches
most app-level bugs before you touch the browser.

Run the WASM build periodically to catch target drift. A minimal
check:

```bash
gleam build --target=javascript
PLUSHIE_RUST_SOURCE_PATH=../plushie-rust \
  gleam run -m plushie/build -- --wasm
cd build/dev/javascript && python3 -m http.server 8080
```

Then open the HTML shim in a browser and smoke-test the critical
paths. The browser devtools console surfaces runtime warnings
(protocol mismatches, normalization errors) with the same
`plushie:` prefix used on BEAM.

That's the full guide. See the [reference documentation](../README.md#reference)
for every prop, command, and event in detail.
