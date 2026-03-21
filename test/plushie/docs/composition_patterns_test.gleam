import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/set.{type Set}
import gleam/string
import gleeunit/should
import plushie/command
import plushie/event.{type Event, WidgetClick}
import plushie/node.{type Node, StringVal}
import plushie/prop/alignment
import plushie/prop/length.{Fill, Fixed}
import plushie/prop/padding
import plushie/tree
import plushie/ui

// ============================================================================
// Tab bar (section 1)
// ============================================================================

type TabModel {
  TabModel(active_tab: String)
}

const tabs = ["overview", "details", "settings"]

fn tab_init() {
  #(TabModel(active_tab: "overview"), command.None)
}

fn tab_update(model: TabModel, event: Event) {
  case event {
    WidgetClick(id: "tab:" <> name, ..) -> #(
      TabModel(active_tab: name),
      command.None,
    )
    _ -> #(model, command.None)
  }
}

fn tab_view(model: TabModel) -> Node {
  ui.window("main", [ui.title("Tab Demo")], [
    ui.column("tabs_layout", [ui.width(Fill)], [
      ui.row(
        "tab_row",
        [ui.spacing(0)],
        list.map(tabs, fn(tab) {
          ui.button("tab:" <> tab, string.capitalise(tab), [
            ui.padding(padding.xy(10.0, 20.0)),
          ])
        }),
      ),
      ui.rule("tab_rule", []),
      ui.container(
        "content",
        [
          ui.padding(padding.all(20.0)),
          ui.width(Fill),
          ui.height(Fill),
        ],
        [ui.text_("tab_content", "Content for " <> model.active_tab)],
      ),
    ]),
  ])
}

pub fn tab_bar_init_test() {
  let #(model, _) = tab_init()
  should.equal(model.active_tab, "overview")
}

pub fn tab_bar_click_changes_active_tab_test() {
  let #(model, _) = tab_init()
  let #(model, _) =
    tab_update(model, WidgetClick(id: "tab:settings", scope: []))
  should.equal(model.active_tab, "settings")
}

pub fn tab_bar_view_has_three_tab_buttons_test() {
  let tree = tab_view(TabModel(active_tab: "overview"))
  let assert [column] = tree.children
  let assert [row, _rule, _content] = column.children
  should.equal(list.length(row.children), 3)
  let ids = list.map(row.children, fn(n) { n.id })
  should.equal(ids, ["tab:overview", "tab:details", "tab:settings"])
}

pub fn tab_bar_view_content_reflects_active_tab_test() {
  let tree = tab_view(TabModel(active_tab: "details"))
  let assert [column] = tree.children
  let assert [_, _, content] = column.children
  let assert [text_node] = content.children
  should.equal(
    dict.get(text_node.props, "content"),
    Ok(StringVal("Content for details")),
  )
}

// ============================================================================
// Sidebar navigation (section 2)
// ============================================================================

type SidebarModel {
  SidebarModel(page: String)
}

const nav_items = [
  #("inbox", "Inbox"),
  #("sent", "Sent"),
  #("drafts", "Drafts"),
]

fn sidebar_init() {
  #(SidebarModel(page: "inbox"), command.None)
}

fn sidebar_update(model: SidebarModel, event: Event) {
  case event {
    WidgetClick(id: "nav:" <> name, ..) -> #(
      SidebarModel(page: name),
      command.None,
    )
    _ -> #(model, command.None)
  }
}

fn sidebar_view(model: SidebarModel) -> Node {
  ui.window("main", [ui.title("Sidebar Demo")], [
    ui.row("layout", [ui.width(Fill), ui.height(Fill)], [
      ui.container("sidebar", [ui.width(Fixed(200.0)), ui.height(Fill)], [
        ui.column(
          "nav",
          [ui.spacing(4), ui.width(Fill)],
          list.map(nav_items, fn(item) {
            let #(id, label) = item
            ui.button("nav:" <> id, label, [ui.width(Fill)])
          }),
        ),
      ]),
      ui.container("main", [ui.width(Fill), ui.height(Fill)], [
        ui.text_("page_title", string.capitalise(model.page) <> " page"),
      ]),
    ]),
  ])
}

pub fn sidebar_init_test() {
  let #(model, _) = sidebar_init()
  should.equal(model.page, "inbox")
}

pub fn sidebar_click_changes_page_test() {
  let #(model, _) = sidebar_init()
  let #(model, _) =
    sidebar_update(model, WidgetClick(id: "nav:sent", scope: []))
  should.equal(model.page, "sent")
}

pub fn sidebar_view_has_nav_items_test() {
  let tree = sidebar_view(SidebarModel(page: "inbox"))
  let assert [row] = tree.children
  let assert [sidebar_container, main_container] = row.children
  should.equal(sidebar_container.id, "sidebar")
  should.equal(main_container.id, "main")

  let assert [nav_col] = sidebar_container.children
  should.equal(list.length(nav_col.children), 3)
}

pub fn sidebar_view_shows_page_title_test() {
  let tree = sidebar_view(SidebarModel(page: "drafts"))
  let assert [row] = tree.children
  let assert [_, main_container] = row.children
  let assert [title] = main_container.children
  should.equal(dict.get(title.props, "content"), Ok(StringVal("Drafts page")))
}

// ============================================================================
// Modal dialog (section 4)
// ============================================================================

type ModalModel {
  ModalModel(show_modal: Bool, confirmed: Bool)
}

fn modal_init() {
  #(ModalModel(show_modal: False, confirmed: False), command.None)
}

fn modal_update(model: ModalModel, event: Event) {
  case event {
    WidgetClick(id: "open_modal", ..) -> #(
      ModalModel(..model, show_modal: True),
      command.None,
    )
    WidgetClick(id: "confirm", ..) -> #(
      ModalModel(show_modal: False, confirmed: True),
      command.None,
    )
    WidgetClick(id: "cancel", ..) -> #(
      ModalModel(..model, show_modal: False),
      command.None,
    )
    _ -> #(model, command.None)
  }
}

fn modal_view(model: ModalModel) -> Node {
  let main_content =
    ui.container("main", [ui.width(Fill), ui.height(Fill)], [
      ui.column(
        "main_col",
        [ui.spacing(12)],
        list.flatten([
          [
            ui.text("main_content", "Main application content", [
              ui.font_size(20.0),
            ]),
          ],
          case model.confirmed {
            True -> [ui.text_("confirmed_msg", "Action confirmed.")]
            False -> []
          },
          [ui.button("open_modal", "Open Dialog", [ui.style("primary")])],
        ]),
      ),
    ])

  let modal_layer = case model.show_modal {
    True -> [
      ui.container(
        "overlay",
        [
          ui.width(Fill),
          ui.height(Fill),
          ui.align_x(alignment.Center),
          ui.align_y(alignment.Center),
        ],
        [
          ui.container("dialog", [ui.max_width(400.0)], [
            ui.column("dialog_col", [ui.spacing(16)], [
              ui.text_("dialog_title", "Confirm action"),
              ui.text_(
                "dialog_body",
                "Are you sure you want to proceed? This cannot be undone.",
              ),
              ui.row("dialog_actions", [ui.spacing(8)], [
                ui.button("cancel", "Cancel", [ui.style("secondary")]),
                ui.button("confirm", "Confirm", [ui.style("primary")]),
              ]),
            ]),
          ]),
        ],
      ),
    ]
    False -> []
  }

  ui.window("main", [ui.title("Modal Demo")], [
    ui.stack("modal_stack", [ui.width(Fill), ui.height(Fill)], [
      main_content,
      ..modal_layer
    ]),
  ])
}

pub fn modal_init_test() {
  let #(model, _) = modal_init()
  should.equal(model.show_modal, False)
  should.equal(model.confirmed, False)
}

pub fn modal_open_test() {
  let #(model, _) = modal_init()
  let #(model, _) =
    modal_update(model, WidgetClick(id: "open_modal", scope: []))
  should.equal(model.show_modal, True)
}

pub fn modal_confirm_test() {
  let model = ModalModel(show_modal: True, confirmed: False)
  let #(model, _) = modal_update(model, WidgetClick(id: "confirm", scope: []))
  should.equal(model.show_modal, False)
  should.equal(model.confirmed, True)
}

pub fn modal_cancel_test() {
  let model = ModalModel(show_modal: True, confirmed: False)
  let #(model, _) = modal_update(model, WidgetClick(id: "cancel", scope: []))
  should.equal(model.show_modal, False)
  should.equal(model.confirmed, False)
}

pub fn modal_view_no_overlay_when_closed_test() {
  let tree = modal_view(ModalModel(show_modal: False, confirmed: False))
  let assert [stack] = tree.children
  // Only the main_content child, no overlay
  should.equal(list.length(stack.children), 1)
}

pub fn modal_view_has_overlay_when_open_test() {
  let tree = modal_view(ModalModel(show_modal: True, confirmed: False))
  let assert [stack] = tree.children
  // main_content + overlay
  should.equal(list.length(stack.children), 2)

  let assert [_, overlay] = stack.children
  should.equal(overlay.id, "overlay")
  let assert [dialog] = overlay.children
  should.equal(dialog.id, "dialog")
}

pub fn modal_view_shows_confirmed_message_test() {
  let tree = modal_view(ModalModel(show_modal: False, confirmed: True))
  let assert [stack] = tree.children
  let assert [main] = stack.children
  let assert [main_col] = main.children
  // Should have: main_content text, confirmed_msg text, open button
  should.equal(list.length(main_col.children), 3)
  let assert [_, confirmed, _] = main_col.children
  should.equal(confirmed.id, "confirmed_msg")
}

// ============================================================================
// Card (section 5)
// ============================================================================

fn card(id: String, title: String, body: List(Node)) -> Node {
  ui.container(id, [ui.width(Fill)], [
    ui.column(
      id <> "_col",
      [ui.spacing(8)],
      list.flatten([
        [
          ui.text("card_title", title, [ui.font_size(16.0)]),
          ui.rule(id <> "_rule", []),
        ],
        body,
      ]),
    ),
  ])
}

pub fn card_helper_produces_correct_structure_test() {
  let node =
    card("info", "System status", [
      ui.text_("status_msg", "All services operational"),
    ])
  should.equal(node.kind, "container")
  should.equal(node.id, "info")

  let assert [col] = node.children
  should.equal(col.id, "info_col")
  should.equal(col.kind, "column")

  // title, rule, body text
  should.equal(list.length(col.children), 3)
  let assert [title, rule, body_text] = col.children
  should.equal(title.id, "card_title")
  should.equal(dict.get(title.props, "content"), Ok(StringVal("System status")))
  should.equal(rule.kind, "rule")
  should.equal(body_text.id, "status_msg")
}

// ============================================================================
// Split panel (section 6)
// ============================================================================

type SplitModel {
  SplitModel(left_width: Float)
}

fn split_view(model: SplitModel) -> Node {
  ui.window("main", [ui.title("Split Panel Demo")], [
    ui.row("split", [ui.width(Fill), ui.height(Fill)], [
      ui.container(
        "left_panel",
        [
          ui.width(Fixed(model.left_width)),
          ui.height(Fill),
        ],
        [ui.text_("left_title", "Left panel")],
      ),
      ui.mouse_area("divider", [], [
        ui.container("divider_track", [ui.width(Fixed(5.0)), ui.height(Fill)], [
          ui.rule("divider_rule", []),
        ]),
      ]),
      ui.container("right_panel", [ui.width(Fill), ui.height(Fill)], [
        ui.text_("right_title", "Right panel"),
      ]),
    ]),
  ])
}

pub fn split_panel_has_three_sections_test() {
  let tree = split_view(SplitModel(left_width: 300.0))
  let assert [row] = tree.children
  should.equal(list.length(row.children), 3)

  let assert [left, divider, right] = row.children
  should.equal(left.id, "left_panel")
  should.equal(divider.id, "divider")
  should.equal(divider.kind, "mouse_area")
  should.equal(right.id, "right_panel")
}

// ============================================================================
// Breadcrumb (section 7)
// ============================================================================

type BreadcrumbModel {
  BreadcrumbModel(path: List(String))
}

fn breadcrumb_update(model: BreadcrumbModel, event: Event) {
  case event {
    WidgetClick(id: "crumb:" <> index_str, ..) -> {
      let assert Ok(index) = int.parse(index_str)
      #(BreadcrumbModel(path: list.take(model.path, index + 1)), command.None)
    }
    _ -> #(model, command.None)
  }
}

pub fn breadcrumb_click_truncates_path_test() {
  let model = BreadcrumbModel(path: ["Home", "Projects", "Plushie", "Docs"])
  let #(model, _) =
    breadcrumb_update(model, WidgetClick(id: "crumb:1", scope: []))
  should.equal(model.path, ["Home", "Projects"])
}

pub fn breadcrumb_click_first_keeps_root_test() {
  let model = BreadcrumbModel(path: ["Home", "Projects", "Plushie"])
  let #(model, _) =
    breadcrumb_update(model, WidgetClick(id: "crumb:0", scope: []))
  should.equal(model.path, ["Home"])
}

// ============================================================================
// Badge / chip (section 8)
// ============================================================================

type ChipModel {
  ChipModel(selected: Set(String))
}

fn chip_update(model: ChipModel, event: Event) {
  case event {
    WidgetClick(id: "tag:" <> name, ..) -> {
      let selected = case set.contains(model.selected, name) {
        True -> set.delete(model.selected, name)
        False -> set.insert(model.selected, name)
      }
      #(ChipModel(selected:), command.None)
    }
    _ -> #(model, command.None)
  }
}

pub fn chip_toggle_on_test() {
  let model = ChipModel(selected: set.new())
  let #(model, _) = chip_update(model, WidgetClick(id: "tag:rust", scope: []))
  should.be_true(set.contains(model.selected, "rust"))
}

pub fn chip_toggle_off_test() {
  let model = ChipModel(selected: set.from_list(["rust"]))
  let #(model, _) = chip_update(model, WidgetClick(id: "tag:rust", scope: []))
  should.be_false(set.contains(model.selected, "rust"))
}

// ============================================================================
// State helpers: undo, selection, route, data (section at end)
// ============================================================================

import plushie/data
import plushie/route
import plushie/selection
import plushie/undo

// -- undo --

pub fn state_helper_undo_apply_and_revert_test() {
  let stack = undo.new(0)
  let stack =
    undo.apply(
      stack,
      undo.UndoCommand(
        apply: fn(n) { n + 10 },
        undo: fn(n) { n - 10 },
        label: "add 10",
        coalesce_key: None,
        coalesce_window_ms: None,
      ),
    )
  should.equal(undo.current(stack), 10)

  let stack = undo.undo(stack)
  should.equal(undo.current(stack), 0)

  let stack = undo.redo(stack)
  should.equal(undo.current(stack), 10)
}

// -- selection --

pub fn state_helper_selection_multi_test() {
  let sel = selection.new(selection.Multi)
  let sel = selection.select(sel, "item_1", False)
  let sel = selection.select(sel, "item_3", True)
  should.be_true(set.contains(selection.selected(sel), "item_1"))
  should.be_true(set.contains(selection.selected(sel), "item_3"))

  let sel = selection.toggle(sel, "item_1")
  should.be_false(set.contains(selection.selected(sel), "item_1"))
  should.be_true(set.contains(selection.selected(sel), "item_3"))
}

pub fn state_helper_selection_range_test() {
  let sel = selection.new_with_order(selection.Range, ["a", "b", "c", "d", "e"])
  let sel = selection.select(sel, "b", False)
  let sel = selection.range_select(sel, "d")
  let selected = selection.selected(sel)
  should.be_true(set.contains(selected, "b"))
  should.be_true(set.contains(selected, "c"))
  should.be_true(set.contains(selected, "d"))
  should.be_false(set.contains(selected, "a"))
  should.be_false(set.contains(selected, "e"))
}

// -- route --

pub fn state_helper_route_push_and_pop_test() {
  let r = route.new("/dashboard")
  let r =
    route.push_with_params(
      r,
      "/settings",
      dict.from_list([#("tab", "general")]),
    )
  should.equal(route.current(r), "/settings")
  should.equal(route.params(r), dict.from_list([#("tab", "general")]))

  let r = route.pop(r)
  should.equal(route.current(r), "/dashboard")
}

// -- data --

type User {
  User(name: String, active: Bool)
}

pub fn state_helper_data_query_filter_test() {
  let records = [
    User(name: "Alice", active: True),
    User(name: "Bob", active: False),
    User(name: "Carol", active: True),
  ]
  let result = data.query(records, [data.Filter(fn(r: User) { r.active })])
  should.equal(result.total, 2)
  let names = list.map(result.entries, fn(r: User) { r.name })
  should.equal(names, ["Alice", "Carol"])
}

// ============================================================================
// Tree find helpers
// ============================================================================

pub fn tree_find_in_composed_widget_test() {
  let tree =
    ui.window("main", [], [
      ui.column("col", [], [
        ui.button_("save", "Save"),
        ui.text_("status", "Ready"),
      ]),
    ])
  let normalized = tree.normalize(tree)
  should.be_true(tree.exists(normalized, "save"))
  should.be_true(tree.exists(normalized, "status"))
  should.equal(option.is_some(tree.find(normalized, "save")), True)
}
