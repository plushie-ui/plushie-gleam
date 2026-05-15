-module(plushie_ffi).
-define(MAX_MESSAGE_SIZE, 67108864).
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
    get_locale/0,
    format_number/2,
    format_date/4,
    extract_port_data/1,
    extract_line_data/1,
    extract_exit_status/1,
    get_env/1,
    set_env/2,
    unset_env/1,
    monotonic_time_ms/0,
    telemetry_execute/3,
    telemetry_attach/4,
    telemetry_handler/4,
    telemetry_detach/1,
    telemetry_duration_measurement/1,
    stdio_port_options_msgpack/0,
    stdio_port_options_json/0,
    open_fd_port/3,
    extract_eof/1,
    null_port/0,
    drain_timer_ticks/2,
    stable_hash_key/1,
    is_finite_float/1,
    gleam_build/0,
    reload_modules/1,
    list_beam_files/1,
    start_file_watcher/1,
    file_watcher_subscribe/1,
    stop_file_watcher/1,
    write_file_atomic/2,
    sha256_hex/1,
    crc32/1,
    zlib_compress/1,
    shutdown_pid/1,
    identity/1,
    with_logger_level/2,
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

get_locale() ->
    get_locale_from_env([<<"LC_ALL">>, <<"LC_MESSAGES">>, <<"LANGUAGE">>, <<"LANG">>]).

get_locale_from_env([]) ->
    <<"en-US">>;
get_locale_from_env([Name | Rest]) ->
    case get_env(Name) of
        {ok, Value} ->
            case normalize_locale(Value) of
                undefined -> get_locale_from_env(Rest);
                Locale -> Locale
            end;
        {error, nil} -> get_locale_from_env(Rest)
    end.

format_number(Number, Locale) ->
    Text = number_to_binary(Number),
    {GroupSep, DecimalSep} = number_separators(Locale),
    format_number_text(Text, GroupSep, DecimalSep).

format_date(Year, Month, Day, Locale) ->
    Y = integer_to_binary(Year),
    M = integer_to_binary(Month),
    D = integer_to_binary(Day),
    M2 = pad2(Month),
    D2 = pad2(Day),
    case date_order(Locale) of
        us -> <<M/binary, "/", D/binary, "/", Y/binary>>;
        european -> <<D2/binary, "/", M2/binary, "/", Y/binary>>;
        iso -> <<Y/binary, "-", M2/binary, "-", D2/binary>>
    end.

normalize_locale(Value) ->
    Trimmed = string:trim(binary_to_list(Value)),
    case Trimmed of
        "" -> undefined;
        _ ->
            FirstLanguage = first_locale_token(Trimmed),
            Base = strip_locale_suffix(FirstLanguage),
            Hyphenated = lists:flatten(string:replace(Base, "_", "-", all)),
            Parts = string:lexemes(Hyphenated, "-"),
            normalize_locale_parts(Parts)
    end.

first_locale_token(Value) ->
    case string:lexemes(Value, ":") of
        [] -> "";
        [First | _] -> First
    end.

strip_locale_suffix(Value) ->
    case string:lexemes(Value, ".@") of
        [] -> "";
        [First | _] -> First
    end.

normalize_locale_parts([]) ->
    undefined;
normalize_locale_parts([Language | Rest]) ->
    LowerLanguage = string:lowercase(Language),
    case valid_language(LowerLanguage) of
        false -> undefined;
        true ->
            case LowerLanguage of
                "c" -> undefined;
                "posix" -> undefined;
                _ -> join_locale_parts([LowerLanguage | normalize_locale_subtags(Rest)])
            end
    end.

normalize_locale_subtags([]) ->
    [];
normalize_locale_subtags([Part | Rest]) ->
    Normalized =
        case length(Part) of
            2 -> string:uppercase(Part);
            3 -> string:uppercase(Part);
            4 -> titlecase_ascii(Part);
            _ -> string:lowercase(Part)
        end,
    [Normalized | normalize_locale_subtags(Rest)].

join_locale_parts(Parts) ->
    list_to_binary(string:join(Parts, "-")).

valid_language(Language) ->
    Len = length(Language),
    (Len =:= 2 orelse Len =:= 3) andalso lists:all(fun is_ascii_letter/1, Language).

is_ascii_letter(C) ->
    (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z).

titlecase_ascii([]) ->
    [];
titlecase_ascii([First | Rest]) ->
    string:uppercase([First]) ++ string:lowercase(Rest).

number_to_binary(Number) when is_float(Number) ->
    strip_zero_fraction(float_to_binary(Number, [short]));
number_to_binary(Number) when is_integer(Number) ->
    integer_to_binary(Number).

strip_zero_fraction(Text) ->
    case binary:split(Text, <<".">>) of
        [Integer, <<"0">>] -> Integer;
        _ -> Text
    end.

number_separators(Locale) ->
    case locale_language(Locale) of
        <<"de">> -> {<<".">>, <<",">>};
        <<"fr">> -> {<<" ">>, <<",">>};
        _ -> {<<",">>, <<".">>}
    end.

format_number_text(<<"-", Rest/binary>>, GroupSep, DecimalSep) ->
    Formatted = format_unsigned_number_text(Rest, GroupSep, DecimalSep),
    <<"-", Formatted/binary>>;
format_number_text(Text, GroupSep, DecimalSep) ->
    format_unsigned_number_text(Text, GroupSep, DecimalSep).

format_unsigned_number_text(Text, GroupSep, DecimalSep) ->
    case binary:match(Text, [<<"e">>, <<"E">>]) of
        {_, _} -> binary:replace(Text, <<".">>, DecimalSep);
        nomatch ->
            case binary:split(Text, <<".">>) of
                [Integer, Fraction] ->
                    Grouped = group_integer(Integer, GroupSep),
                    <<Grouped/binary, DecimalSep/binary, Fraction/binary>>;
                [Integer] -> group_integer(Integer, GroupSep)
            end
    end.

group_integer(Integer, GroupSep) ->
    Grouped = group_digits(binary_to_list(Integer), binary_to_list(GroupSep)),
    list_to_binary(Grouped).

group_digits(Digits, GroupSep) ->
    case length(Digits) =< 3 of
        true -> Digits;
        false ->
            SplitAt = length(Digits) - 3,
            {Head, Tail} = lists:split(SplitAt, Digits),
            group_digits(Head, GroupSep) ++ GroupSep ++ Tail
    end.

date_order(Locale) ->
    Normalized = normalize_locale_or_raw(Locale),
    Language = locale_language(Normalized),
    case Normalized of
        <<"en-US">> -> us;
        <<"en">> -> us;
        _ ->
            case lists:member(Language, european_date_languages()) of
                true -> european;
                false ->
                    case lists:member(Language, [<<"ja">>, <<"zh">>, <<"ko">>]) of
                        true -> iso;
                        false -> iso
                    end
            end
    end.

european_date_languages() ->
    [
        <<"bg">>, <<"cs">>, <<"da">>, <<"de">>, <<"el">>, <<"en">>, <<"es">>,
        <<"fi">>, <<"fr">>, <<"hr">>, <<"hu">>, <<"it">>, <<"nl">>, <<"no">>,
        <<"pl">>, <<"pt">>, <<"ro">>, <<"ru">>, <<"sk">>, <<"sl">>, <<"sv">>,
        <<"tr">>, <<"uk">>
    ].

locale_language(Locale) ->
    Normalized = normalize_locale_or_raw(Locale),
    hd(binary:split(Normalized, <<"-">>)).

normalize_locale_or_raw(Locale) ->
    case normalize_locale(Locale) of
        undefined -> Locale;
        Normalized -> Normalized
    end.

pad2(Value) when Value >= 0, Value =< 9 ->
    <<"0", (integer_to_binary(Value))/binary>>;
pad2(Value) ->
    integer_to_binary(Value).

%% Extract data from a port message tuple {Port, {data, Data}}.
%% For {packet, N} mode, Data is a plain binary.
extract_port_data({_Port, {data, Data}}) when is_binary(Data), byte_size(Data) =< ?MAX_MESSAGE_SIZE ->
    {ok, Data};
extract_port_data({_Port, {data, Data}}) when is_binary(Data) ->
    {error, overflow};
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
%% Event names and map keys are whitelisted so untrusted strings never
%% allocate new atoms. Unknown events are discarded because telemetry is
%% observational. Unknown measurement and metadata keys are omitted.
telemetry_execute(EventName, Measurements, Metadata) ->
    case telemetry_event_atoms(EventName) of
        {ok, AtomName} ->
            AtomMeasurements = gleam_dict_to_atom_map(Measurements),
            AtomMetadata = gleam_dict_to_atom_map(Metadata),
            telemetry:execute(AtomName, AtomMeasurements, AtomMetadata);
        error ->
            nil
    end,
    nil.

telemetry_handler(Event, Measurements, Metadata, HandlerId) ->
    case persistent_term:get({plushie_telemetry_handler, HandlerId}, undefined) of
        undefined ->
            nil;
        Handler ->
            StringEvent = [atom_to_binary(A, utf8) || A <- Event],
            StringMeasurements = atom_map_to_gleam_dict(Measurements),
            StringMetadata = atom_map_to_gleam_dict(Metadata),
            Handler(StringEvent, StringMeasurements, StringMetadata)
    end.

%% Telemetry: attach a handler.
%% The Gleam handler takes (List(String), Dict, Dict) -> Nil.
%% Store it in persistent_term and attach a module function so
%% telemetry doesn't log warnings about local handlers.
telemetry_attach(HandlerId, EventName, Handler, _Config) ->
    case telemetry_event_atoms(EventName) of
        {ok, AtomName} ->
            persistent_term:put({plushie_telemetry_handler, HandlerId}, Handler),
            case telemetry:attach(HandlerId, AtomName, fun ?MODULE:telemetry_handler/4, HandlerId) of
                ok -> {ok, nil};
                {error, Reason} ->
                    persistent_term:erase({plushie_telemetry_handler, HandlerId}),
                    {error, Reason}
            end;
        error ->
            {error, unknown_telemetry_event}
    end.

%% Telemetry: detach a handler.
telemetry_detach(HandlerId) ->
    persistent_term:erase({plushie_telemetry_handler, HandlerId}),
    telemetry:detach(HandlerId),
    nil.

telemetry_duration_measurement(DurationMs) ->
    gleam@dict:from_list([{<<"duration_ms">>, DurationMs}]).

%% Convert a Gleam Dict (with binary keys) to an Erlang map with atom keys.
gleam_dict_to_atom_map(Dict) ->
    maps:fold(fun(K, V, Acc) ->
        case telemetry_key_atom(K) of
            {ok, AtomKey} -> Acc#{AtomKey => V};
            error -> Acc
        end
    end, #{}, Dict).

telemetry_event_atoms([<<"plushie">>, <<"bridge">>, <<"send">>]) ->
    {ok, [plushie, bridge, send]};
telemetry_event_atoms([<<"plushie">>, <<"bridge">>, <<"receive">>]) ->
    {ok, [plushie, bridge, 'receive']};
telemetry_event_atoms([<<"plushie">>, <<"bridge">>, <<"restart">>]) ->
    {ok, [plushie, bridge, restart]};
telemetry_event_atoms([<<"plushie">>, <<"bridge">>, <<"decode_error">>]) ->
    {ok, [plushie, bridge, decode_error]};
telemetry_event_atoms([<<"plushie">>, <<"diff">>]) ->
    {ok, [plushie, diff]};
telemetry_event_atoms([<<"plushie">>, <<"diff">>, <<"complete">>]) ->
    {ok, [plushie, diff, complete]};
telemetry_event_atoms([<<"plushie">>, <<"diff">>, <<"start">>]) ->
    {ok, [plushie, diff, start]};
telemetry_event_atoms([<<"plushie">>, <<"diff">>, <<"stop">>]) ->
    {ok, [plushie, diff, stop]};
telemetry_event_atoms([<<"plushie">>, <<"view">>]) ->
    {ok, [plushie, view]};
telemetry_event_atoms([<<"plushie">>, <<"view">>, <<"start">>]) ->
    {ok, [plushie, view, start]};
telemetry_event_atoms([<<"plushie">>, <<"view">>, <<"stop">>]) ->
    {ok, [plushie, view, stop]};
telemetry_event_atoms([<<"plushie">>, <<"normalize">>]) ->
    {ok, [plushie, normalize]};
telemetry_event_atoms([<<"plushie">>, <<"normalize">>, <<"start">>]) ->
    {ok, [plushie, normalize, start]};
telemetry_event_atoms([<<"plushie">>, <<"normalize">>, <<"stop">>]) ->
    {ok, [plushie, normalize, stop]};
telemetry_event_atoms([<<"plushie">>, <<"update">>]) ->
    {ok, [plushie, update]};
telemetry_event_atoms([<<"plushie">>, <<"update">>, <<"start">>]) ->
    {ok, [plushie, update, start]};
telemetry_event_atoms([<<"plushie">>, <<"update">>, <<"stop">>]) ->
    {ok, [plushie, update, stop]};
telemetry_event_atoms([<<"plushie">>, <<"test">>, <<"noop">>]) ->
    {ok, [plushie, test, noop]};
telemetry_event_atoms([<<"plushie">>, <<"test">>, <<"ping">>]) ->
    {ok, [plushie, test, ping]};
telemetry_event_atoms([<<"plushie">>, <<"test">>, <<"detach_check">>]) ->
    {ok, [plushie, test, detach_check]};
telemetry_event_atoms([<<"plushie">>, <<"test">>, <<"meta">>]) ->
    {ok, [plushie, test, meta]};
telemetry_event_atoms([<<"plushie">>, <<"test">>, <<"dup">>]) ->
    {ok, [plushie, test, dup]};
telemetry_event_atoms(_) ->
    error.

telemetry_key_atom(<<"byte_size">>) -> {ok, byte_size};
telemetry_key_atom(<<"duration_ms">>) -> {ok, duration_ms};
telemetry_key_atom(<<"nodes">>) -> {ok, nodes};
telemetry_key_atom(<<"ops">>) -> {ok, ops};
telemetry_key_atom(<<"op_count">>) -> {ok, op_count};
telemetry_key_atom(<<"count">>) -> {ok, count};
telemetry_key_atom(<<"reason">>) -> {ok, reason};
telemetry_key_atom(_) -> error.

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

%% Return true when a float is finite (not NaN or +/-Infinity).
is_finite_float(Value) when is_float(Value) ->
    Delta = Value - Value,
    Delta =:= Delta;
is_finite_float(_) ->
    false.

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
%% Returns {ok, Pid} or {error, Reason} if file_system is not installed.
start_file_watcher(Dirs) ->
    DirsStr = [binary_to_list(D) || D <- Dirs],
    try file_system:start_link(DirsStr) of
        {ok, Pid} -> {ok, Pid};
        Err -> {error, iolist_to_binary(io_lib:format("file_system:start_link failed: ~p", [Err]))}
    catch
        error:undef ->
            {error, <<"file_system not available. "
                      "Add `file_system = \">= 1.0.0 and < 2.0.0\"` to [dependencies] "
                      "in gleam.toml and install Elixir to enable hot reload.">>}
    end.

%% Subscribe the calling process to file events from the watcher.
file_watcher_subscribe(Pid) ->
    file_system:subscribe(Pid),
    nil.

%% Stop a file_system watcher process (GenServer).
stop_file_watcher(Pid) ->
    try gen_server:stop(Pid, normal, 5000)
    catch _:_ -> ok
    end,
    nil.

write_file_atomic(Path, Content) ->
    PathStr = binary_to_list(Path),
    ok = filelib:ensure_dir(PathStr),
    TmpPath = PathStr ++ ".tmp." ++ integer_to_list(erlang:unique_integer([positive])),
    case file:write_file(TmpPath, Content) of
        ok ->
            case file:rename(TmpPath, PathStr) of
                ok -> {ok, nil};
                {error, eexist} ->
                    _ = file:delete(PathStr),
                    case file:rename(TmpPath, PathStr) of
                        ok -> {ok, nil};
                        {error, RetryReason} ->
                            _ = file:delete(TmpPath),
                            {error, list_to_binary(file:format_error(RetryReason))}
                    end;
                {error, Reason} ->
                    _ = file:delete(TmpPath),
                    {error, list_to_binary(file:format_error(Reason))}
            end;
        {error, Reason} ->
            {error, list_to_binary(file:format_error(Reason))}
    end.

%% Compute SHA-256 hash and return as lowercase hex binary.
sha256_hex(Data) ->
    Hash = crypto:hash(sha256, Data),
    list_to_binary([io_lib:format("~2.16.0b", [B]) || <<B>> <= Hash]).

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
with_logger_level(Level, Fun) ->
    PrevConfig = logger:get_primary_config(),
    PrevLevel = maps:get(level, PrevConfig, notice),
    logger:set_primary_config(level, binary_to_atom(Level, utf8)),
    try
        Fun()
    after
        logger:set_primary_config(level, PrevLevel)
    end.

log_info(Msg) -> logger:info(Msg), nil.
log_warning(Msg) -> logger:warning(Msg), nil.
log_error(Msg) -> logger:error(Msg), nil.
