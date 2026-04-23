# The Development Loop

In this chapter we cover hot reload and how to inspect a running app.

## Hot reload

Set `dev: True` in `GuiOpts` to enable hot code reloading:

```gleam
import plushie/gui

let opts = gui.GuiOpts(..gui.default_opts(), dev: True)
gui.run(app(), opts)
```

Plushie watches your `src/` directory. Edit any `.gleam` file, save it,
and the running app recompiles in place. Your model state is preserved.

Hot reload works because the runtime re-calls `view` with the current
model after recompilation. The new view function produces a new tree, the
runtime diffs it against the old one, and only the changes are sent to the
renderer.

## Inspecting a running app

Query the runtime state of a running app:

```gleam
let assert Ok(model) = plushie.get_model(instance)
let assert Ok(tree) = plushie.get_tree(instance)
```

`get_model` returns the current model. `get_tree` returns the normalized
UI tree. The `Instance(model)` type is parameterized, so `get_model`
returns the typed model directly with no dynamic coercion needed.

`plushie.dispatch_event(instance, event)` injects an event into the
runtime's message loop, bypassing the renderer. Useful for integration
tests to trigger state changes.

---

Next: [Events](05-events.md)
