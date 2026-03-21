# Layout

Toddy's layout model mirrors iced's. Understanding it is essential for
building UIs that size and position correctly.

## Length

Length controls how a widget claims space along an axis.

| Toddy value | Iced equivalent | Meaning |
|---|---|---|
| `Fill` | `Length::Fill` | Take all remaining space |
| `FillPortion(n)` | `Length::FillPortion(n)` | Proportional share of remaining space |
| `Shrink` | `Length::Shrink` | Use minimum/intrinsic size |
| `Fixed(200.0)` | `Length::Fixed(200.0)` | Exact pixel size |

<!-- test: layout_length_fill_test, layout_length_fixed_test, layout_length_fill_portion_test, layout_length_shrink_test -- keep this code block in sync with the test -->
```gleam
import toddy/ui
import toddy/prop/length.{Fill, FillPortion, Fixed, Shrink}
import toddy/prop/padding

// Fill available width
ui.column("main", [ui.width(Fill)], [...])

// Fixed width
ui.container("sidebar", [ui.width(Fixed(250.0))], [...])

// Proportional: left takes 2/3, right takes 1/3
ui.row("layout", [], [
  ui.container("left", [ui.width(FillPortion(2))], [...]),
  ui.container("right", [ui.width(FillPortion(1))], [...]),
])

// Shrink to content
ui.button("save", "Save", [ui.width(Shrink)])
```

### Default lengths

Most widgets default to `Shrink` for both width and height. Layout
containers (`column`, `row`) typically default to `Shrink` but grow to
accommodate their children.

## Padding

Padding is the space between a widget's boundary and its content.

| Toddy value | Meaning |
|---|---|
| `padding.all(10.0)` | Uniform: 10px on all sides |
| `padding.xy(10.0, 20.0)` | Axis: 10px vertical, 20px horizontal |
| `Padding(top: 5.0, right: 10.0, bottom: 5.0, left: 10.0)` | Per-side |
| `padding.none()` | No padding |

<!-- test: layout_padding_all_test, layout_padding_xy_test, layout_padding_per_side_test -- keep this code block in sync with the test -->
```gleam
ui.container("box", [ui.padding(padding.all(16.0))], [...])
ui.container("box", [ui.padding(padding.xy(8.0, 16.0))], [...])
ui.container("box", [ui.padding(Padding(top: 0.0, right: 16.0, bottom: 8.0, left: 16.0))], [...])
```

Padding is accepted by `container`, `column`, `row`, `scrollable`,
`button`, `text_input`, and `text_editor`.

## Spacing

Spacing is the gap between children in a layout container.

<!-- test: layout_spacing_test -- keep this code block in sync with the test -->
```gleam
ui.column("col", [ui.spacing(8)], [
  ui.text_("first", "First"),
  ui.text_("second", "Second"),   // 8px gap between First and Second
  ui.text_("third", "Third"),     // 8px gap between Second and Third
])
```

Spacing is accepted by `column`, `row`, and `scrollable`.

## Alignment

Alignment controls how children are positioned within their parent along
the cross axis.

### align_x (horizontal alignment in a column)

| Value | Meaning |
|---|---|
| `Start` or `Left` | Left-aligned |
| `Center` | Centered |
| `End` or `Right` | Right-aligned |

### align_y (vertical alignment in a row)

| Value | Meaning |
|---|---|
| `Start` or `Top` | Top-aligned |
| `Center` | Centered |
| `End` or `Bottom` | Bottom-aligned |

<!-- test: layout_align_x_column_test, layout_align_center_container_test -- keep this code block in sync with the test -->
```gleam
import toddy/prop/alignment.{Center}

// Center children horizontally in a column
ui.column("col", [ui.align_x(Center)], [
  ui.text_("label", "Centered"),
  ui.button_("ok", "OK"),
])

// Center a single child in a container
ui.container("page", [ui.width(Fill), ui.height(Fill), ui.align_x(Center), ui.align_y(Center)], [
  ui.text_("label", "Dead center"),
])
```

## Layout containers

### column

Arranges children vertically (top to bottom).

<!-- test: layout_column_with_props_test -- keep this code block in sync with the test -->
```gleam
ui.column("main", [ui.spacing(16), ui.padding(padding.all(20.0)), ui.width(Fill), ui.align_x(Center)], [
  ui.text("title", "Title", [ui.font_size(24.0)]),
  ui.text("subtitle", "Subtitle", [ui.font_size(14.0)]),
])
```

Props: `spacing`, `padding`, `width`, `height`, `align_x`.

### row

Arranges children horizontally (left to right).

<!-- test: layout_row_with_align_y_test -- keep this code block in sync with the test -->
```gleam
ui.row("nav", [ui.spacing(8), ui.align_y(Center)], [
  ui.button_("back", "<"),
  ui.text_("page", "Page 1 of 5"),
  ui.button_("next", ">"),
])
```

Props: `spacing`, `padding`, `width`, `height`, `align_y`, `wrap` (new
in toddy-iced -- wraps children to next line when they overflow).

### container

Wraps a single child with padding, alignment, and styling.

<!-- test: layout_container_with_style_test -- keep this code block in sync with the test -->
```gleam
ui.container("card", [ui.padding(padding.all(16.0)), ui.style("rounded_box"), ui.width(Fill)], [
  ui.column("card_col", [], [
    ui.text_("card_title", "Card title"),
    ui.text_("card_content", "Card content"),
  ]),
])
```

Props: `padding`, `width`, `height`, `align_x`, `align_y`,
`style`, `clip`.

### scrollable

Wraps content in a scrollable region.

<!-- test: layout_scrollable_test -- keep this code block in sync with the test -->
```gleam
ui.scrollable("list", [ui.height(Fixed(400.0)), ui.width(Fill)], [
  ui.column("items", [ui.spacing(4)], [
    // map over items to produce child nodes
  ]),
])
```

Props: `width`, `height`, `direction` (`"vertical"`, `"horizontal"`,
`"both"`), `spacing`.

### stack

Overlays children on top of each other (z-stacking). Later children
are on top.

<!-- test: layout_stack_test -- keep this code block in sync with the test -->
```gleam
ui.stack("layers", [], [
  ui.image("bg", "background.png", [ui.width(Fill), ui.height(Fill)]),
  ui.container("overlay", [ui.width(Fill), ui.height(Fill), ui.align_x(Center), ui.align_y(Center)], [
    ui.text("overlay_text", "Overlaid text", [ui.font_size(48.0)]),
  ]),
])
```

### space

Empty spacer. Takes up space without rendering anything.

<!-- test: layout_space_test -- keep this code block in sync with the test -->
```gleam
ui.row("spread", [], [
  ui.text_("left", "Left"),
  ui.space("gap", [ui.width(Fill)]),  // pushes Right to the far right
  ui.text_("right", "Right"),
])
```

### grid

Arranges children in a grid layout (new in toddy-iced).

<!-- test: layout_grid_test -- keep this code block in sync with the test -->
```gleam
ui.grid("gallery", [ui.spacing(8)], [
  // map over items to produce child nodes
])
```

## Common layout patterns

### Centered page

<!-- test: layout_centered_page_test -- keep this code block in sync with the test -->
```gleam
ui.container("page", [ui.width(Fill), ui.height(Fill), ui.align_x(Center), ui.align_y(Center)], [
  ui.column("content", [ui.spacing(16), ui.align_x(Center)], [
    ui.text("welcome", "Welcome", [ui.font_size(32.0)]),
    ui.button_("start", "Get Started"),
  ]),
])
```

### Sidebar + content

```gleam
ui.row("layout", [ui.width(Fill), ui.height(Fill)], [
  ui.container("sidebar", [ui.width(Fixed(250.0)), ui.height(Fill), ui.padding(padding.all(16.0))], [
    nav_items(model),
  ]),
  ui.container("content", [ui.width(Fill), ui.height(Fill), ui.padding(padding.all(16.0))], [
    main_content(model),
  ]),
])
```

### Header + body + footer

```gleam
ui.column("page", [ui.width(Fill), ui.height(Fill)], [
  ui.container("header", [ui.width(Fill), ui.padding(padding.xy(8.0, 16.0))], [
    header(model),
  ]),
  ui.scrollable("body", [ui.width(Fill), ui.height(Fill)], [
    body_content(model),
  ]),
  ui.container("footer", [ui.width(Fill), ui.padding(padding.xy(8.0, 16.0))], [
    footer(model),
  ]),
])
```
