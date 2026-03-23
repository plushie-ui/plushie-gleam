-module(plushie_config_ffi).
-export([
    read_config/1
]).

%% Read a key from the [plushie] section of gleam.toml.
%% Returns {ok, Value} or {error, nil}.
%%
%% Supports three value forms:
%%   key = "string"          -> {ok, <<"string">>}
%%   key = ["a", "b"]        -> {ok, [<<"a">>, <<"b">>]}
%%   (missing)               -> {error, nil}
%%
%% Looks for gleam.toml in the current directory.
read_config(Key) when is_binary(Key) ->
    case file:read_file("gleam.toml") of
        {ok, Content} ->
            find_in_section(Key, Content);
        {error, _} ->
            {error, nil}
    end.

%% Find a key in the [plushie] section of TOML content.
find_in_section(Key, Content) ->
    Lines = binary:split(Content, <<"\n">>, [global]),
    find_section(Key, Lines, false).

find_section(_Key, [], _InSection) ->
    {error, nil};
find_section(Key, [Line | Rest], InSection) ->
    Trimmed = string:trim(binary_to_list(Line)),
    case Trimmed of
        %% New section header
        [$[ | _] ->
            case Trimmed of
                "[plushie]" ->
                    find_section(Key, Rest, true);
                _ ->
                    case InSection of
                        true ->
                            %% Hit a different section, stop
                            {error, nil};
                        false ->
                            find_section(Key, Rest, false)
                    end
            end;
        %% Empty or comment
        "" ->
            find_section(Key, Rest, InSection);
        [$# | _] ->
            find_section(Key, Rest, InSection);
        _ when InSection ->
            KeyStr = binary_to_list(Key),
            case parse_kv(Trimmed) of
                {KeyStr, Value} ->
                    {ok, Value};
                _ ->
                    find_section(Key, Rest, InSection)
            end;
        _ ->
            find_section(Key, Rest, InSection)
    end.

%% Parse "key = value" from a trimmed line.
%% Returns {KeyStr, Value} or false.
parse_kv(Line) ->
    case string:split(Line, "=", leading) of
        [KeyPart, ValuePart] ->
            K = string:trim(KeyPart),
            V = string:trim(ValuePart),
            case parse_value(V) of
                {ok, Parsed} -> {K, Parsed};
                error -> false
            end;
        _ ->
            false
    end.

%% Parse a TOML value: "string" or ["a", "b"].
parse_value([$" | Rest]) ->
    %% String value: strip trailing quote
    case lists:reverse(Rest) of
        [$" | Inner] ->
            {ok, list_to_binary(lists:reverse(Inner))};
        _ ->
            error
    end;
parse_value([$[ | Rest]) ->
    %% Array value: strip trailing bracket, split on comma, parse each
    case lists:reverse(Rest) of
        [$] | Inner] ->
            Items = string:split(lists:reverse(Inner), ",", all),
            Parsed = lists:filtermap(fun(Item) ->
                T = string:trim(Item),
                case T of
                    [$" | R] ->
                        case lists:reverse(R) of
                            [$" | S] ->
                                {true, list_to_binary(lists:reverse(S))};
                            _ ->
                                false
                        end;
                    "" ->
                        false;
                    _ ->
                        false
                end
            end, Items),
            {ok, Parsed};
        _ ->
            error
    end;
parse_value(_) ->
    error.
