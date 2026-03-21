-module(toddy_test_cleanup_ffi).
-export([cleanup_dir/1]).

cleanup_dir(Path) ->
    Dir = binary_to_list(Path),
    case filelib:is_dir(Dir) of
        true ->
            {ok, Files} = file:list_dir(Dir),
            lists:foreach(fun(F) ->
                file:delete(filename:join(Dir, F))
            end, Files),
            file:del_dir(Dir);
        false ->
            ok
    end,
    nil.
