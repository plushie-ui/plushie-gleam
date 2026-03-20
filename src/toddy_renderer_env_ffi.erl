-module(toddy_renderer_env_ffi).
-export([get_env/0, entries_to_port_env/1]).

get_env() ->
    maps:from_list([{list_to_binary(K), list_to_binary(V)} || {K, V} <- os:env()]).

entries_to_port_env(Entries) ->
    lists:map(fun
        ({set, Key, Value}) -> {binary_to_list(Key), binary_to_list(Value)};
        ({unset, Key}) -> {binary_to_list(Key), false}
    end, Entries).
