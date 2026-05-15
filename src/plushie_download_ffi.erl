-module(plushie_download_ffi).
-export([
    download_binary/2,
    run_tool/2,
    has_flag/1,
    get_flag_value/1,
    ensure_dir/1,
    write_file/2,
    delete_file/1,
    chmod/2,
    bytes_to_string/1,
    extract_tarball/2
]).

%% Download a URL following redirects. Returns {ok, Body} or {error, Reason}.
download_binary(Url, MaxRedirects) ->
    ensure_http_started(),
    do_download(binary_to_list(Url), MaxRedirects).

run_tool(Path, Args) ->
    Program = binary_to_list(Path),
    case resolve_program(Program) of
        {ok, Resolved} ->
            ArgList = [binary_to_list(Arg) || Arg <- Args],
            Port = open_port({spawn_executable, Resolved},
                             [binary, exit_status, use_stdio, stderr_to_stdout,
                              {args, ArgList}]),
            collect_tool_output(Port, []);
        {error, Reason} ->
            {error, Reason}
    end.

resolve_program(Program) ->
    case filename:dirname(Program) of
        "." ->
            case os:find_executable(Program) of
                false ->
                    {error, list_to_binary("executable not found: " ++ Program)};
                Resolved ->
                    {ok, Resolved}
            end;
        _ ->
            {ok, Program}
    end.

collect_tool_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_tool_output(Port, [Acc, Data]);
        {Port, {exit_status, 0}} ->
            {ok, iolist_to_binary(Acc)};
        {Port, {exit_status, Status}} ->
            Output = iolist_to_binary(Acc),
            {error, iolist_to_binary([
                "status ", integer_to_list(Status), ": ", Output
            ])}
    after 30000 ->
        port_close(Port),
        {error, <<"timed out">>}
    end.

do_download(_Url, 0) ->
    {error, <<"too many redirects">>};
do_download(Url, RedirectsLeft) ->
    Headers = [{"user-agent", "plushie-gleam-download"}],
    SslOpts = ssl_opts(),
    case httpc:request(get, {Url, Headers},
                       [{ssl, SslOpts}, {autoredirect, false}],
                       [{body_format, binary}]) of
        {ok, {{_, 200, _}, _Headers, Body}} ->
            {ok, Body};
        {ok, {{_, Status, _}, RespHeaders, _Body}}
          when Status =:= 301; Status =:= 302; Status =:= 303;
               Status =:= 307; Status =:= 308 ->
            case lists:keyfind("location", 1, RespHeaders) of
                {_, Location} ->
                    do_download(Location, RedirectsLeft - 1);
                false ->
                    {error, list_to_binary(
                        "redirect without location header (status " ++
                        integer_to_list(Status) ++ ")")}
            end;
        {ok, {{_, Status, _}, _, _}} ->
            {error, list_to_binary("HTTP " ++ integer_to_list(Status))};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

ssl_opts() ->
    try
        Cacerts = public_key:cacerts_get(),
        MatchFun = public_key:pkix_verify_hostname_match_fun(https),
        [{verify, verify_peer},
         {cacerts, Cacerts},
         {depth, 3},
         {customize_hostname_check, [{match_fun, MatchFun}]}]
    catch
        _:_ ->
            %% No verify_none fallback; require TLS verification.
            %% If cacerts_get fails, the user needs to configure
            %% their Erlang/OTP installation with CA certificates.
            error({ssl_cacerts_unavailable,
                   "TLS certificate verification requires CA certificates. "
                   "Ensure your Erlang/OTP installation includes the "
                   "public_key application with system CA certificates."})
    end.

ensure_http_started() ->
    application:ensure_all_started(inets),
    application:ensure_all_started(ssl),
    ok.

%% Check if a flag is present in init:get_plain_arguments().
has_flag(Flag) ->
    plushie_cli_args_ffi:has_flag(Flag, init:get_plain_arguments()).

%% Get the value following a flag in init:get_plain_arguments().
%% Returns {ok, Value} or {error, nil}.
get_flag_value(Flag) ->
    plushie_cli_args_ffi:get_flag_value(Flag, init:get_plain_arguments()).

%% Create directory (and parents) if it doesn't exist.
ensure_dir(Path) ->
    filelib:ensure_dir(binary_to_list(Path) ++ "/dummy"),
    nil.

%% Write binary data to a file.
write_file(Path, Data) ->
    ok = file:write_file(binary_to_list(Path), Data),
    nil.

%% Delete a file (ignore errors).
delete_file(Path) ->
    file:delete(binary_to_list(Path)),
    nil.

%% Set file permissions.
chmod(Path, Mode) ->
    file:change_mode(binary_to_list(Path), Mode),
    nil.

%% Convert binary bytes to a Gleam string (identity for binaries).
bytes_to_string(Data) when is_binary(Data) ->
    Data;
bytes_to_string(Data) when is_list(Data) ->
    list_to_binary(Data).


%% Extract a compressed tarball to a destination directory.
%% Uses :erl_tar.extract with :compressed and {:cwd, Dir}.
extract_tarball(TarballPath, DestDir) ->
    case erl_tar:extract(binary_to_list(TarballPath),
                         [compressed, {cwd, binary_to_list(DestDir)}]) of
        ok -> {ok, nil};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.
