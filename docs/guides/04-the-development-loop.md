# The Development Loop

The pad has a layout but the preview does not work yet. In this
chapter we bring it to life with two complementary techniques:
**hot reload** for editing the pad's own source code, and
**runtime compilation** for compiling widget code typed into the
pad's editor.

Along the way we will learn how to inspect a running app, a useful
debugging skill.

## Hot reload

Chapter 2 introduced `dev: True` on `GuiOpts` and the `file_system`
dependency it requires. Bake `dev: True` into the pad's entry point
so every `gleam run` during development watches `src/` and reloads
on save:

```gleam
import plushie/gui
import plushie_pad/app as pad_app

pub fn main() {
  gui.run(pad_app.app(), gui.GuiOpts(..gui.default_opts(), dev: True))
}
```

Start the pad with `gleam run -m plushie_pad`, edit any `.gleam`
file under `src/`, save, and the running app recompiles in place.
The model is preserved, so the text you typed in the editor stays.

Hot reload works because the runtime re-runs `view(model)` after
the dev server hot-loads the changed BEAM modules. The new view
produces a new tree, the runtime diffs it against the old one,
and only the changed patches go over the wire.

See the [App Lifecycle reference](../reference/app-lifecycle.md)
for the full startup sequence.

## Making the preview work

The editor holds an experiment. We want to compile it at runtime
and render the result in the preview pane. For the pad we compile
**Erlang** source, not Gleam: Gleam's compiler is a separate Rust
binary, while the BEAM ships a runtime Erlang compiler we can call
directly from a loaded app. Experiments are small modules exporting
`view/0`, so Erlang fits.

Three steps, each a standard-library call:

1. **Tokenise** the source with `erl_scan:string/1`.
2. **Parse** each form with `erl_parse:parse_form/1`.
3. **Compile** the parsed forms with `compile:forms/2`, load the
   resulting `.beam` with `code:load_binary/3`, and call
   `Module:view/0` to get the widget tree.

Create `src/plushie_pad_compile_ffi.erl`:

```erlang
%% @doc Runtime Erlang compilation for Plushie Pad experiments.
%%
%% Takes source text, parses it, compiles it, loads the module, and
%% invokes the module's `view/0' function. Errors at any stage are
%% returned as `{error, Reason}' tuples so the Gleam side can render
%% them as text in the preview pane.

-module(plushie_pad_compile_ffi).

-export([compile_and_render/1]).

%% Compile the given Erlang source text and call the resulting
%% module's view/0 function. Returns {ok, Node} on success or
%% {error, Message} on any failure (parse, compile, load, missing
%% export, runtime error).
compile_and_render(Source) when is_binary(Source) ->
    SourceStr = binary_to_list(Source),
    case erl_scan:string(SourceStr) of
        {ok, Tokens, _End} ->
            compile_tokens(Tokens);
        {error, {_Line, erl_scan, Reason}, _} ->
            {error, format_error(scan, Reason)}
    end.

compile_tokens(Tokens) ->
    Forms = split_forms(Tokens, [], []),
    case parse_forms(Forms, []) of
        {ok, Parsed} ->
            compile_forms(Parsed);
        {error, Message} ->
            {error, Message}
    end.

%% Split a flat token list into a list of per-form token lists,
%% splitting on dot tokens.
split_forms([], [], Acc) ->
    lists:reverse(Acc);
split_forms([], Current, Acc) ->
    lists:reverse([lists:reverse(Current) | Acc]);
split_forms([{dot, _} = Dot | Rest], Current, Acc) ->
    Form = lists:reverse([Dot | Current]),
    split_forms(Rest, [], [Form | Acc]);
split_forms([Tok | Rest], Current, Acc) ->
    split_forms(Rest, [Tok | Current], Acc).

parse_forms([], Acc) ->
    {ok, lists:reverse(Acc)};
parse_forms([Form | Rest], Acc) ->
    case erl_parse:parse_form(Form) of
        {ok, Parsed} ->
            parse_forms(Rest, [Parsed | Acc]);
        {error, {_Line, erl_parse, Reason}} ->
            {error, format_error(parse, Reason)}
    end.

compile_forms(Forms) ->
    case compile:forms(Forms, [return_errors]) of
        {ok, Module, Binary} ->
            load_and_render(Module, Binary);
        {ok, Module, Binary, _Warnings} ->
            load_and_render(Module, Binary);
        {error, Errors, _Warnings} ->
            {error, format_compile_errors(Errors)};
        error ->
            {error, <<"compile error">>}
    end.

load_and_render(Module, Binary) ->
    %% Allow re-defining the module each save cycle.
    code:purge(Module),
    case code:load_binary(Module, atom_to_list(Module) ++ ".erl", Binary) of
        {module, Module} ->
            case erlang:function_exported(Module, view, 0) of
                true ->
                    safe_call_view(Module);
                false ->
                    {error, <<"module must export view/0">>}
            end;
        {error, What} ->
            {error, format_error(load, What)}
    end.

safe_call_view(Module) ->
    try Module:view() of
        Node ->
            {ok, Node}
    catch
        Class:Reason:_Stack ->
            Text = io_lib:format("~p: ~p", [Class, Reason]),
            {error, iolist_to_binary(Text)}
    end.

format_error(Stage, Reason) ->
    Text = io_lib:format("~p: ~p", [Stage, Reason]),
    iolist_to_binary(Text).

format_compile_errors(Errors) ->
    Text =
        lists:map(
            fun({_File, Reasons}) ->
                lists:map(
                    fun({Line, Module, Desc}) ->
                        io_lib:format("line ~p: ~s~n", [
                            Line, Module:format_error(Desc)
                        ])
                    end,
                    Reasons
                )
            end,
            Errors
        ),
    iolist_to_binary(Text).
```

Every failure mode (bad syntax, unknown function, runtime error,
missing `view/0`) collapses to `{error, Message}`. The pad displays
the message in the preview pane and never crashes.

`code:purge/1` before `code:load_binary/3` matters: without it,
repeatedly saving the same module leaks the old code version into
BEAM's "old code" slot and the next save fails with
`code_replaced`. Purging clears the slot.

Wrap the FFI behind a Gleam module so the pad can call it without
`@external` at the call site. Create
`src/plushie_pad/compile.gleam`:

```gleam
//// Wrapper around the runtime Erlang compilation FFI.
////
//// The pad compiles user-typed Erlang source each time the user saves
//// and renders the resulting widget tree into the preview pane. This
//// module narrows the FFI boundary to a single `compile_and_render`
//// call returning `Result(Node, String)`.

import plushie/node.{type Node}

@external(erlang, "plushie_pad_compile_ffi", "compile_and_render")
pub fn compile_and_render(source: String) -> Result(Node, String)
```

The Erlang return shape (`{ok, Node}` or `{error, Message}`)
matches Gleam's `Result` encoding exactly (see the
[Erlang Interop reference](../reference/erlang-interop.md)), so no
translation is needed.

## A helper module for experiments

The SDK's Erlang surface is usable but noisy. A raw experiment
looks like this:

```erlang
view() ->
    'plushie@ui':column(<<"root">>,
        [{padding, 'plushie@prop@padding':all(16.0)}, {spacing, 8.0}],
        [
            'plushie@ui':text_(<<"title">>, <<"Hello">>),
            'plushie@ui':button_(<<"btn">>, <<"Click">>)
        ]).
```

Every `@`-prefixed module name is a reminder that the caller is
reaching across the language boundary. Add `src/pad_helpers.erl`
to hide the noise:

```erlang
%% @doc Ergonomic Erlang-side wrappers around the Gleam SDK's widget builders.
%%
%% Plushie Pad experiments are Erlang modules compiled at runtime. The
%% raw plushie@ui and plushie@widget@* call sites are unergonomic
%% (`'plushie@widget@button':new(Id, Label)' and so on), so this helper
%% module exposes friendlier names. It is the recommended shape for
%% any Erlang-side code talking to Plushie; see the erlang-interop
%% reference for the underlying mapping.

-module(pad_helpers).

-export([
    %% Leaf widgets
    text/2, text_size/3,
    button/2,
    %% Container widgets
    column/3, row/3, container/3,
    %% Padding helpers
    padding_all/1, padding_xy/2
]).

%% --- Leaf widgets ----------------------------------------------------------

text(Id, Content) ->
    'plushie@ui':text_(Id, Content).

text_size(Id, Content, Size) ->
    'plushie@ui':text(Id, Content, [{size, Size}]).

button(Id, Label) ->
    'plushie@ui':button_(Id, Label).

%% --- Container widgets -----------------------------------------------------

column(Id, Opts, Children) ->
    'plushie@ui':column(Id, Opts, Children).

row(Id, Opts, Children) ->
    'plushie@ui':row(Id, Opts, Children).

container(Id, Opts, Children) ->
    'plushie@ui':container(Id, Opts, Children).

%% --- Padding helpers -------------------------------------------------------

padding_all(N) ->
    'plushie@prop@padding':all(N).

padding_xy(V, H) ->
    'plushie@prop@padding':xy(V, H).
```

With the helpers in place the experiment reads almost like Gleam:

```erlang
view() ->
    pad_helpers:column(<<"root">>,
        [{padding, pad_helpers:padding_all(16.0)}, {spacing, 8.0}],
        [
            pad_helpers:text(<<"title">>, <<"Hello">>),
            pad_helpers:button(<<"btn">>, <<"Click">>)
        ]).
```

This pattern applies to any Erlang-side code talking to Plushie,
not just the pad. The
[Erlang Interop reference](../reference/erlang-interop.md) walks
through the full mapping with event accessors and command
shortcuts.

## Wiring up the save button

`compile_and_render/1` returns a `Result(Node, String)`. Store
both outcomes on the model: a successful tree in `preview`, a
failure message in `error`. Display whichever one is set.

In `src/plushie_pad/app.gleam`, extend the model with those fields
and a starting source string:

```gleam
pub type Model {
  Model(source: String, preview: Option(Node), error: Option(String))
}

const starter = "-module(hello).
-export([view/0]).

view() ->
    pad_helpers:column(<<\"root\">>,
        [{padding, pad_helpers:padding_all(16.0)}, {spacing, 8.0}],
        [
            pad_helpers:text_size(<<\"title\">>, <<\"Hello, Plushie!\">>, 20.0),
            pad_helpers:button(<<\"btn\">>, <<\"Click me\">>)
        ]).
"
```

Compile the starter on init so the preview pane is populated
before the user clicks anything:

```gleam
import plushie_pad/compile

fn init() -> #(Model, Command(Event)) {
  let #(preview, error) = case compile.compile_and_render(starter) {
    Ok(tree) -> #(Some(tree), None)
    Error(msg) -> #(None, Some(msg))
  }
  #(Model(source: starter, preview: preview, error: error), command.none())
}
```

Add two `update` arms: one for editor input (update `source`),
one for the save button (recompile):

```gleam
import plushie/event.{
  type Event, Click, EventTarget, Input, Widget,
}

fn update(model: Model, event: Event) -> #(Model, Command(Event)) {
  case event {
    Widget(Input(target: EventTarget(id: "editor", ..), value: source)) -> #(
      Model(..model, source: source),
      command.none(),
    )

    Widget(Click(target: EventTarget(id: "save", ..))) -> {
      let model = case compile.compile_and_render(model.source) {
        Ok(tree) -> Model(..model, preview: Some(tree), error: None)
        Error(msg) -> Model(..model, preview: None, error: Some(msg))
      }
      #(model, command.none())
    }

    _ -> #(model, command.none())
  }
}
```

Render whichever of `preview` or `error` is currently set in the
preview pane. A minimal view:

```gleam
fn preview_pane(model: Model) -> Node {
  let content = case model.error, model.preview {
    Some(msg), _ -> ui.text_("error", msg)
    None, Some(tree) -> tree
    None, None -> ui.text_("placeholder", "Press Save to compile")
  }
  ui.container(
    "preview",
    [container.Width(FillPortion(2)), container.Height(Fill)],
    [content],
  )
}
```

Type experiment code in the editor, click Save, and the preview
updates. Break the syntax and the red error text replaces the
preview. Fix it, save again, and the tree comes back.

See the [Events reference](../reference/events.md) for the event
taxonomy, particularly the `Widget(Click)` and `Widget(Input)`
shapes that the save and editor handlers match on.

## The experiment format

An experiment is an Erlang module exporting `view/0`:

```erlang
-module(hello).
-export([view/0]).

view() ->
    pad_helpers:column(<<"root">>,
        [{padding, pad_helpers:padding_all(16.0)}, {spacing, 8.0}],
        [
            pad_helpers:text_size(<<"title">>, <<"Hello, Plushie!">>, 20.0),
            pad_helpers:button(<<"btn">>, <<"Click me">>)
        ]).
```

The module name is free-form. `pad_helpers` handles the widget
calls; see the helper source above for the exported surface.
Experiments are pure: no state, no `update`, just a `view/0` that
builds a widget tree. The preview pane embeds the returned node
directly under `container "preview"`, which scopes every child ID
under `preview/` (see the
[Scoped IDs reference](../reference/scoped-ids.md)).

## Inspecting a running app

When a view misbehaves you want to see the model and the tree the
renderer is working against. Plushie exposes synchronous queries
on the running `Instance(model)`:

| Query | Returns |
|---|---|
| `plushie.get_model(instance)` | Current typed model |
| `plushie.get_tree(instance)` | Current normalised view tree |
| `plushie.get_focused(instance)` | ID of the focused widget |
| `plushie.get_health(instance)` | Error counters for `update` and `view` |

`Instance(model)` is parameterised over the app's model type, so
`get_model` returns the typed model directly. No `Dynamic`
coercion at the call site, no `dynamic.decode` gymnastics.

The simplest way to use these is a short-lived helper called from
inside `update` or a debug button:

```gleam
import gleam/io
import gleam/result
import gleam/string

fn debug_dump(instance) -> Nil {
  let _ = {
    use model <- result.try(plushie.get_model(instance))
    use tree <- result.try(plushie.get_tree(instance))
    io.println("model: " <> string.inspect(model))
    io.println("tree:  " <> string.inspect(tree))
    Ok(Nil)
  }
  Nil
}
```

Because the model type is baked into the instance,
`string.inspect` prints the real record shape (field names, typed
values), not a generic tuple.

For interactive poking, attach an Erlang shell to the running
BEAM (`erl -sname probe -remsh plushie_pad@localhost`) and call
`plushie:get_model/1` and `plushie:get_tree/1` directly against
the instance.

See the [App Lifecycle reference](../reference/app-lifecycle.md)
for the complete list of runtime queries, including
`is_view_desynced` and `get_prop_warnings`.

## Try it

With the pad running and hot reload on:

- Break an experiment deliberately: remove a closing `)`, save,
  and read the error message in the preview. Fix it and save
  again.
- Extend `pad_helpers` with another widget. Add a `slider/3` that
  calls `'plushie@ui':slider/3`, then use it from an experiment.
- Add a `dump` button to the pad that writes `get_model` and
  `get_tree` output to stderr via `io.println_error`.
- Change the pad's own `view` (font size, border colour, toolbar
  layout) while the pad is running. Watch the window update
  without losing the editor contents.

In the next chapter we log every event the preview produces into
a panel at the bottom of the pad, so you can watch exactly what a
widget emits when you interact with it.

---

Next: [Events](05-events.md)
