import gleam/dict
import plushie/node.{FloatVal, IntVal, StringVal}
import plushie/prop/alignment.{Center}
import plushie/prop/length.{Fill, FillPortion, Fixed, Shrink}
import plushie/prop/padding.{Padding}
import plushie/ui
import plushie/widget/button
import plushie/widget/column
import plushie/widget/container
import plushie/widget/grid
import plushie/widget/image
import plushie/widget/row
import plushie/widget/scrollable
import plushie/widget/space
import plushie/widget/text

// -- Length examples ----------------------------------------------------------

pub fn layout_length_fill_test() {
  let node = ui.column("main", [column.Width(Fill)], [])
  assert node.kind == "column"
  assert dict.get(node.props, "width") == Ok(StringVal("fill"))
}

pub fn layout_length_fixed_test() {
  let node = ui.container("sidebar", [container.Width(Fixed(250.0))], [])
  assert node.kind == "container"
  assert dict.get(node.props, "width") == Ok(FloatVal(250.0))
}

pub fn layout_length_fill_portion_test() {
  let left = ui.container("left", [container.Width(FillPortion(2))], [])
  let right = ui.container("right", [container.Width(FillPortion(1))], [])
  let row = ui.row("layout", [], [left, right])
  assert row.kind == "row"
  let assert [l, r] = row.children
  assert l.id == "left"
  assert r.id == "right"
  assert dict.get(l.props, "width")
    == Ok(node.DictVal(dict.from_list([#("fill_portion", IntVal(2))])))
  assert dict.get(r.props, "width")
    == Ok(node.DictVal(dict.from_list([#("fill_portion", IntVal(1))])))
}

pub fn layout_length_shrink_test() {
  let node = ui.button("save", "Save", [button.Width(Shrink)])
  assert node.kind == "button"
  assert dict.get(node.props, "width") == Ok(StringVal("shrink"))
}

// -- Padding examples ---------------------------------------------------------

pub fn layout_padding_all_test() {
  let node = ui.container("box", [container.Padding(padding.all(16.0))], [])
  let expected =
    node.DictVal(
      dict.from_list([
        #("top", FloatVal(16.0)),
        #("right", FloatVal(16.0)),
        #("bottom", FloatVal(16.0)),
        #("left", FloatVal(16.0)),
      ]),
    )
  assert dict.get(node.props, "padding") == Ok(expected)
}

pub fn layout_padding_xy_test() {
  let node = ui.container("box", [container.Padding(padding.xy(8.0, 16.0))], [])
  let expected =
    node.DictVal(
      dict.from_list([
        #("top", FloatVal(8.0)),
        #("right", FloatVal(16.0)),
        #("bottom", FloatVal(8.0)),
        #("left", FloatVal(16.0)),
      ]),
    )
  assert dict.get(node.props, "padding") == Ok(expected)
}

pub fn layout_padding_per_side_test() {
  let node =
    ui.container(
      "box",
      [
        container.Padding(Padding(
          top: 0.0,
          right: 16.0,
          bottom: 8.0,
          left: 16.0,
        )),
      ],
      [],
    )
  let expected =
    node.DictVal(
      dict.from_list([
        #("top", FloatVal(0.0)),
        #("right", FloatVal(16.0)),
        #("bottom", FloatVal(8.0)),
        #("left", FloatVal(16.0)),
      ]),
    )
  assert dict.get(node.props, "padding") == Ok(expected)
}

// -- Spacing example ----------------------------------------------------------

pub fn layout_spacing_test() {
  let node =
    ui.column("col", [column.Spacing(8)], [
      ui.text_("first", "First"),
      ui.text_("second", "Second"),
      ui.text_("third", "Third"),
    ])
  assert node.kind == "column"
  assert dict.get(node.props, "spacing") == Ok(IntVal(8))
  let assert [a, b, c] = node.children
  assert dict.get(a.props, "content") == Ok(StringVal("First"))
  assert dict.get(b.props, "content") == Ok(StringVal("Second"))
  assert dict.get(c.props, "content") == Ok(StringVal("Third"))
}

// -- Alignment examples -------------------------------------------------------

pub fn layout_align_x_column_test() {
  let node =
    ui.column("col", [column.AlignX(Center)], [
      ui.text_("label", "Centered"),
      ui.button_("ok", "OK"),
    ])
  assert node.kind == "column"
  assert dict.get(node.props, "align_x") == Ok(StringVal("center"))
  let assert [text, btn] = node.children
  assert dict.get(text.props, "content") == Ok(StringVal("Centered"))
  assert dict.get(btn.props, "label") == Ok(StringVal("OK"))
}

pub fn layout_align_center_container_test() {
  let node =
    ui.container(
      "page",
      [
        container.Width(Fill),
        container.Height(Fill),
        container.AlignX(Center),
        container.AlignY(Center),
      ],
      [ui.text_("label", "Dead center")],
    )
  assert node.kind == "container"
  assert dict.get(node.props, "width") == Ok(StringVal("fill"))
  assert dict.get(node.props, "height") == Ok(StringVal("fill"))
  assert dict.get(node.props, "align_x") == Ok(StringVal("center"))
  assert dict.get(node.props, "align_y") == Ok(StringVal("center"))
  let assert [child] = node.children
  assert dict.get(child.props, "content") == Ok(StringVal("Dead center"))
}

// -- Layout container examples ------------------------------------------------

pub fn layout_column_with_props_test() {
  let node =
    ui.column(
      "main",
      [
        column.Spacing(16),
        column.Padding(padding.all(20.0)),
        column.Width(Fill),
        column.AlignX(Center),
      ],
      [
        ui.text("title", "Title", [text.Size(24.0)]),
        ui.text("subtitle", "Subtitle", [text.Size(14.0)]),
      ],
    )
  assert node.kind == "column"
  assert dict.get(node.props, "spacing") == Ok(IntVal(16))
  assert dict.get(node.props, "width") == Ok(StringVal("fill"))
  assert dict.get(node.props, "align_x") == Ok(StringVal("center"))
  let assert [title, subtitle] = node.children
  assert dict.get(title.props, "size") == Ok(FloatVal(24.0))
  assert dict.get(subtitle.props, "size") == Ok(FloatVal(14.0))
}

pub fn layout_row_with_align_y_test() {
  let node =
    ui.row("nav", [row.Spacing(8), row.AlignY(Center)], [
      ui.button_("back", "<"),
      ui.text_("page", "Page 1 of 5"),
      ui.button_("next", ">"),
    ])
  assert node.kind == "row"
  assert dict.get(node.props, "spacing") == Ok(IntVal(8))
  assert dict.get(node.props, "align_y") == Ok(StringVal("center"))
  let assert [back, page, next] = node.children
  assert dict.get(back.props, "label") == Ok(StringVal("<"))
  assert dict.get(page.props, "content") == Ok(StringVal("Page 1 of 5"))
  assert dict.get(next.props, "label") == Ok(StringVal(">"))
}

pub fn layout_container_with_style_test() {
  let node =
    ui.container(
      "card",
      [
        container.Padding(padding.all(16.0)),
        container.Style("rounded_box"),
        container.Width(Fill),
      ],
      [
        ui.column("card_col", [], [
          ui.text_("card_title", "Card title"),
          ui.text_("card_content", "Card content"),
        ]),
      ],
    )
  assert node.kind == "container"
  assert dict.get(node.props, "style") == Ok(StringVal("rounded_box"))
  assert dict.get(node.props, "width") == Ok(StringVal("fill"))
  let assert [col] = node.children
  assert col.kind == "column"
  let assert [t, c] = col.children
  assert dict.get(t.props, "content") == Ok(StringVal("Card title"))
  assert dict.get(c.props, "content") == Ok(StringVal("Card content"))
}

pub fn layout_scrollable_test() {
  let node =
    ui.scrollable(
      "list",
      [scrollable.Height(Fixed(400.0)), scrollable.Width(Fill)],
      [
        ui.column("items", [column.Spacing(4)], []),
      ],
    )
  assert node.kind == "scrollable"
  assert node.id == "list"
  assert dict.get(node.props, "height") == Ok(FloatVal(400.0))
  assert dict.get(node.props, "width") == Ok(StringVal("fill"))
  let assert [col] = node.children
  assert col.kind == "column"
  assert col.id == "items"
}

pub fn layout_stack_test() {
  let node =
    ui.stack("layers", [], [
      ui.image("bg", "background.png", [image.Width(Fill), image.Height(Fill)]),
      ui.container(
        "overlay",
        [
          container.Width(Fill),
          container.Height(Fill),
          container.AlignX(Center),
          container.AlignY(Center),
        ],
        [ui.text("overlay_text", "Overlaid text", [text.Size(48.0)])],
      ),
    ])
  assert node.kind == "stack"
  assert node.id == "layers"
  let assert [bg, overlay] = node.children
  assert bg.kind == "image"
  assert dict.get(bg.props, "source") == Ok(StringVal("background.png"))
  assert overlay.kind == "container"
  let assert [text] = overlay.children
  assert dict.get(text.props, "content") == Ok(StringVal("Overlaid text"))
  assert dict.get(text.props, "size") == Ok(FloatVal(48.0))
}

pub fn layout_space_test() {
  let node =
    ui.row("spread", [], [
      ui.text_("left", "Left"),
      ui.space("gap", [space.Width(Fill)]),
      ui.text_("right", "Right"),
    ])
  assert node.kind == "row"
  let assert [left, gap, right] = node.children
  assert dict.get(left.props, "content") == Ok(StringVal("Left"))
  assert gap.kind == "space"
  assert dict.get(gap.props, "width") == Ok(StringVal("fill"))
  assert dict.get(right.props, "content") == Ok(StringVal("Right"))
}

pub fn layout_grid_test() {
  let node = ui.grid("gallery", [grid.Spacing(8)], [])
  assert node.kind == "grid"
  assert node.id == "gallery"
  assert dict.get(node.props, "spacing") == Ok(IntVal(8))
  assert node.children == []
}

// -- Common layout patterns ---------------------------------------------------

pub fn layout_centered_page_test() {
  let node =
    ui.container(
      "page",
      [
        container.Width(Fill),
        container.Height(Fill),
        container.AlignX(Center),
        container.AlignY(Center),
      ],
      [
        ui.column("content", [column.Spacing(16), column.AlignX(Center)], [
          ui.text("welcome", "Welcome", [text.Size(32.0)]),
          ui.button_("start", "Get Started"),
        ]),
      ],
    )
  assert node.kind == "container"
  assert dict.get(node.props, "align_x") == Ok(StringVal("center"))
  assert dict.get(node.props, "align_y") == Ok(StringVal("center"))
  let assert [col] = node.children
  assert dict.get(col.props, "align_x") == Ok(StringVal("center"))
  let assert [text, btn] = col.children
  assert dict.get(text.props, "content") == Ok(StringVal("Welcome"))
  assert dict.get(text.props, "size") == Ok(FloatVal(32.0))
  assert dict.get(btn.props, "label") == Ok(StringVal("Get Started"))
}
