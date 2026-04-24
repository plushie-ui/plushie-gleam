# Accessibility

Plushie integrates with platform accessibility services via
[AccessKit](https://github.com/AccessKit/accesskit): VoiceOver on
macOS, AT-SPI / Orca on Linux, UI Automation / NVDA / JAWS on
Windows. Most accessibility semantics are inferred automatically
from widget types, so correct roles, labels, and state ship without
extra work. The SDK-side types live in `plushie/prop/a11y`, widget
defaults in `plushie/widget/build`, focus and announcement commands
in `plushie/command`, and related diagnostics in `plushie/event`.

## Accessible by default

Built-in widgets expose accessibility metadata automatically: a
button announces itself as a button, a checkbox tracks its checked
state, a slider exposes its numeric value and range. The widget
builder fills in `role` and (where applicable) a default `label`
derived from the widget's label or content prop before the node
reaches the wire.

Layout containers that wrap other widgets (`column`, `row`,
`container`, `stack`, `grid`, `keyed_column`, `space`, ...) do not
emit an inferred role and are filtered from the platform
accessibility tree. Screen reader users navigate through the
semantic content (buttons, text, inputs) without encountering
intermediate layout wrappers.

When overrides are needed (custom canvas controls, widgets with
context-dependent labels, relationship annotations), the `A11y`
prop is available on every widget.

## Auto-inference

### Role mapping

| Widget | Inferred role |
|---|---|
| `button` | `button` |
| `text`, `rich_text` | `label` |
| `text_input` | `text_input` |
| `text_editor` | `multiline_text_input` |
| `checkbox` | `check_box` |
| `toggler` | `switch` |
| `radio` | `radio_button` |
| `slider`, `vertical_slider` | `slider` |
| `pick_list`, `combo_box` | `combo_box` |
| `progress_bar` | `progress_indicator` |
| `scrollable` | `scroll_view` |
| `image`, `svg`, `qr_code` | `image` |
| `canvas` | `canvas` |
| `table` | `table` |
| `pane_grid` | `group` |
| `rule` | `splitter` |
| `window` | `window` |
| `markdown` | `document` |
| `tooltip` | `tooltip` |

### Label inference

The builder looks up the label from a named prop when the caller
did not pass an explicit `A11y`:

| Widget | Prop used as label |
|---|---|
| `button`, `checkbox`, `toggler`, `radio` | `label` |
| `text`, `rich_text` | `content` |
| `image`, `svg` | `alt` |

An explicit `A11y` always replaces the inferred defaults for that
widget; the builder does not merge the two.

## The A11y prop

`A11y` is an opaque record built by chaining setters onto
`a11y.new()`. Every widget exposes an `A11y(A11y)` opt that carries
one through to the wire:

```gleam
import plushie/prop/a11y
import plushie/ui
import plushie/widget/button
import plushie/widget/text_input

ui.button("save", "Save", [
  button.A11y(
    a11y.new()
    |> a11y.description("Save the current document"),
  ),
])

ui.text_input("email", model.email, [
  text_input.A11y(
    a11y.new()
    |> a11y.required(True)
    |> a11y.labelled_by("email-label"),
  ),
])
```

Typed builders expose an `a11y/2` setter that accepts the same
record directly: `button.new("save", "Save") |> button.a11y(...)`.

### Setters

| Setter | Argument | Purpose |
|---|---|---|
| `a11y.role` | `Role` | Override the inferred role |
| `a11y.label` | `String` | Accessible name |
| `a11y.description` | `String` | Longer description read after the label |
| `a11y.live` | `String` (`"polite"` or `"assertive"`) | Live region mode |
| `a11y.hidden` | `Bool` | Exclude from the accessibility tree |
| `a11y.expanded` | `Bool` | Disclosure state |
| `a11y.required` | `Bool` | Form field is required |
| `a11y.level` | `Int` (1-6) | Heading level |
| `a11y.busy` | `Bool` | Suppress announcements during updates |
| `a11y.invalid` | `Bool` | Form validation error state |
| `a11y.modal` | `Bool` | Dialog is modal |
| `a11y.read_only` | `Bool` | Value is readable but not editable |
| `a11y.toggled` | `Bool` | Toggle / checked state |
| `a11y.selected` | `Bool` | Selection state |
| `a11y.value` | `String` | Current value for assistive technology |
| `a11y.orientation` | `Orientation` (`Horizontal`, `Vertical`) | Layout orientation hint |
| `a11y.disabled` | `Bool` | Disabled state override |
| `a11y.mnemonic` | `String` (single grapheme) | Keyboard mnemonic |
| `a11y.position_in_set` | `Int` | 1-based position in a group |
| `a11y.size_of_set` | `Int` | Total items in the group |
| `a11y.has_popup` | `HasPopup` (`ListboxPopup`, `MenuPopup`, `DialogPopup`, `TreePopup`, `GridPopup`) | Popup type |
| `a11y.labelled_by` | `String` | ID of a widget that labels this one |
| `a11y.described_by` | `String` | ID of a widget that describes this one |
| `a11y.error_message` | `String` | ID of a widget showing the validation error |
| `a11y.set` | `String`, `PropValue` | Escape hatch for arbitrary keys |

`mnemonic` panics at build time if the argument is not a single
grapheme.

### Cross-references

`labelled_by`, `described_by`, and `error_message` hold widget IDs.
Tree normalization resolves them relative to the current scope, so
a bare `"label"` inside scope `"form"` rewrites to `"form/label"`.
Unresolved refs produce an `A11yRefUnresolved` diagnostic (see
below) and the ID is left as-is on the wire.

### Roles

The `Role` type covers the vocabulary the renderer accepts. Wire
values are snake_case strings produced by `a11y.role_to_string`.

**Interactive**: `Button`, `CheckBox`, `ComboBox`, `Link`,
`MenuItem`, `RadioButton`, `Slider`, `Switch`, `Tab`, `TextInput`,
`MultilineTextInput`, `TreeItem`

**Structure**: `Group`, `Heading`, `Label`, `List`, `ListItem`,
`ColumnHeader`, `Row`, `Cell`, `Table`, `Tree`

**Landmarks**: `Navigation`, `Region`, `Search`

**Status**: `Alert`, `AlertDialog`, `Dialog`, `Status`, `Meter`,
`ProgressIndicator`

**Other**: `Canvas`, `Document`, `Image`, `Menu`, `MenuBar`,
`ScrollBar`, `ScrollView`, `Separator`, `StaticText`, `TabList`,
`TabPanel`, `Toolbar`, `Tooltip`, `Window`

## Accessible name computation

When a screen reader encounters a widget, it announces the widget's
accessible name. Resolution order:

1. **Direct label** - the explicit `a11y.label(...)` or the
   inferred `label` derived from the widget's label prop.
2. **Labelled-by** - if no direct label, the renderer follows
   `labelled_by` to a sibling widget. For roles that support
   name-from-contents (button, checkbox, radio, link), descendant
   text is used automatically.
3. **No name** - the screen reader announces only the role.

Interactive widgets without an accessible name trigger a
`MissingAccessibleName` diagnostic during tree normalization.

## Keyboard navigation

| Key | Behaviour |
|---|---|
| Tab / Shift+Tab | Cycle focus through focusable widgets |
| Space / Enter | Activate the focused widget |
| Arrow keys | Navigate within sliders, lists, and similar widgets |
| F6 / Shift+F6 | Cycle focus between pane_grid panes |
| Ctrl+Tab | Escape the current focus scope |
| Escape | Close popups, dismiss modals |

Focus follows the focus-visible pattern: focus rings appear on
keyboard navigation and not on mouse clicks.

### Focus commands

Commands from `plushie/command` drive focus programmatically:

| Function | Purpose |
|---|---|
| `command.focus(widget_id)` | Move focus to a specific widget |
| `command.focus_next()` | Move to the next focusable widget |
| `command.focus_previous()` | Move to the previous focusable widget |
| `command.focus_next_within(scope)` | Next focusable widget inside a subtree, wrapping at the boundary |
| `command.focus_previous_within(scope)` | Previous focusable widget inside a subtree, wrapping at the boundary |
| `command.find_focused(tag)` | Query which widget currently has focus; result arrives as `System(FocusedWidget(tag, widget_id))` |
| `command.focus_window(window_id)` | Bring a window to the front |

`command.focus` targets canvas elements via their scoped path
(`"canvas/element"`).

### Canvas keyboard navigation

Canvas interactive elements opt into keyboard focus via the
`Focusable(True)` interactive opt. Without `Focusable(True)`, the
element responds to mouse clicks but is invisible to keyboard
navigation and screen readers. Interactive elements infer a role
from their options; an explicit `A11y(PropValue)` override
replaces the inferred defaults.

```gleam
import plushie/canvas/shape
import plushie/node.{DictVal, StringVal}
import gleam/dict

shape.interactive_group("save-btn", [
  shape.OnClick(True),
  shape.Focusable(True),
  shape.Cursor("pointer"),
  shape.A11y(DictVal(dict.from_list([
    #("role", StringVal("button")),
    #("label", StringVal("Save experiment")),
  ]))),
], [
  shape.rect(0.0, 0.0, 100.0, 36.0, []),
  shape.text(50.0, 11.0, "Save", []),
])
```

## Announcements and live regions

### Live regions

`a11y.live("polite")` or `a11y.live("assertive")` turns a widget
into a live region. The renderer re-announces the widget's label
or content when it changes.

| Value | Behaviour | Use for |
|---|---|---|
| `"polite"` | Announced after current speech finishes | Status messages, counters, progress updates |
| `"assertive"` | Interrupts current speech immediately | Error messages, critical alerts |

```gleam
import plushie/prop/a11y
import plushie/ui
import plushie/widget/text

ui.text("status", model.status_message, [
  text.A11y(a11y.new() |> a11y.live("polite")),
])

ui.text("error", model.error, [
  text.A11y(
    a11y.new()
    |> a11y.live("assertive")
    |> a11y.role(a11y.Alert),
  ),
])
```

Reserve `"assertive"` for urgent context. Rapid updates on an
assertive region cause announcement storms. Prefer `"polite"` for
anything that updates more than once per user action. Do not
apply `live` to static content; screen readers re-announce on
every tree rebuild even when the content did not change.

### Direct announcements

Commands push text straight to assistive technology without a
visible widget:

| Function | Purpose |
|---|---|
| `command.announce(text)` | Polite announcement |
| `command.announce_with(text, politeness)` | Explicit politeness |
| `command.announce_assertive(text)` | Shortcut for assertive politeness |

`Politeness` is `Polite` or `Assertive` from `plushie/command`.

```gleam
import plushie/command

#(Model(..model, saved: True), command.announce("Document saved"))
```

## Accessibility events

Accessibility-related interactions arrive through the standard
event pipeline. Assistive technology actions (e.g. VoiceOver
"activate") produce the same `WidgetEvent` as direct interaction,
so no special handling is required in `update`.

| Event | Meaning |
|---|---|
| `Widget(Focused(target))` | A widget received keyboard focus |
| `Widget(Blurred(target))` | A widget lost keyboard focus |
| `System(FocusedWidget(tag, widget_id))` | Reply to `command.find_focused` |
| `System(Announce(text))` | Renderer-originated announcement notice |

```gleam
import plushie/event.{
  Blurred, EventTarget, Focused, FocusedWidget, System, Widget,
}

case event {
  Widget(Focused(target: EventTarget(id: "email", ..))) ->
    Model(..model, editing_field: Some("email"))

  Widget(Blurred(target: EventTarget(id: "email", ..))) ->
    validate_email(model)

  System(FocusedWidget(tag: "check_focus", widget_id: Some(id))) ->
    Model(..model, focus_trace: [id, ..model.focus_trace])

  _ -> model
}
```

Keyboard focus scoped to a widget arrives as `Widget(WidgetKeyPress(...))`
and `Widget(WidgetKeyRelease(...))`. See the [Events
reference](events.md) for their full field sets.

## Diagnostics

The renderer emits typed diagnostics for accessibility problems
via `Error(Diagnostic(session, level, payload))`. Relevant
variants from `plushie/event.Diagnostic`:

| Variant | Meaning |
|---|---|
| `MissingAccessibleName(type_name, id)` | An interactive widget had no label, text child, `a11y.label`, or `a11y.labelled_by` |
| `A11yRefUnresolved(id, key, value, is_member)` | A `labelled_by`, `described_by`, or `error_message` ID did not resolve |

`key` on `A11yRefUnresolved` identifies which field held the bad
reference. `is_member` is true when the ref was inside a
collection (e.g. a radio group's members list). Treat both
diagnostics as authoring bugs: the affected widget ships to the
platform without the missing metadata.

```gleam
import plushie/event.{
  A11yRefUnresolved, Diagnostic, Error, MissingAccessibleName,
}

case event {
  Error(Diagnostic(payload: MissingAccessibleName(type_name: t, id: id), ..)) ->
    log_warning(model, "widget " <> t <> "#" <> id <> " has no accessible name")

  Error(Diagnostic(payload: A11yRefUnresolved(id: id, key: k, value: v, ..), ..)) ->
    log_warning(
      model,
      "a11y." <> k <> "=\"" <> v <> "\" on " <> id <> " did not resolve",
    )

  _ -> model
}
```

## Disabled vs read-only

These are semantically different:

| State | Meaning | Screen reader behaviour |
|---|---|---|
| Disabled | Not currently usable | Often skipped in Tab navigation, announced as "dimmed" or "unavailable" |
| Read-only | Has a value that can be read but not changed | Fully navigable and announced, editing commands blocked |

Use `a11y.disabled(True)` (or the widget's own `disabled` setter
where available) for controls that become active based on other
state. Use `a11y.read_only(True)` for displaying values the user
can select and copy but not edit.

## Common patterns

### Form field labelling

Every form control needs an accessible name. Three approaches:

Direct label:

```gleam
import plushie/prop/a11y
import plushie/ui
import plushie/widget/text_input

ui.text_input("email", model.email, [
  text_input.Placeholder("Email address"),
  text_input.A11y(a11y.new() |> a11y.label("Email address")),
])
```

Cross-widget `labelled_by`:

```gleam
ui.text("email-label", "Email address", [])
ui.text_input("email", model.email, [
  text_input.A11y(a11y.new() |> a11y.labelled_by("email-label")),
])
```

Description for additional context:

```gleam
ui.text_input("password", model.password, [
  text_input.A11y(
    a11y.new()
    |> a11y.label("Password")
    |> a11y.described_by("password-hint"),
  ),
])
ui.text("password-hint", "Must be at least 8 characters", [])
```

`text_input.required(True)` and `text_input.validation(...)` flow
into `a11y.required`, `a11y.invalid`, and `a11y.error_message`
automatically, so validation metadata does not need a separate
`A11y` record.

### Grouping related controls

Use the `Group` role when controls are logically related and the
grouping helps the user understand context:

```gleam
import plushie/prop/a11y
import plushie/ui
import plushie/widget/container

ui.container("shipping-options", [
  container.A11y(
    a11y.new()
    |> a11y.role(a11y.Group)
    |> a11y.label("Shipping options"),
  ),
], [
  ui.radio("standard", "standard", model.shipping, "Standard (5-7 days)", []),
  ui.radio("express", "express", model.shipping, "Express (1-2 days)", []),
])
```

Layout containers without an `A11y` override already filter out
of the tree, so wrapping things in groups unnecessarily only adds
noise.

## Testing

The test facade in `plushie/testing` exposes assertions that
operate on the resolved accessibility tree, catching missing
labels, wrong roles, and missing state annotations:

```gleam
import gleam/dict
import plushie/testing
import plushie/testing/backend

testing.find_by(ctx, backend.ByRole("button"))
testing.find_by(ctx, backend.ByLabel("Save"))
testing.find_by(ctx, backend.Focused)

let expected = dict.from_list([#("required", "true")])
testing.assert_a11y(ctx, "email", expected)

testing.resolved_a11y(ctx, "email")
```

`resolved_a11y` returns the a11y dict after inference and
normalization, so tests see what assistive technology will see.
See the [Testing reference](testing.md) for the full assertion
API.

## Platform notes

| Platform | AT service | Integration |
|---|---|---|
| macOS | VoiceOver | AccessKit to NSAccessibility |
| Linux | Orca (AT-SPI) | AccessKit to AT-SPI2 |
| Windows | NVDA / JAWS | AccessKit to UI Automation |

NVDA and JAWS operate in browse mode and focus mode, auto-switching
to focus mode when Tab reaches an interactive control. VoiceOver
uses a rotor for category-based navigation; correct roles ensure
widgets appear in the right rotor categories. Orca provides
structural navigation similar to browse mode. Wayland keyboard
input is currently broken for Linux screen readers, so Linux
screen reader users need X11.

## See also

- [Built-in Widgets reference](built-in-widgets.md) - widget list
  and the `A11y` opt on every widget
- [Events reference](events.md) - `Focused`, `Blurred`, system
  events, and the `Diagnostic` variant list
- [Commands reference](commands.md) - focus commands, announcements,
  and `find_focused`
- [Scoped IDs reference](scoped-ids.md) - how `labelled_by`,
  `described_by`, and `error_message` resolve
- [Canvas reference](canvas.md) - canvas accessibility annotations
  and interactive elements
