# Lists and Inputs

The pad so far edits a single experiment held in memory. In this chapter we
add file management: save experiments as `.erl` files, list them in a
sidebar, create new ones, switch between them, and delete the ones you
don't want anymore.

Along the way we cover `text_input`, `checkbox`, dynamic lists with
`list.map` and `keyed_column`, and the scoped-ID pattern that lets events
from a row recover which row they came from.

## Saving experiments to files

Experiments are plain Erlang source files stored in `experiments/`, a
directory outside the compilation path. Each file is a module exporting a
`view/0` function. The file I/O is standard stdlib; there is nothing
Plushie-specific about it:

```gleam
import gleam/list
import gleam/string
import simplifile

const experiments_dir = "experiments"

pub fn list() -> List(String) {
  case simplifile.read_directory(experiments_dir) {
    Ok(names) ->
      names
      |> list.filter(fn(name) { string.ends_with(name, ".erl") })
      |> list.sort(string.compare)
    Error(_) -> []
  }
}

pub fn load(name: String) -> String {
  case simplifile.read(experiments_dir <> "/" <> name) {
    Ok(s) -> s
    Error(_) -> ""
  }
}

pub fn save(name: String, source: String) -> Nil {
  let _ = simplifile.create_directory_all(experiments_dir)
  let _ = simplifile.write(experiments_dir <> "/" <> name, source)
  Nil
}

pub fn delete(name: String) -> Nil {
  let _ = simplifile.delete(experiments_dir <> "/" <> name)
  Nil
}
```

We call these from `update` when the user interacts with the file
management UI.

## Extending the model

The model needs new fields for the file list, the active file, the
new-experiment name input, and the auto-save flag:

```gleam
pub type Model {
  Model(
    source: String,
    preview: Option(Node),
    error: Option(String),
    event_log: List(String),
    files: List(String),
    active_file: Option(String),
    new_name: String,
    auto_save: Bool,
  )
}
```

In `init`, load the file list. If any files exist, load the first one;
otherwise seed the editor with a starter template:

```gleam
fn init() -> #(Model, Command(Event)) {
  let files = experiments.list()
  let #(source, active) = case files {
    [first, ..] -> #(experiments.load(first), Some(first))
    [] -> #(starter_source("hello"), None)
  }
  let model =
    Model(
      source: source,
      preview: None,
      error: None,
      event_log: [],
      files: files,
      active_file: active,
      new_name: "",
      auto_save: False,
    )
  #(model, command.none())
}
```

## Dynamic lists with list.map

To render one row per file, map the list into a list of nodes. Gleam's
`list.map` is the direct equivalent of a comprehension in other languages:

```gleam
import gleam/list
import plushie/ui
import plushie/widget/column

ui.column(
  "files",
  [column.Spacing(4.0)],
  list.map(model.files, fn(file) { ui.button_(file, file) }),
)
```

This works but has a subtle problem. When you add or remove a file, the
default `column` matches children to their previous state by position.
Adding a file at the top of the list shifts every other child down one
slot. The second file inherits the first file's widget state (focus,
scroll position, cursor) because it now sits in the first file's old
position.

`keyed_column` solves this by matching children by ID instead of position.
Items keep their state no matter where they move:

```gleam
import plushie/widget/keyed_column

ui.keyed_column(
  "files",
  [keyed_column.Spacing(4.0)],
  list.map(model.files, fn(file) { ui.button_(file, file) }),
)
```

Use `keyed_column` for any list that changes at runtime. Use `column` for
static layouts where the children are fixed.

## Scoped IDs

Each file in the sidebar needs its own controls, at least a delete button.
If every delete button has `id: "delete"`, how does `update` know which
file to delete?

Named containers solve this. Wrapping each row in a `ui.container` whose
ID is the filename puts the filename on the scope chain. Events from
widgets inside that container carry the scope:

```gleam
ui.container("hello.erl", [], [
  ui.button_("delete", "x"),
])
```

When the delete button fires, the event's `EventTarget` looks like:

```gleam
EventTarget(
  window_id: "main",
  id: "delete",
  scope: ["hello.erl", "main"],
  full: "main#hello.erl/delete",
)
```

The `scope` list is the ancestor chain, nearest parent first, with the
window ID at the tail. Pattern-match on the head to bind the filename:

```gleam
Widget(Click(target: EventTarget(id: "delete", scope: [file, ..], ..))) ->
  delete_file(model, file)
```

This works regardless of nesting depth. Any named container between the
button and the root adds its ID to the scope chain. For the full scoping
rules, see the [Scoped IDs reference](../reference/scoped-ids.md).

## The file list sidebar

Here is the sidebar view. A fixed-width `container` holds a scrollable
list of file rows:

```gleam
import plushie/prop/length.{Fill, Fixed}
import plushie/prop/padding
import plushie/widget/container
import plushie/widget/scrollable

fn sidebar(model: Model) -> Node {
  ui.container(
    "sidebar-wrap",
    [container.Width(Fixed(200.0)), container.Height(Fill)],
    [
      ui.scrollable("sidebar", [scrollable.Height(Fill)], [
        ui.keyed_column(
          "files",
          [keyed_column.Spacing(4.0), keyed_column.Padding(padding.all(8.0))],
          list.map(model.files, fn(file) { file_row(model, file) }),
        ),
      ]),
    ],
  )
}

fn file_row(model: Model, file: String) -> Node {
  let is_active = model.active_file == Some(file)
  ui.container(file, [container.Padding(padding.all(4.0))], [
    ui.row("row", [row.Spacing(4.0)], [
      ui.button("select", file, case is_active {
        True -> [button.Style(button.Primary)]
        False -> [button.Style(button.Subtle)]
      }),
      ui.button("delete", "x", [button.Style(button.Danger)]),
    ]),
  ])
}
```

Each `file_row` wraps its controls in a `ui.container` whose ID is the
filename. Inside, a select button highlights the active file and a delete
button fires with the filename on its scope.

## Text input

`text_input` is a single-line editable field. It takes an ID, the current
value (from the model), and an opts list:

```gleam
import plushie/widget/text_input

ui.text_input("new-name", model.new_name, [
  text_input.Placeholder("new_name.erl"),
  text_input.OnSubmit(True),
])
```

- `Placeholder(String)` shows grey hint text when the input is empty.
- `OnSubmit(True)` enables the `Submit` event when the user presses
  Enter. Without it, only `Input` events (one per keystroke) are emitted.

The `Input` event carries the current text as `value` on every keystroke:

```gleam
Widget(Input(target: EventTarget(id: "new-name", ..), value: text)) ->
  #(Model(..model, new_name: text), command.none())
```

The `Submit` event fires when Enter is pressed, provided `OnSubmit(True)`
is set:

```gleam
Widget(Submit(target: EventTarget(id: "new-name", ..), ..)) ->
  #(create_new(model), command.none())
```

## Checkbox: the auto-save toggle

`checkbox` is a boolean toggle. It takes an ID, a label, the current
state, and opts:

```gleam
ui.checkbox("auto-save", "Auto-save", model.auto_save, [])
```

The toggle fires as `Widget(Toggle(..))` with the new boolean state:

```gleam
Widget(Toggle(target: EventTarget(id: "auto-save", ..), value: on)) ->
  #(Model(..model, auto_save: on), command.none())
```

For now the flag is only stored in the model. We wire it to a debounced
save in [chapter 10](10-subscriptions.md) when we cover subscriptions.

## Focusing a widget after creating one

`update` returns `#(model, command)`. When the user creates a new
experiment and submits its name, we want focus to jump to the editor so
they can start typing immediately. `command.focus` does that:

```gleam
import plushie/command

fn create_new(model: Model) -> #(Model, Command(Event)) {
  case string.trim(model.new_name) {
    "" -> #(model, command.none())
    raw -> {
      let name = case string.ends_with(raw, ".erl") {
        True -> raw
        False -> raw <> ".erl"
      }
      let source = starter_source(module_name_of(name))
      experiments.save(name, source)
      let model =
        Model(
          ..model,
          files: experiments.list(),
          active_file: Some(name),
          source: source,
          new_name: "",
        )
      #(model, command.focus("editor"))
    }
  }
}
```

`command.focus` takes a widget path. A bare ID matches any widget with
that local ID; a scoped path like `"sidebar/new-name"` targets a specific
widget. See the [Commands reference](../reference/commands.md) for the
full command surface.

## Wiring file switching and deletion

Two more clauses handle the select and delete buttons in each file row.
Both extract the filename from the scope chain:

```gleam
Widget(Click(target: EventTarget(id: "select", scope: [file, ..], ..))) ->
  #(switch_file(model, file), command.none())

Widget(Click(target: EventTarget(id: "delete", scope: [file, ..], ..))) ->
  #(delete_file(model, file), command.none())
```

`switch_file` saves the current buffer before loading the new one, so
unsaved edits are not lost:

```gleam
fn switch_file(model: Model, file: String) -> Model {
  case model.active_file {
    Some(prev) -> experiments.save(prev, model.source)
    None -> Nil
  }
  let source = experiments.load(file)
  Model(..model, active_file: Some(file), source: source)
}
```

`delete_file` removes the file, refreshes the list, and picks a new
active file if the deleted one was selected:

```gleam
fn delete_file(model: Model, file: String) -> Model {
  experiments.delete(file)
  let files = experiments.list()
  case model.active_file == Some(file), files {
    True, [first, ..] -> switch_file(Model(..model, files: files), first)
    True, [] ->
      Model(
        ..model,
        files: [],
        active_file: None,
        source: starter_source("hello"),
      )
    False, _ -> Model(..model, files: files)
  }
}
```

Notice that both handlers treat `file` as an ordinary string variable
bound from the pattern. Scope matching is just pattern binding: the head
of the scope list is the nearest named ancestor.

## Updating the view

The root view now wraps the sidebar, editor, and preview in a horizontal
`row`, with a toolbar underneath:

```gleam
fn view(model: Model) -> List(Node) {
  [
    ui.window("main", [window.Title("Plushie Pad")], [
      ui.column("root", [column.Width(Fill), column.Height(Fill)], [
        ui.row("main-row", [row.Width(Fill), row.Height(Fill)], [
          sidebar(model),
          editor_pane(model),
          preview_pane(model),
        ]),
        toolbar(model),
        event_log_pane(model),
      ]),
    ]),
  ]
}

fn toolbar(model: Model) -> Node {
  ui.row("toolbar", [row.Padding(padding.xy(4.0, 8.0)), row.Spacing(8.0)], [
    ui.button_("save", "Save"),
    ui.checkbox("auto-save", "Auto-save", model.auto_save, []),
    ui.text_input("new-name", model.new_name, [
      text_input.Placeholder("new_name.erl"),
      text_input.OnSubmit(True),
    ]),
  ])
}
```

The sidebar has a fixed 200-pixel width. The editor and preview share the
rest of the row equally via `FillPortion(2)` each. We tidy the layout in
[chapter 7](07-layout.md).

## Pattern-matching one row per item

The scoped-ID pattern generalizes to any list where items have their own
controls: a todo list with a done checkbox per task, a settings screen
with per-entry delete buttons, a playlist with skip and favorite buttons.
Wrap each row in a `ui.container` keyed by the item's stable ID, then
bind the ID from the scope chain in `update`:

```gleam
ui.keyed_column(
  "tasks",
  [],
  list.map(model.tasks, fn(task) {
    ui.container(task.id, [], [
      ui.row("row", [], [
        ui.checkbox("done", task.title, task.done, []),
        ui.button_("delete", "x"),
      ]),
    ])
  }),
)
```

In `update`:

```gleam
case event {
  Widget(Toggle(
    target: EventTarget(id: "done", scope: [task_id, ..], ..),
    value: done,
  )) -> #(toggle_task(model, task_id, done), command.none())

  Widget(Click(target: EventTarget(id: "delete", scope: [task_id, ..], ..))) ->
    #(delete_task(model, task_id), command.none())

  _ -> #(model, command.none())
}
```

Keyed lists plus scoped IDs cover the vast majority of dynamic UI. The
types stay flat, the update clauses stay readable, and items keep their
renderer-side state even when the list reorders.

## Other input widgets

`pick_list` and `combo_box` are the other input widgets you reach for
regularly. Both live in the same `plushie/widget/*` layout and surface as
convenience functions on `plushie/ui`.

`pick_list` is a dropdown with a fixed list of string options:

```gleam
import plushie/widget/pick_list

ui.pick_list(
  "theme",
  ["Light", "Dark", "Solarized"],
  model.theme,
  [pick_list.Placeholder("Pick a theme")],
)
```

The selection arrives as `Widget(Select(..))` with the chosen string as
`value`:

```gleam
Widget(Select(target: EventTarget(id: "theme", ..), value: choice)) ->
  #(Model(..model, theme: Some(choice)), command.none())
```

`combo_box` is a text input with a filtered suggestion dropdown, useful
for free-text fields with a known set of common values:

```gleam
import plushie/widget/combo_box

ui.combo_box(
  "language",
  ["Gleam", "Elixir", "Erlang", "Rust"],
  model.language,
  [combo_box.Placeholder("Language")],
)
```

It emits `Input` on every keystroke (current text), `Select` when the
user picks a suggestion, and `Open` / `Close` as the dropdown toggles.

`slider` picks a float from a range:

```gleam
import plushie/widget/slider

ui.slider("volume", #(0.0, 1.0), model.volume, [slider.Step(0.01)])
```

`Slide` fires during the drag; `SlideRelease` fires on release. Use
`SlideRelease` if you only care about the final value, `Slide` for live
previews.

See the [Built-in Widgets reference](../reference/built-in-widgets.md)
for the full catalog and prop tables.

## Verify it

Exercise the create-and-switch flow with the testing helpers:

```gleam
import plushie/testing

pub fn create_experiment_test() {
  let ctx = testing.start(app.app(), [])

  testing.type_text(ctx, "new-name", "test.erl")
  testing.submit(ctx, "new-name")

  testing.assert_exists(ctx, "test.erl/select")

  testing.click(ctx, "hello.erl/select")
  testing.assert_text(ctx, "preview/greeting", "Hello, Plushie!")

  testing.stop(ctx)
}
```

This exercises scoped IDs, text submission, dynamic list rendering, and
file switching end to end. We cover the testing API fully in
[chapter 15](15-testing.md).

## Try it

With the updated pad running:

- Create a few experiments with different names. Each one gets a starter
  template and shows up in the sidebar.
- Switch between them. The editor swaps content and the preview updates.
- Delete an experiment. The sidebar updates and the next file loads
  automatically.
- Write a gallery experiment with its own widgets. Switch away and back.
  Your content is preserved because we save on switch.
- Toggle the auto-save checkbox. The model flips but nothing saves yet.
  We wire the timer up in [chapter 10](10-subscriptions.md).

The pad now manages a library of experiments. Each one is a plain `.erl`
file under `experiments/` that you can also open in any editor. Next we
improve the layout so the panes are sized and spaced consistently.

---

Next: [Layout](07-layout.md)
