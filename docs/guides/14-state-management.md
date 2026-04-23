# State Management

As apps grow, model management gets complex. Plushie provides standalone
helper modules for common patterns. Each is a pure data structure with no
processes or side effects.

## plushie/undo

Tracks reversible actions with an undo/redo stack:

```gleam
import plushie/undo

let history = undo.new("")
let history = undo.push(history, undo.Action(
  apply: fn(_old) { "hello" },
  undo: fn(_new) { "" },
  label: "Type hello",
))

undo.current(history)     // "hello"
undo.can_undo(history)    // True

let history = undo.undo(history)
undo.current(history)     // ""
```

Coalescing groups rapid sequential changes into a single undo step.

## plushie/data

Query pipeline for filtering, searching, sorting, and paginating:

```gleam
import plushie/data

let result = data.query(records, [
  data.Search(
    fields: [fn(record) { record.name }, fn(record) { record.role }],
    query: "dev",
  ),
  data.Sort(direction: data.Asc, key: fn(record) { record.name }),
  data.Page(1),
  data.PageSize(10),
])
```

Repeated `Filter` and `Search` opts compose as successive narrowing.
All filters run first, in list order, then all searches run, in list
order, before sorting and pagination.

## plushie/selection

Manages selection state for lists with three modes: `Single`, `Multi`,
and `Range`.

```gleam
import plushie/selection

let sel = selection.new(selection.Multi)
let sel = selection.toggle(sel, "file_a")
selection.selected(sel, "file_a")  // True
```

## plushie/route

Navigation stack for multi-view apps:

```gleam
import plushie/route

let nav = route.new("editor")
let nav = route.push(nav, "browser")
route.current(nav)        // "browser"
route.can_go_back(nav)    // True

let nav = route.pop(nav)
route.current(nav)        // "editor"
```

## plushie/animation/tween

For SDK-side frame-by-frame animation. Requires an
`on_animation_frame` subscription. See the
[Animation reference](../reference/animation.md) for details.

---

Next: [Testing](15-testing.md)
