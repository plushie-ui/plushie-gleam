-module(plushie_connect_ffi).
-export([
    get_flag_value/1,
    read_stdin_line_timeout/1,
    parse_json_token/1
]).

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

%% Read a line from stdin with a timeout. Returns {ok, Line} or {error, nil}.
%% Spawns a task to avoid blocking the caller indefinitely.
read_stdin_line_timeout(TimeoutMs) ->
    Parent = self(),
    Pid = spawn(fun() ->
        case io:get_line("") of
            eof -> Parent ! {stdin_line, error};
            {error, _} -> Parent ! {stdin_line, error};
            Line when is_list(Line) ->
                Parent ! {stdin_line, {ok, list_to_binary(string:trim(Line))}};
            Line when is_binary(Line) ->
                Parent ! {stdin_line, {ok, string:trim(Line)}}
        end
    end),
    receive
        {stdin_line, {ok, Line}} -> {ok, Line};
        {stdin_line, error} -> {error, nil}
    after TimeoutMs ->
        exit(Pid, kill),
        {error, nil}
    end.

%% Parse a JSON negotiation line and extract the "token" field.
%% Expects: {"token":"...","protocol":1} or similar.
%% Uses json (OTP 27+) or jsx/jiffy if available, falling back to
%% a simple regex extraction.
%% Returns {ok, Token} or {error, nil}.
parse_json_token(Line) ->
    case parse_json_token_json(Line) of
        {ok, Token} -> {ok, Token};
        {error, _} -> parse_json_token_regex(Line)
    end.

parse_json_token_json(Line) ->
    try
        {ok, Map} = json:decode(Line),
        case maps:find(<<"token">>, Map) of
            {ok, Token} when is_binary(Token) -> {ok, Token};
            _ -> {error, nil}
        end
    catch
        _:_ -> {error, nil}
    end.

parse_json_token_regex(Line) ->
    case re:run(Line, <<"\"token\"\\s*:\\s*\"([^\"]+)\"">>,
                [{capture, [1], binary}]) of
        {match, [Token]} -> {ok, Token};
        _ -> {error, nil}
    end.
