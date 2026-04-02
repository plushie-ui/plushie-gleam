# Accessibility

Plushie integrates with platform accessibility services via
[AccessKit](https://github.com/AccessKit/accesskit): VoiceOver on macOS,
AT-SPI/Orca on Linux, UI Automation/NVDA/JAWS on Windows. Most
accessibility semantics are inferred automatically from widget types.

## Auto-inference

### Role mapping

| Widget type | Inferred role |
|---|---|
| `button` | button |
| `text`, `rich_text` | label |
| `text_input` | text_input |
| `text_editor` | multiline_text_input |
| `checkbox` | check_box |
| `toggler` | switch |
| `radio` | radio_button |
| `slider`, `vertical_slider` | slider |
| `pick_list`, `combo_box` | combo_box |
| `progress_bar` | progress_indicator |
| `scrollable` | scroll_view |
| `image`, `svg`, `qr_code` | image |
| `canvas` | canvas |
| `table` | table |
| `window` | window |
| Containers (column, row, etc.) | generic_container |

### Label inference

| Widget type | Prop used as label |
|---|---|
| `button`, `checkbox`, `toggler`, `radio` | `label` prop |
| `text`, `rich_text` | `content` prop |
| `image`, `svg` | `alt` prop |
| `text_input` | `placeholder` prop (as description) |

## The a11y prop

Every widget accepts an `A11y` option for explicit overrides:

```gleam
import plushie/prop/a11y

ui.button("save", "Save", [
  button.A11y(a11y.new() |> a11y.description("Save the current document")),
])

ui.text_input("email", model.email, [
  text_input.A11y(a11y.new() |> a11y.required(True) |> a11y.labelled_by("email-label")),
])
```

### Fields

| Field | Type | Purpose |
|---|---|---|
| `role` | A11yRole | Override the inferred role |
| `label` | String | Accessible name |
| `description` | String | Longer description read after the label |
| `live` | Polite / Assertive | Live region announcement mode |
| `hidden` | Bool | Exclude from accessibility tree |
| `expanded` | Bool | Disclosure state |
| `required` | Bool | Form field is required |
| `level` | Int | Heading level (1-6) |
| `busy` | Bool | Suppress announcements during updates |
| `invalid` | Bool | Form validation error state |
| `modal` | Bool | Dialog is modal |
| `read_only` | Bool | Value is readable but not editable |
| `labelled_by` | String | ID of the widget providing this widget's label |
| `described_by` | String | ID of the widget providing a description |

Cross-reference IDs are resolved relative to the current scope during
tree normalisation. See [Scoped IDs](scoped-ids.md).

## Keyboard navigation

| Key | Behaviour |
|---|---|
| Tab / Shift+Tab | Cycle focus through focusable widgets |
| Space / Enter | Activate the focused widget |
| Arrow keys | Navigate within sliders, lists, etc. |
| F6 / Shift+F6 | Cycle focus between pane_grid panes |
| Escape | Close popups, dismiss modals |

### Canvas keyboard navigation

Canvas interactive groups opt into keyboard focus with `Focusable(True)`:

```gleam
shape.group("save-btn", [
  shape.OnClick(True),
  shape.Focusable(True),
  shape.A11y(a11y.new() |> a11y.role(a11y.Button) |> a11y.label("Save")),
], [...])
```

## Live regions

```gleam
ui.text("status", model.status_message, [
  text.A11y(a11y.new() |> a11y.live(a11y.Polite)),
])
ui.text("error", model.error, [
  text.A11y(a11y.new() |> a11y.live(a11y.Assertive) |> a11y.role(a11y.Alert)),
])
```

Use `Assertive` sparingly. Prefer `Polite` for anything that updates more
than once per user action.

## Testing accessibility

```gleam
testing.assert_role(session, "#save", "button")
testing.assert_a11y(session, "#email", [#("required", "true")])
```

## See also

- `plushie/prop/a11y` - full type and field documentation
- [Canvas reference](canvas.md) - canvas accessibility annotations
- [Scoped IDs reference](scoped-ids.md) - how `labelled_by` IDs are resolved
