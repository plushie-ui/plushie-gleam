-module(plushie_download_ffi).
-export([
    download_binary/2,
    has_flag/1,
    get_flag_value/1,
    ensure_dir/1,
    write_file/2,
    delete_file/1,
    chmod/2,
    bytes_to_string/1,
    extract_tarball/2,
    make_symlink/2
]).

%% Download a URL following redirects. Returns {ok, Body} or {error, Reason}.
download_binary(Url, MaxRedirects) ->
    ensure_http_started(),
    do_download(binary_to_list(Url), MaxRedirects).

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
            %% No verify_none fallback -- require TLS verification.
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
    FlagStr = binary_to_list(Flag),
    lists:member(FlagStr, init:get_plain_arguments()).

%% Get the value following a flag in init:get_plain_arguments().
%% Returns {ok, Value} or {error, nil}.
get_flag_value(Flag) ->
    FlagStr = binary_to_list(Flag),
    Args = init:get_plain_arguments(),
    find_flag_value(FlagStr, Args).

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

%% Create a symbolic link. Returns {ok, nil} or {error, Reason}.
make_symlink(Target, Link) ->
    case file:make_symlink(binary_to_list(Target), binary_to_list(Link)) of
        ok -> {ok, nil};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.

%% Extract a compressed tarball to a destination directory.
%% Uses :erl_tar.extract with :compressed and {:cwd, Dir}.
extract_tarball(TarballPath, DestDir) ->
    case erl_tar:extract(binary_to_list(TarballPath),
                         [compressed, {cwd, binary_to_list(DestDir)}]) of
        ok -> {ok, nil};
        {error, Reason} ->
            {error, list_to_binary(io_lib:format("~p", [Reason]))}
    end.
