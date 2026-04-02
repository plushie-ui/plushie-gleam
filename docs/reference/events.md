# Events

All user interactions, system responses, and asynchronous results are
delivered to your `update` callback as variants of `plushie/event.Event`.

For a gentler introduction, see the [Events guide](../guides/05-events.md).

## Event type

`plushie/event.Event` is a union type with constructors for every event
the runtime can produce.

## Event taxonomy

| Category | Constructors | Source |
|---|---|---|
| Widget interaction | `WidgetClick`, `WidgetInput`, `WidgetToggle`, etc. | Renderer |
| Pointer | `WidgetPress`, `WidgetRelease`, `WidgetMove`, `WidgetScroll`, `WidgetEnter`, `WidgetExit` | Canvas, pointer_area, subscriptions |
| Keyboard | `KeyPress`, `KeyRelease` | Subscription |
| Window | `WindowOpened`, `WindowClosed`, `WindowResized`, etc. | Renderer |
| Timer | `TimerTick` | Subscription |
| Async | `AsyncResult` | Command |
| Stream | `StreamValue` | Command |
| Effect | `EffectResult` | Renderer |
| System | `SystemInfo`, `ThemeChanged`, `AllWindowsClosed`, etc. | Renderer |
| Scroll | `WidgetScrolled` | Scrollable viewport |

## Standard widget events

| Constructor | Payload | Description |
|---|---|---|
| `WidgetClick` | none | Button pressed |
| `WidgetInput` | `value: String` | Text input changed |
| `WidgetSubmit` | `value: String` | Text input submitted (Enter) |
| `WidgetToggle` | `value: Bool` | Toggler/checkbox toggled |
| `WidgetSelect` | `value: String` | Pick list/combo box selection |
| `WidgetSlide` | `value: Float` | Slider moved |
| `WidgetSlideRelease` | `value: Float` | Slider released |
| `WidgetSort` | `column: String` | Table column sort requested |
| `WidgetScrolled` | `absolute_x`, `absolute_y`, etc. | Scrollable viewport changed |
| `WidgetTransitionComplete` | `tag: String` | Renderer-side transition completed |

## Unified pointer events

Pointer events replace the previous canvas_*, mouse_*, and sensor_*
families with a device-agnostic model. The `pointer` field identifies
the input device (Mouse, Touch, Pen).

| Constructor | Fields |
|---|---|
| `WidgetPress` | `x`, `y`, `button`, `pointer`, `finger`, `modifiers` |
| `WidgetRelease` | `x`, `y`, `button`, `pointer`, `finger`, `modifiers` |
| `WidgetMove` | `x`, `y`, `pointer`, `finger`, `modifiers` |
| `WidgetScroll` | `x`, `y`, `delta_x`, `delta_y`, `pointer`, `modifiers` |
| `WidgetEnter` | none |
| `WidgetExit` | none |
| `WidgetResize` | `width`, `height` |

All events carry `id`, `scope`, and `window_id` fields.

## Pattern matching

```gleam
case event {
  // By widget ID
  WidgetClick(id: "save", ..) -> save(model)

  // With value
  WidgetInput(id: "search", value: text, ..) ->
    Model(..model, query: text)

  // By scope (dynamic lists)
  WidgetClick(id: "delete", scope: [item_id, ..], ..) ->
    delete_item(model, item_id)

  // Key with modifiers
  KeyPress(key: "s", modifiers: m, ..) if m.command ->
    save(model)

  // Pointer event with device type
  WidgetPress(id: "area", pointer: event.Mouse, button: event.Left, ..) ->
    select(model)

  // Async result
  AsyncResult(tag: "fetch", result: Ok(data), ..) ->
    Model(..model, data: data)

  // Effect result
  EffectResult(tag: "open_file", result: Ok(data), ..) ->
    load_file(model, data.path)
  EffectResult(tag: "open_file", result: Cancelled, ..) ->
    model

  // Catch-all
  _ -> model
}
```

## Scope field

Events carry `id` (local) and `scope` (reversed ancestor chain, nearest
parent first, window ID last):

```gleam
WidgetClick(id: "save", scope: ["form", "sidebar", "main"], window_id: "main", ..)
```

## See also

- [Events guide](../guides/05-events.md)
- [Scoped IDs](scoped-ids.md)
- [Commands](commands.md)
