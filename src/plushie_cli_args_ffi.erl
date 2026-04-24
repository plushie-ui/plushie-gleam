-module(plushie_cli_args_ffi).
-export([
    has_flag/2,
    get_flag_value/2
]).

has_flag(Flag, Args) ->
    find_flag(to_list(Flag), Args).

get_flag_value(Flag, Args) ->
    find_flag_value(to_list(Flag), Args).

find_flag(_Flag, []) ->
    false;
find_flag(_Flag, [Arg | _Rest]) when Arg =:= "--"; Arg =:= <<"--">> ->
    false;
find_flag(Flag, [Arg | Rest]) ->
    case to_list(Arg) of
        Flag -> true;
        _ -> find_flag(Flag, Rest)
    end.

find_flag_value(_Flag, []) ->
    {error, nil};
find_flag_value(_Flag, [Arg | _Rest]) when Arg =:= "--"; Arg =:= <<"--">> ->
    {error, nil};
find_flag_value(Flag, [Arg | Rest]) ->
    ArgStr = to_list(Arg),
    case ArgStr of
        Flag ->
            value_after_flag(Rest);
        _ ->
            Prefix = Flag ++ "=",
            case lists:prefix(Prefix, ArgStr) of
                true -> {ok, list_to_binary(lists:nthtail(length(Prefix), ArgStr))};
                false -> find_flag_value(Flag, Rest)
            end
    end.

value_after_flag([]) ->
    {error, nil};
value_after_flag([Arg | _Rest]) ->
    ArgStr = to_list(Arg),
    case ArgStr of
        "--" -> {error, nil};
        [$-, $- | _] -> {error, nil};
        _ -> {ok, list_to_binary(ArgStr)}
    end.

to_list(Value) when is_binary(Value) ->
    binary_to_list(Value);
to_list(Value) ->
    Value.
