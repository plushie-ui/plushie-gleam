import gleam/dict
import plushie/node.{FloatVal, IntVal, StringVal}
import plushie/prop/alignment.{Center}
import plushie/prop/length.{Fill, FillPortion, Fixed, Shrink}
import plushie/prop/padding.{Padding}
import plushie/ui

// -- Length examples ----------------------------------------------------------

pub fn layout_length_fill_test() {
  let node = ui.column("main", [ui.width(Fill)], [])
  assert node.kind == "column"
  assert dict.get(node.props, "width") == Ok(StringVal("fill"))
}

pub fn layout_length_fixed_test() {
  let node = ui.container("sidebar", [ui.width(Fixed(250.0))], [])
  assert node.kind == "container"
  assert dict.get(node.props, "width") == Ok(FloatVal(250.0))
}

pub fn layout_length_fill_portion_test() {
  let left = ui.container("left", [ui.width(FillPortion(2))], [])
  let right = ui.container("right", [ui.width(FillPortion(1))], [])
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
  let node = ui.button("save", "Save", [ui.width(Shrink)])
  assert node.kind == "button"
  assert dict.get(node.props, "width") == Ok(StringVal("shrink"))
}

// -- Padding examples ---------------------------------------------------------

pub fn layout_padding_all_test() {
  let node = ui.container("box", [ui.padding(padding.all(16.0))], [])
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
  let node = ui.container("box", [ui.padding(padding.xy(8.0, 16.0))], [])
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
        ui.padding(Padding(top: 0.0, right: 16.0, bottom: 8.0, left: 16.0)),
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
    ui.column("col", [ui.spacing(8)], [
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
    ui.column("col", [ui.align_x(Center)], [
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
        ui.width(Fill),
        ui.height(Fill),
        ui.align_x(Center),
        ui.align_y(Center),
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
        ui.spacing(16),
        ui.padding(padding.all(20.0)),
        ui.width(Fill),
        ui.align_x(Center),
      ],
      [
        ui.text("title", "Title", [ui.font_size(24.0)]),
        ui.text("subtitle", "Subtitle", [ui.font_size(14.0)]),
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
    ui.row("nav", [ui.spacing(8), ui.align_y(Center)], [
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
      [ui.padding(padding.all(16.0)), ui.style("rounded_box"), ui.width(Fill)],
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
    ui.scrollable("list", [ui.height(Fixed(400.0)), ui.width(Fill)], [
      ui.column("items", [ui.spacing(4)], []),
    ])
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
      ui.image("bg", "background.png", [ui.width(Fill), ui.height(Fill)]),
      ui.container(
        "overlay",
        [
          ui.width(Fill),
          ui.height(Fill),
          ui.align_x(Center),
          ui.align_y(Center),
        ],
        [ui.text("overlay_text", "Overlaid text", [ui.font_size(48.0)])],
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
      ui.space("gap", [ui.width(Fill)]),
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
  let node = ui.grid("gallery", [ui.spacing(8)], [])
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
        ui.width(Fill),
        ui.height(Fill),
        ui.align_x(Center),
        ui.align_y(Center),
      ],
      [
        ui.column("content", [ui.spacing(16), ui.align_x(Center)], [
          ui.text("welcome", "Welcome", [ui.font_size(32.0)]),
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
