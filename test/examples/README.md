# Examples

Each example is a standalone plushie app with a `main()` entry point.

## Apps

- **counter** -- Minimal Elm-architecture demo: increment/decrement buttons.
- **clock** -- Timer subscription with derived display formatting.
- **todo** -- Text input, list management, checkbox toggling.
- **color_picker** -- HSV color picker with canvas drag interaction. Uses
  the extracted `widgets/color_picker_widget` for rendering.
- **rate_plushie** -- App rating page composing StarRating and ThemeToggle
  canvas widgets with styled containers, theme animation, and keyboard input.
- **async_fetch** -- Async HTTP fetch with loading/error states.
- **catalog** -- Widget catalog showing available UI components.
- **notes** -- Multi-window note editor.
- **shortcuts** -- Keyboard shortcut handling demo.

## Reusable widgets (examples/widgets/)

- **star_rating** -- Canvas-based 5-star rating with hover preview.
- **theme_toggle** -- Animated emoji toggle switch with smoothstep easing.
- **color_picker_widget** -- HSV hue ring + SV square canvas widget with
  geometry accessors for consumer hit testing.

## Running

```
gleam run -m examples/<name>
```
