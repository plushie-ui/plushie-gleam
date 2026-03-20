-module(toddy_renderer_env_ffi).
-export([get_env/0]).

get_env() ->
    maps:from_list([{list_to_binary(K), list_to_binary(V)} || {K, V} <- os:env()]).
