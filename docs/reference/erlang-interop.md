# Erlang Interop

The Gleam SDK compiles to BEAM modules that Erlang code can call
directly. This page covers the mapping from Gleam to Erlang, how
to use Plushie from an Erlang codebase, and the caveats that come
with crossing the language boundary.

Two audiences benefit from this page:

- **Gleam users who write FFI modules.** Gleam's standard escape
  hatch for unsafe or ecosystem code is a `.erl` file alongside
  the `.gleam` module, with `@external(erlang, ...)` annotations
  connecting them. Understanding the BEAM compilation scheme
  makes those FFIs easier to write.
- **Erlang-first users who want Plushie.** The Gleam SDK is, by
  way of its BEAM compile output, a perfectly usable Erlang
  binding for Plushie. The Erlang call site loses the type-
  checking Gleam provides, but the generated atoms and tuples
  are clean and stable.

## Module naming

Gleam modules compile to Erlang modules with `@` as the path
separator:

| Gleam module | Erlang atom |
|---|---|
| `plushie` | `plushie` |
| `plushie/ui` | `plushie@ui` |
| `plushie/widget/button` | `plushie@widget@button` |
| `plushie/prop/length` | `plushie@prop@length` |
| `plushie/canvas/shape` | `plushie@canvas@shape` |
| `plushie/animation/transition` | `plushie@animation@transition` |
| `plushie/animation/easing` | `plushie@animation@easing` |

Function names are preserved as-is. Arity matches the Gleam
source: `pub fn foo(a, b)` becomes `foo/2`. All public Gleam
functions are exported.

```erlang
%% Equivalent of ui.button_("save", "Save") from Gleam:
Node = 'plushie@ui':button_(<<"save">>, <<"Save">>).
```

## Value encoding

Every Gleam value has a concrete BEAM representation.

### Primitives

| Gleam type | Erlang representation |
|---|---|
| `Int` | integer (arbitrary precision) |
| `Float` | float |
| `Bool` | atom `true` / `false` |
| `String` | UTF-8 binary |
| `Nil` | atom `nil` |
| `BitArray` | bit string |

Gleam strings are **binaries**, not Erlang strings (which are
char lists). Pass `<<"hello"/utf8>>` or simply `<<"hello">>`
(ASCII) from Erlang.

### Lists and tuples

| Gleam | Erlang |
|---|---|
| `List(a)` | Erlang cons list `[A1, A2, ...]` |
| `#(a, b)` | Erlang tuple `{A, B}` |
| `#(a, b, c)` | `{A, B, C}` |

Note the direct overlap between Gleam tuples and Erlang tuples.
Records compile to tuples too, which means shape-matching between
user data and library internals is ambiguous without discipline.
See the opaque-types caveat below.

### Sum-type variants

Variant constructors become atoms or tagged tuples, with names
converted to snake_case:

| Gleam variant | Erlang value |
|---|---|
| `Fill` | `fill` |
| `Shrink` | `shrink` |
| `FillPortion(3)` | `{fill_portion, 3}` |
| `Fixed(400.0)` | `{fixed, 400.0}` |
| `Primary` | `primary` |
| `Custom(sm)` | `{custom, SM}` |
| `CubicBezier(0.25, 0.1, 0.25, 1.0)` | `{cubic_bezier, 0.25, 0.1, 0.25, 1.0}` |

Argument-less variants become bare atoms. Variants with
arguments become tuples with the snake_cased variant name as the
first element.

### Built-in wrappers

Gleam's standard `Option`, `Result`, and the event-target types
follow the same scheme:

| Gleam | Erlang |
|---|---|
| `None` | `none` |
| `Some(x)` | `{some, X}` |
| `Ok(x)` | `{ok, X}` |
| `Error(e)` | `{error, E}` |

### Records

Records compile to tuples with the record name as the first
element, followed by fields in declaration order:

```gleam
pub type Modifiers {
  Modifiers(shift: Bool, ctrl: Bool, alt: Bool, logo: Bool, command: Bool)
}
```

becomes the Erlang tuple
`{modifiers, Shift, Ctrl, Alt, Logo, Command}`.

### Opaque records

Opaque types (the default for widget builders) compile to
tuples with the type name as the first element:

```erlang
%% From Gleam: button.new("save", "Save")
%% Produces an Erlang tuple:
{button, <<"save">>, <<"Save">>, none, none, none, none, none, none, none, #{}}
```

The field layout is an implementation detail. Do not pattern
match against the internal shape; call the builder functions
(`'plushie@widget@button':new/2`, `:width/2`, ...) instead.

## Calling the SDK from Erlang

### The ui module

`plushie@ui` exports one function per built-in widget, returning
a `plushie@node:node_()` (the widget node).

```erlang
%% Equivalent of:
%%   ui.column("root", [column.Spacing(8.0)], [
%%     ui.text_("greeting", "Hello"),
%%     ui.button_("ok", "OK"),
%%   ])

Greeting = 'plushie@ui':text_(<<"greeting">>, <<"Hello">>),
Ok = 'plushie@ui':button_(<<"ok">>, <<"OK">>),
Column = 'plushie@ui':column(
    <<"root">>,
    [{spacing, 8.0}],
    [Greeting, Ok]
).
```

Opts are the variant-encoded values: `column.Spacing(8.0)` from
Gleam is the Erlang tuple `{spacing, 8.0}`.

### The builder modules

Each widget also exposes a builder module under
`plushie@widget@<name>`:

```erlang
Button = 'plushie@widget@button':new(<<"save">>, <<"Save">>),
Button2 = 'plushie@widget@button':width(Button, fill),
Button3 = 'plushie@widget@button':style(Button2, primary),
Node = 'plushie@widget@button':build(Button3).
```

Compose with `|>` in Gleam, or with pipes of local variables in
Erlang (as above). The build function turns the opaque builder
into a wire-ready `Node`.

### Prop values

Length / Padding / Color / etc. all expose constructors under
their own Erlang modules:

```erlang
Fill = fill,
Fixed200 = {fixed, 200.0},
Portion3 = {fill_portion, 3},

%% Paddings: record tuple with all four sides
P = 'plushie@prop@padding':all(16.0),
%% equivalently:
PManual = {padding, 16.0, 16.0, 16.0, 16.0},

%% Colors: construct through the module (returns Result)
{ok, Blue} = 'plushie@prop@color':from_hex(<<"#3b82f6">>).
```

### Handling events

Events arrive at `update` as nested tuples. Pattern-match on the
outer wrapper and the inner variant:

```erlang
update(Model, Event) ->
    case Event of
        {widget, {click, {event_target, _Window, <<"save">>, _Scope, _Full}}} ->
            save(Model);

        {widget, {input, {event_target, _W, <<"editor">>, _S, _F}, Value}} ->
            Model#{source => Value};

        {key, {key_event, key_pressed, _W, <<"s">>, _Mk, {modifiers, _, _, _, _, true}, _Pk, _L, _T, _R, _C}} ->
            save(Model);

        _ ->
            Model
    end.
```

The verbose wildcards are there because every field has a fixed
position in the tuple. Named field access (`#event_target.id`)
is not available without a `-record` declaration that mirrors the
Gleam record.

A helper module (below) can hide this with accessors.

### Returning commands

Commands are tagged tuples built by the `plushie@command` and
`plushie@effect` modules. Return `{Model, Cmd}` from `update`:

```erlang
update(Model, {widget, {click, {event_target, _, <<"save">>, _, _}}}) ->
    Cmd = 'plushie@command':focus(<<"editor">>),
    {Model, Cmd};

update(Model, {widget, {click, {event_target, _, <<"import">>, _, _}}}) ->
    Cmd = 'plushie@effect':file_open(
        <<"import">>,
        [{dialog_title, <<"Import">>}]
    ),
    {Model, Cmd}.
```

## A helper module pattern

The raw call sites are noisy. For any non-trivial Erlang
codebase, write a thin helper module that provides friendly
names for the common operations:

```erlang
-module(plushie_erl).
-export([text/2, button/2, column/3, row/3,
         press/1, input/2, focus/1]).

%% Shortened builders
text(Id, Content) -> 'plushie@ui':text_(Id, Content).
button(Id, Label) -> 'plushie@ui':button_(Id, Label).
column(Id, Opts, Kids) -> 'plushie@ui':column(Id, Opts, Kids).
row(Id, Opts, Kids) -> 'plushie@ui':row(Id, Opts, Kids).

%% Event accessors
press({widget, {click, {event_target, _, Id, _, _}}}) -> {ok, Id};
press(_) -> error.

input({widget, {input, {event_target, _, Id, _, _}, Value}}) ->
    {ok, {Id, Value}};
input(_) -> error.

%% Command shortcuts
focus(Id) -> 'plushie@command':focus(Id).
```

The helper module then lets application code stay tight:

```erlang
update(Model, Event) ->
    case plushie_erl:press(Event) of
        {ok, <<"save">>} -> {Model, plushie_erl:focus(<<"editor">>)};
        _ -> handle_input(Model, Event)
    end.
```

This is also the shape we recommend for the Plushie Pad
experiment chapters in the guides: a small `pad_helpers.erl`
hides the raw atoms and gives experiments a friendlier surface.

## Starting the runtime from Erlang

The app value is a `plushie@app:app()` tuple. Build it via
`app:simple/3` or `app:application/4`, then hand it to
`plushie@gui:run/2` for a local desktop app or
`plushie@stdio:run/2` for exec / remote rendering:

```erlang
-module(my_app).
-export([main/0, init/0, update/2, view/1]).

main() ->
    App = 'plushie@app':simple(fun init/0, fun update/2, fun view/1),
    Opts = 'plushie@gui':default_opts(),
    'plushie@gui':run(App, Opts).

init() ->
    {#{count => 0}, 'plushie@command':none()}.

update(Model = #{count := N}, {widget, {click, {event_target, _, <<"+">>, _, _}}}) ->
    {Model#{count => N + 1}, 'plushie@command':none()};
update(Model, _) ->
    {Model, 'plushie@command':none()}.

view(#{count := N}) ->
    [
        'plushie@ui':window(<<"main">>, [{title, <<"Counter">>}], [
            'plushie@ui':text(<<"count">>,
                list_to_binary(integer_to_list(N)), [])
        ])
    ].
```

Gleam's higher-ordered-function shape fits Erlang `fun` values
cleanly. The callbacks can be module-exported functions
(`fun init/0`, `fun update/2`, `fun view/1`) or anonymous funs.

## Caveats

### Opaque types

Gleam opaque types (widget builders, `Color`, `Theme`, most prop
types) compile to regular tuples, but the field layout is an
implementation detail. Pattern-matching against the internal
shape works today and may break on the next version bump. Always
go through the module's exported functions
(`'plushie@prop@color':from_hex/1`, `'plushie@widget@button':width/2`).

### No type-checking at the call site

Erlang doesn't know the types Gleam annotated. Passing a
mistyped prop (`'plushie@widget@button':width(B, 3.14)` when the
target expects a `length()`) compiles fine and produces a
meaningless wire value the renderer will reject with a
`PropTypeMismatch` or `PropRangeExceeded` diagnostic. Use
Dialyzer with the generated `.beam` specs if you want more
feedback, or isolate unsafe calls behind a helper module.

### Binary vs string

Gleam strings are binaries. Passing `"hello"` (an Erlang string,
which is a char list) from Erlang produces a list of codepoints,
not a binary. The SDK's input validation panics or silently
fails on this. Always use `<<"...">>` or call `list_to_binary/1`.

### Float-or-integer division

Arithmetic in Gleam is either integer or float, never mixed. If
your Erlang code computes `5 / 2`, that's Erlang integer
division returning a float (`2.5`). If Gleam is expecting an
integer, pass `5 div 2` (`2`). If it expects a float, `5.0 / 2.0`
or `5 / 2` both work.

### Process linking

`plushie@gui:run` blocks the calling process. Errors during the
Elm loop bubble up as exits from the runtime actor. Standard OTP
supervision works: link the runtime into a supervisor tree via
`erlang:spawn_link/1` around `plushie@gui:run`, or build a child
spec that calls it.

## From Gleam: calling Erlang

For completeness: Gleam calls Erlang via `@external`. For a
helper function living in `src/my_helper.erl`:

```erlang
-module(my_helper).
-export([shuffle/1]).

shuffle(List) ->
    [X || {_, X} <- lists:sort([{rand:uniform(), I} || I <- List])].
```

Declared on the Gleam side:

```gleam
@external(erlang, "my_helper", "shuffle")
pub fn shuffle(items: List(a)) -> List(a)
```

Gleam's generated module name is not required here; reference
the Erlang module by its own name. Argument and return encodings
follow the same mapping as above.

## See also

- [App Lifecycle reference](app-lifecycle.md) - the callbacks
  and return shapes you implement on either side of the
  boundary
- [Events reference](events.md) - the variant shapes Erlang
  code pattern-matches against
- [Commands reference](commands.md) - command constructors
  callable from Erlang via the `plushie@command` module
- [CLI Commands reference](cli-commands.md) - running a Plushie
  app regardless of whether the entry is Gleam or Erlang
- [Gleam FFI docs](https://gleam.run/book/tour/external-functions.html) -
  the canonical documentation for `@external` annotations
