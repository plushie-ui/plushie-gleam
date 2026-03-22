//// Notes app: route-based navigation, undo/redo, search, multi-select.
////
//// Demonstrates Route, UndoStack, Selection, and Data.query
//// working together with typed Gleam records.

import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/set
import gleam/string
import plushie
import plushie/app
import plushie/command
import plushie/data
import plushie/event.{type Event, WidgetClick, WidgetInput, WidgetToggle}
import plushie/node.{type Node}
import plushie/prop/length
import plushie/prop/padding
import plushie/route
import plushie/selection
import plushie/ui
import plushie/undo
import plushie/widget/text_editor

pub type Note {
  Note(id: Int, title: String, body: String)
}

pub type EditState {
  EditState(title: String, text: String)
}

pub type Model {
  Model(
    notes: List(Note),
    next_id: Int,
    search_query: String,
    editing_id: option.Option(Int),
    selection: selection.Selection,
    undo_stack: undo.UndoStack(EditState),
    nav: route.Route,
  )
}

fn init() {
  #(
    Model(
      notes: [],
      next_id: 1,
      search_query: "",
      editing_id: None,
      selection: selection.new(selection.Multi),
      undo_stack: undo.new(EditState(title: "", text: "")),
      nav: route.new("/list"),
    ),
    command.none(),
  )
}

fn update(model: Model, event: Event) {
  case event {
    // --- List view actions ---
    WidgetClick(id: "new_note", ..) -> {
      let id = model.next_id
      let note = Note(id:, title: "", body: "")
      let model =
        Model(
          ..model,
          notes: list.append(model.notes, [note]),
          next_id: id + 1,
          editing_id: Some(id),
          undo_stack: undo.new(EditState(title: "", text: "")),
          nav: route.push(model.nav, "/edit"),
        )
      #(model, command.none())
    }

    WidgetClick(id: "delete_selected", ..) -> {
      let sel = selection.selected(model.selection)
      let notes =
        list.filter(model.notes, fn(n) {
          !set.contains(sel, int.to_string(n.id))
        })
      #(
        Model(..model, notes:, selection: selection.clear(model.selection)),
        command.none(),
      )
    }

    WidgetInput(id: "search", value: query, ..) -> #(
      Model(..model, search_query: query),
      command.none(),
    )

    WidgetToggle(id: id, ..) -> {
      case string.split(id, ":") {
        ["note_select", id_str] -> #(
          Model(..model, selection: selection.toggle(model.selection, id_str)),
          command.none(),
        )
        _ -> #(model, command.none())
      }
    }

    WidgetClick(id: id, ..) -> {
      case string.split(id, ":") {
        ["note", id_str] -> {
          case int.parse(id_str) {
            Ok(note_id) -> {
              case list.find(model.notes, fn(n) { n.id == note_id }) {
                Ok(note) -> #(
                  Model(
                    ..model,
                    editing_id: Some(note_id),
                    undo_stack: undo.new(EditState(
                      title: note.title,
                      text: note.body,
                    )),
                    nav: route.push(model.nav, "/edit"),
                  ),
                  command.none(),
                )
                Error(_) -> #(model, command.none())
              }
            }
            Error(_) -> #(model, command.none())
          }
        }
        _ -> handle_edit_click(model, id)
      }
    }

    // --- Edit view actions ---
    WidgetInput(id: "title", value:, ..) -> {
      let old_title = undo.current(model.undo_stack).title
      let cmd =
        undo.UndoCommand(
          apply: fn(s) { EditState(..s, title: value) },
          undo: fn(s) { EditState(..s, title: old_title) },
          label: "edit title",
          coalesce_key: Some("title"),
          coalesce_window_ms: Some(500),
        )
      #(
        Model(..model, undo_stack: undo.apply(model.undo_stack, cmd)),
        command.none(),
      )
    }

    WidgetInput(id: "body", value:, ..) -> {
      let old_text = undo.current(model.undo_stack).text
      let cmd =
        undo.UndoCommand(
          apply: fn(s) { EditState(..s, text: value) },
          undo: fn(s) { EditState(..s, text: old_text) },
          label: "edit body",
          coalesce_key: Some("body"),
          coalesce_window_ms: Some(500),
        )
      #(
        Model(..model, undo_stack: undo.apply(model.undo_stack, cmd)),
        command.none(),
      )
    }

    _ -> #(model, command.none())
  }
}

fn handle_edit_click(model: Model, id: String) {
  case id {
    "back" -> {
      let model = save_current_edit(model)
      #(
        Model(..model, editing_id: None, nav: route.pop(model.nav)),
        command.none(),
      )
    }
    "undo" -> #(
      Model(..model, undo_stack: undo.undo(model.undo_stack)),
      command.none(),
    )
    "redo" -> #(
      Model(..model, undo_stack: undo.redo(model.undo_stack)),
      command.none(),
    )
    _ -> #(model, command.none())
  }
}

fn save_current_edit(model: Model) -> Model {
  case model.editing_id {
    None -> model
    Some(editing_id) -> {
      let current = undo.current(model.undo_stack)
      let notes =
        list.map(model.notes, fn(n) {
          case n.id == editing_id {
            True -> Note(..n, title: current.title, body: current.text)
            False -> n
          }
        })
      Model(..model, notes:)
    }
  }
}

fn view(model: Model) -> Node {
  case route.current(model.nav) {
    "/edit" -> view_edit(model)
    _ -> view_list(model)
  }
}

fn view_list(model: Model) -> Node {
  let filtered = case model.search_query {
    "" -> model.notes
    query -> {
      let result =
        data.query(model.notes, [
          data.Search(
            fields: [fn(n: Note) { n.title }, fn(n: Note) { n.body }],
            query:,
          ),
        ])
      result.entries
    }
  }

  ui.window("main", [ui.title("Notes")], [
    ui.column(
      "content",
      [ui.padding(padding.all(16.0)), ui.spacing(12), ui.width(length.Fill)],
      [
        ui.text("heading", "Notes", [ui.font_size(24.0)]),
        ui.text_input("search", model.search_query, [
          ui.placeholder("Search notes..."),
        ]),
        ui.scrollable("notes_list", [ui.height(length.Fill)], [
          ui.column(
            "notes_col",
            [ui.spacing(4), ui.width(length.Fill)],
            list.map(filtered, fn(note) {
              let id_str = int.to_string(note.id)
              let display_title = case note.title {
                "" -> "(untitled)"
                t -> t
              }
              ui.row(
                "note_row:" <> id_str,
                [ui.spacing(8), ui.width(length.Fill)],
                [
                  ui.checkbox(
                    "note_select:" <> id_str,
                    display_title,
                    selection.is_selected(model.selection, id_str),
                    [],
                  ),
                  ui.button_("note:" <> id_str, "Edit"),
                ],
              )
            }),
          ),
        ]),
        ui.row("actions", [ui.spacing(8)], [
          ui.button_("new_note", "New Note"),
          ui.button_("delete_selected", "Delete Selected"),
        ]),
      ],
    ),
  ])
}

fn view_edit(model: Model) -> Node {
  let current = undo.current(model.undo_stack)

  ui.window("main", [ui.title("Edit Note")], [
    ui.column(
      "content",
      [ui.padding(padding.all(16.0)), ui.spacing(12), ui.width(length.Fill)],
      [
        ui.row("toolbar", [ui.spacing(8)], [
          ui.button_("back", "Back"),
          ui.button_("undo", "Undo"),
          ui.button_("redo", "Redo"),
        ]),
        ui.text_input("title", current.title, [
          ui.placeholder("Note title"),
        ]),
        text_editor.new("body", current.text)
          |> text_editor.width(length.Fill)
          |> text_editor.height(length.Fill)
          |> text_editor.build(),
      ],
    ),
  ])
}

pub fn app() {
  app.simple(init, update, view)
}

pub fn main() {
  let _ = plushie.start(app(), plushie.default_start_opts())
  process.sleep_forever()
}
