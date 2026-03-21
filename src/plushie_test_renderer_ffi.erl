-module(plushie_test_renderer_ffi).

-export([msgpack_decode_dynamic/1, float_to_string/1, send_exit/1,
         deserialize_wire/2,
         put_renderer/1, get_renderer/0, erase_renderer/0]).

%% Decode msgpack bytes into an Erlang map (Dynamic-compatible).
msgpack_decode_dynamic(Bytes) ->
    case 'glepack@decode':value(Bytes) of
        {ok, {Value, _Rest}} ->
            {ok, glepack_value_to_term(Value)};
        {error, _} ->
            {error, nil}
    end.

glepack_value_to_term({string, S}) -> S;
glepack_value_to_term({integer, N}) -> N;
glepack_value_to_term({float, F}) -> F;
glepack_value_to_term({boolean, B}) -> B;
glepack_value_to_term(nil) -> nil;
glepack_value_to_term({binary, B}) -> B;
glepack_value_to_term({array, Items}) ->
    lists:map(fun glepack_value_to_term/1, Items);
glepack_value_to_term({map, Map}) ->
    maps:fold(fun(K, V, Acc) ->
        Acc#{glepack_value_to_term(K) => glepack_value_to_term(V)}
    end, #{}, Map);
glepack_value_to_term({extension, _, _}) -> nil;
glepack_value_to_term(Other) -> Other.

float_to_string(F) when is_float(F) ->
    list_to_binary(io_lib:format("~.10g", [F]));
float_to_string(I) when is_integer(I) ->
    list_to_binary(io_lib:format("~.10g", [float(I)])).

send_exit(Pid) ->
    exit(Pid, normal),
    nil.

%% Deserialize wire bytes to an Erlang map.
%% Format: json | msgpack (atoms matching protocol.Format constructors).
deserialize_wire(Bytes, json) ->
    case 'gleam_json_ffi':decode(Bytes) of
        {ok, Map} when is_map(Map) -> {ok, Map};
        {ok, _} -> {error, nil};
        {error, _} -> {error, nil}
    end;
deserialize_wire(Bytes, msgpack) ->
    case 'glepack@decode':value(Bytes) of
        {ok, {Value, _Rest}} ->
            Term = glepack_value_to_term(Value),
            case is_map(Term) of
                true -> {ok, Term};
                false -> {error, nil}
            end;
        {error, _} ->
            {error, nil}
    end.

%% Process dictionary helpers for storing the renderer Subject.
%% Used by headless/windowed backends to associate a renderer
%% actor with the calling test process.
put_renderer(Subject) ->
    put(plushie_test_renderer, Subject),
    nil.

get_renderer() ->
    case get(plushie_test_renderer) of
        undefined -> {error, nil};
        Subject -> {ok, Subject}
    end.

erase_renderer() ->
    erase(plushie_test_renderer),
    nil.
