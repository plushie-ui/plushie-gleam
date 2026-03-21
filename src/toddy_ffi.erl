-module(toddy_ffi).
-export([
    open_port_spawn/4,
    port_command/2,
    port_close/1,
    try_call/1,
    unique_id/0,
    msgpack_port_options/0,
    json_port_options/0,
    file_exists/1,
    platform_string/0,
    arch_string/0,
    extract_port_data/1,
    extract_line_data/1,
    extract_exit_status/1,
    get_env/1,
    set_env/2,
    unset_env/1,
    monotonic_time_ms/0
]).

%% Open a port with {spawn_executable, Path} and given args, env, options.
%% Args is a list of binaries, Env is an Erlang port env list (already
%% converted by renderer_env_ffi), Options is the port driver options.
open_port_spawn(Path, Args, Env, Options) ->
    CharArgs = [binary_to_list(A) || A <- Args],
    erlang:open_port(
        {spawn_executable, binary_to_list(Path)},
        [{args, CharArgs}, {env, Env} | Options]
    ).

%% Send data to a port.
port_command(Port, Data) ->
    erlang:port_command(Port, Data).

%% Close a port.
port_close(Port) ->
    erlang:port_close(Port).

%% Call a function with try/catch, returning {ok, Result} or {error, Reason}.
try_call(F) ->
    try
        {ok, F()}
    catch
        _:Reason -> {error, Reason}
    end.

%% Generate a unique monotonic integer ID as a binary string.
unique_id() ->
    integer_to_binary(erlang:unique_integer([positive, monotonic])).

%% Port options for MessagePack wire format (4-byte length prefix).
msgpack_port_options() ->
    [binary, {packet, 4}, exit_status, use_stdio].

%% Port options for JSONL wire format (newline-delimited).
json_port_options() ->
    [binary, {line, 65536}, exit_status, use_stdio].

%% Check whether a file exists at the given path.
file_exists(Path) ->
    filelib:is_file(binary_to_list(Path)).

%% Return the platform as a binary string.
platform_string() ->
    case os:type() of
        {unix, linux} -> <<"linux">>;
        {unix, darwin} -> <<"darwin">>;
        {win32, _} -> <<"windows">>;
        _ -> <<"unknown">>
    end.

%% Return the CPU architecture as a binary string.
arch_string() ->
    Arch = erlang:system_info(system_architecture),
    case lists:prefix("x86_64", Arch) orelse lists:prefix("amd64", Arch) of
        true -> <<"x86_64">>;
        false ->
            case lists:prefix("aarch64", Arch) orelse lists:prefix("arm64", Arch) of
                true -> <<"aarch64">>;
                false -> list_to_binary(Arch)
            end
    end.

%% Extract data from a port message tuple {Port, {data, Data}}.
%% For {packet, N} mode, Data is a plain binary.
extract_port_data({_Port, {data, Data}}) when is_binary(Data) -> {ok, Data};
extract_port_data(_) -> {error, not_data}.

%% Extract line data from a port message in {line, N} mode.
%% Returns {eol, Binary} for complete lines or {noeol, Binary} for partials.
extract_line_data({_Port, {data, {eol, Line}}}) -> {ok, {eol, list_to_binary(Line)}};
extract_line_data({_Port, {data, {noeol, Chunk}}}) -> {ok, {noeol, list_to_binary(Chunk)}};
extract_line_data(_) -> {error, not_line_data}.

%% Extract exit status from a port message tuple {Port, {exit_status, Status}}.
extract_exit_status({_Port, {exit_status, Status}}) -> {ok, Status};
extract_exit_status(_) -> {error, not_exit}.

%% Get an environment variable. Returns {ok, Value} or {error, nil}.
get_env(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, list_to_binary(Value)}
    end.

%% Set an environment variable.
set_env(Name, Value) ->
    os:putenv(binary_to_list(Name), binary_to_list(Value)),
    nil.

%% Unset an environment variable.
unset_env(Name) ->
    os:unsetenv(binary_to_list(Name)),
    nil.

%% Return monotonic time in milliseconds.
monotonic_time_ms() ->
    erlang:monotonic_time(millisecond).
