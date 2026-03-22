-module(plushie_build_ffi).
-export([
    rustc_version/0,
    cargo_build/2,
    has_flag/1,
    ensure_dir/1,
    copy_file/2,
    chmod/2,
    dir_exists/1,
    parse_int/1,
    check_wasm_pack/0,
    wasm_pack_build/2
]).

%% Get the rustc version as "MAJOR.MINOR.PATCH" string.
%% Returns {ok, Version} or {error, Message}.
rustc_version() ->
    try
        Output = os:cmd("rustc --version 2>&1"),
        OutputBin = list_to_binary(Output),
        case re:run(OutputBin, <<"rustc (\\d+)\\.(\\d+)\\.(\\d+)">>,
                    [{capture, [1, 2, 3], binary}]) of
            {match, [Major, Minor, Patch]} ->
                {ok, <<Major/binary, ".", Minor/binary, ".", Patch/binary>>};
            nomatch ->
                {error, <<"rustc not found. Install Rust 1.92.0+ via https://rustup.rs">>}
        end
    catch
        _:_ ->
            {error, <<"rustc not found. Install Rust 1.92.0+ via https://rustup.rs">>}
    end.

%% Run cargo build. Returns {ok, Output} on success, {error, Output} on failure.
%% Uses spawn_executable with cargo directly and {cd, Dir} for cross-platform support.
cargo_build(SourceDir, Release) ->
    SourceDirStr = binary_to_list(SourceDir),
    Cargo = find_executable("cargo"),
    Args = case Release of
        true -> ["-p", "plushie", "--release"];
        false -> ["-p", "plushie"]
    end,
    Port = erlang:open_port({spawn_executable, Cargo}, [
        {args, ["build" | Args]},
        {cd, SourceDirStr},
        stream, binary, exit_status, use_stdio, stderr_to_stdout
    ]),
    collect_port_output(Port, <<>>).

find_executable(Name) ->
    case os:find_executable(Name) of
        false -> error({executable_not_found, Name});
        Path -> Path
    end.

collect_port_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_port_output(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, 0}} ->
            {ok, Acc};
        {Port, {exit_status, _Status}} ->
            {error, Acc}
    end.

%% Check if a flag is present in init:get_plain_arguments().
has_flag(Flag) ->
    FlagStr = binary_to_list(Flag),
    lists:member(FlagStr, init:get_plain_arguments()).

%% Create directory (and parents) if it doesn't exist.
ensure_dir(Path) ->
    filelib:ensure_dir(binary_to_list(Path) ++ "/dummy"),
    nil.

%% Copy a file.
copy_file(Src, Dest) ->
    {ok, _} = file:copy(binary_to_list(Src), binary_to_list(Dest)),
    nil.

%% Set file permissions.
chmod(Path, Mode) ->
    file:change_mode(binary_to_list(Path), Mode),
    nil.

%% Check if a directory exists.
dir_exists(Path) ->
    filelib:is_dir(binary_to_list(Path)).

%% Parse an integer from a string. Returns {ok, Int} or {error, nil}.
parse_int(Str) ->
    try
        {ok, binary_to_integer(Str)}
    catch
        _:_ -> {error, nil}
    end.

%% Check if wasm-pack is available. Returns {ok, nil} or {error, Message}.
check_wasm_pack() ->
    try
        WasmPack = find_executable("wasm-pack"),
        Port = erlang:open_port({spawn_executable, WasmPack}, [
            {args, ["--version"]},
            stream, binary, exit_status, use_stdio, stderr_to_stdout
        ]),
        case collect_port_output(Port, <<>>) of
            {ok, _} -> {ok, nil};
            {error, _} ->
                {error, <<"wasm-pack not found. Install via https://rustwasm.github.io/wasm-pack/">>}
        end
    catch
        _:_ ->
            {error, <<"wasm-pack not found. Install via https://rustwasm.github.io/wasm-pack/">>}
    end.

%% Run wasm-pack build. Returns {ok, Output} on success, {error, Output} on failure.
wasm_pack_build(CrateDir, Release) ->
    CrateDirStr = binary_to_list(CrateDir),
    WasmPack = find_executable("wasm-pack"),
    Profile = case Release of
        true -> "--release";
        false -> "--dev"
    end,
    Port = erlang:open_port({spawn_executable, WasmPack}, [
        {args, ["build", "--target", "web", Profile]},
        {cd, CrateDirStr},
        stream, binary, exit_status, use_stdio, stderr_to_stdout
    ]),
    collect_port_output(Port, <<>>).
