-module(plushie_ffi).
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
    monotonic_time_ms/0,
    telemetry_execute/3,
    telemetry_attach/4,
    telemetry_detach/1,
    stdio_port_options_msgpack/0,
    stdio_port_options_json/0,
    open_fd_port/3,
    extract_eof/1,
    null_port/0,
    drain_timer_ticks/2,
    stable_hash_key/1,
    gleam_build/0,
    reload_modules/1,
    list_beam_files/1,
    start_file_watcher/1,
    file_watcher_subscribe/1,
    sha256_hex/1,
    crc32/1,
    zlib_compress/1,
    shutdown_pid/1,
    identity/1,
    log_info/1,
    log_warning/1,
    log_error/1
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

%% Telemetry: execute an event.
%% Converts the event name from a list of binaries to a list of atoms,
%% and measurements/metadata from Gleam Dict to Erlang maps with atom keys.
telemetry_execute(EventName, Measurements, Metadata) ->
    AtomName = [binary_to_atom(N, utf8) || N <- EventName],
    AtomMeasurements = gleam_dict_to_atom_map(Measurements),
    AtomMetadata = gleam_dict_to_atom_map(Metadata),
    telemetry:execute(AtomName, AtomMeasurements, AtomMetadata),
    nil.

%% Telemetry: attach a handler.
%% The Gleam handler takes (List(String), Dict, Dict) -> Nil.
%% We wrap it to convert from atoms back to strings for the callback.
telemetry_attach(HandlerId, EventName, Handler, _Config) ->
    AtomName = [binary_to_atom(N, utf8) || N <- EventName],
    WrappedHandler = fun(Event, Measurements, Metadata, _Cfg) ->
        StringEvent = [atom_to_binary(A, utf8) || A <- Event],
        StringMeasurements = atom_map_to_gleam_dict(Measurements),
        StringMetadata = atom_map_to_gleam_dict(Metadata),
        Handler(StringEvent, StringMeasurements, StringMetadata)
    end,
    case telemetry:attach(HandlerId, AtomName, WrappedHandler, nil) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

%% Telemetry: detach a handler.
telemetry_detach(HandlerId) ->
    telemetry:detach(HandlerId),
    nil.

%% Convert a Gleam Dict (with binary keys) to an Erlang map with atom keys.
gleam_dict_to_atom_map(Dict) ->
    maps:fold(fun(K, V, Acc) ->
        AtomKey = binary_to_atom(K, utf8),
        Acc#{AtomKey => V}
    end, #{}, Dict).

%% Convert an Erlang map with atom keys to a Gleam-compatible map with binary keys.
atom_map_to_gleam_dict(Map) ->
    maps:fold(fun(K, V, Acc) ->
        BinKey = case is_atom(K) of
            true -> atom_to_binary(K, utf8);
            false -> K
        end,
        Acc#{BinKey => V}
    end, #{}, Map).

%% Port options for stdio transport (MessagePack, no exit_status).
stdio_port_options_msgpack() ->
    [binary, eof, {packet, 4}].

%% Port options for stdio transport (JSON, no exit_status).
stdio_port_options_json() ->
    [binary, eof, {line, 65536}].

%% Open an fd port for stdin/stdout transport.
open_fd_port(InputFd, OutputFd, Options) ->
    erlang:open_port({fd, InputFd, OutputFd}, Options).

%% Extract eof from a port message {Port, eof}.
extract_eof({_Port, eof}) -> {ok, nil};
extract_eof(_) -> {error, not_eof}.

%% Return a placeholder value for iostream transport (no real port).
%% Uses a self-referencing atom to avoid any accidental port operations.
null_port() ->
    %% Open and immediately close a dummy port to get a valid but dead port ref.
    Port = erlang:open_port({spawn, "true"}, []),
    erlang:port_close(Port),
    Port.

%% Drain queued TimerFired messages for the same tag from the mailbox.
%% Uses Erlang selective receive with zero timeout so non-matching
%% messages are left undisturbed in the mailbox.
%%
%% The Subject is {subject, Owner, SubjectTag} in Gleam's compiled form.
%% Messages sent via the subject arrive as {SubjectTag, Payload}.
%% TimerFired(tag: Tag) compiles to {timer_fired, Tag}.
drain_timer_ticks(Subject, TimerTag) ->
    Tag = subject_tag(Subject),
    drain_timer_ticks_loop(Tag, TimerTag).

drain_timer_ticks_loop(Tag, TimerTag) ->
    receive
        {Tag, {timer_fired, TimerTag}} ->
            drain_timer_ticks_loop(Tag, TimerTag)
    after
        0 -> nil
    end.

subject_tag({subject, _Owner, SubjectTag}) -> SubjectTag;
subject_tag({named_subject, Name}) -> Name.

%% Return a stable hash key for any Erlang term as a binary string.
%% Uses erlang:phash2 which gives consistent results regardless of
%% how the value is wrapped (e.g. raw vs Dynamic).
stable_hash_key(Value) ->
    integer_to_binary(erlang:phash2(Value)).

%% Run `gleam build` and return the output as a binary string.
gleam_build() ->
    Output = os:cmd("gleam build 2>&1"),
    list_to_binary(Output).

%% Reload a list of module atoms: purge and reload each.
reload_modules(Modules) ->
    lists:foreach(fun(M) ->
        code:purge(M),
        code:load_file(M)
    end, Modules),
    nil.

%% Scan a directory for .beam files, returning [{ModuleAtom, Mtime}].
list_beam_files(Dir) ->
    DirStr = binary_to_list(Dir),
    case filelib:wildcard(DirStr ++ "/**/*.beam") of
        [] -> [];
        Files ->
            [{list_to_atom(filename:basename(F, ".beam")),
              filelib:last_modified(F)} || F <- Files]
    end.

%% Start a file_system watcher on the given list of directories.
start_file_watcher(Dirs) ->
    DirsStr = [binary_to_list(D) || D <- Dirs],
    {ok, Pid} = file_system:start_link(DirsStr),
    Pid.

%% Subscribe the calling process to file events from the watcher.
file_watcher_subscribe(Pid) ->
    file_system:subscribe(Pid),
    nil.

%% Compute SHA-256 hash and return as lowercase hex binary.
sha256_hex(Data) ->
    Hash = crypto:hash(sha256, Data),
    list_to_binary(string:lowercase(binary_to_list(
        << <<(integer_to_binary(B, 16))/binary>> || <<B:4>> <= Hash >>
    ))).

%% CRC32 of binary data.
crc32(Data) ->
    erlang:crc32(Data).

%% Zlib compress binary data.
zlib_compress(Data) ->
    zlib:compress(Data).

%% Gracefully stop a process with reason :shutdown.
%% Used to stop supervisors in the OTP-standard way.
shutdown_pid(Pid) ->
    exit(Pid, shutdown),
    nil.

%% Identity function for Gleam type erasure (e.g. model -> Dynamic).
identity(X) -> X.

%% Erlang logger wrappers that return nil instead of ok.
log_info(Msg) -> logger:info(Msg), nil.
log_warning(Msg) -> logger:warning(Msg), nil.
log_error(Msg) -> logger:error(Msg), nil.

