-module(plushie_build_ffi).
-export([
    rustc_version/0,
    executable_exists/1,
    has_flag/1,
    get_flag_value/1,
    ensure_dir/1,
    copy_file/2,
    chmod/2,
    dir_exists/1,
    delete_file/1,
    make_symlink/2,
    parse_int/1,
    check_wasm_pack/0,
    wasm_pack_build/2,
    write_file/2,
    read_file/1,
    file_exists/1,
    project_name/0,
    get_cwd/0,
    run_command/2
]).

%% Check if an executable is on PATH (Gleam-facing, takes binary).
executable_exists(Name) ->
    case os:find_executable(binary_to_list(Name)) of
        false -> false;
        _ -> true
    end.

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

%% Get the value following a flag (e.g. --bin-file PATH).
get_flag_value(Flag) ->
    FlagStr = binary_to_list(Flag),
    find_flag_value(FlagStr, init:get_plain_arguments()).

find_flag_value(_Flag, []) ->
    {error, nil};
find_flag_value(Flag, [Flag, Value | _Rest]) ->
    {ok, list_to_binary(Value)};
find_flag_value(Flag, [_ | Rest]) ->
    find_flag_value(Flag, Rest).

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

%% Delete a file (ignore errors).
delete_file(Path) ->
    file:delete(binary_to_list(Path)),
    nil.

%% Create a symbolic link. Returns {ok, nil} or {error, Reason}.
make_symlink(Target, Link) ->
    case file:make_symlink(binary_to_list(Target), binary_to_list(Link)) of
        ok -> {ok, nil};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

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

%% Write binary content to a file. Creates parent dirs.
write_file(Path, Content) ->
    PathStr = binary_to_list(Path),
    filelib:ensure_dir(PathStr),
    ok = file:write_file(PathStr, Content),
    nil.

%% Read a file. Returns {ok, Content} or {error, Reason}.
read_file(Path) ->
    case file:read_file(binary_to_list(Path)) of
        {ok, Content} -> {ok, Content};
        {error, Reason} -> {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

%% Check if a regular file exists.
file_exists(Path) ->
    filelib:is_regular(binary_to_list(Path)).

%% Read the project name from gleam.toml.
project_name() ->
    case file:read_file("gleam.toml") of
        {ok, Content} ->
            Lines = binary:split(Content, <<"\n">>, [global]),
            find_name(Lines);
        {error, _} ->
            {error, <<"gleam.toml not found">>}
    end.

find_name([]) ->
    {error, <<"name not found in gleam.toml">>};
find_name([Line | Rest]) ->
    Trimmed = string:trim(binary_to_list(Line)),
    case Trimmed of
        [$[ | _] ->
            %% Hit a section header, stop looking in root
            {error, <<"name not found in gleam.toml root">>};
        _ ->
            case string:split(Trimmed, "=", leading) of
                [KeyPart, ValuePart] ->
                    K = string:trim(KeyPart),
                    case K of
                        "name" ->
                            V = string:trim(ValuePart),
                            case V of
                                [$" | R] ->
                                    case lists:reverse(R) of
                                        [$" | Inner] ->
                                            {ok, list_to_binary(lists:reverse(Inner))};
                                        _ ->
                                            find_name(Rest)
                                    end;
                                _ ->
                                    find_name(Rest)
                            end;
                        _ ->
                            find_name(Rest)
                    end;
                _ ->
                    find_name(Rest)
            end
    end.

%% Get current working directory.
get_cwd() ->
    {ok, Cwd} = file:get_cwd(),
    list_to_binary(Cwd).

%% Run an arbitrary command with args. Combined stdout/stderr captured.
%% Returns {ok, Output} on status 0, {error, Output} otherwise.
run_command(Cmd, Args) ->
    CmdStr = binary_to_list(Cmd),
    Exe = case filename:dirname(CmdStr) of
        "." ->
            case os:find_executable(CmdStr) of
                false -> error({executable_not_found, CmdStr});
                Found -> Found
            end;
        _ ->
            CmdStr
    end,
    ArgStrs = [binary_to_list(A) || A <- Args],
    Port = erlang:open_port({spawn_executable, Exe}, [
        {args, ArgStrs},
        stream, binary, exit_status, use_stdio, stderr_to_stdout
    ]),
    collect_port_output(Port, <<>>).
