-module(toddy_snapshot_ffi).
-export([file_exists/1, read_file/1, write_file/2, mkdir_p/1, dir_name/1]).

file_exists(Path) ->
    filelib:is_file(binary_to_list(Path)).

read_file(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> {ok, Bin};
        {error, _} -> {error, nil}
    end.

write_file(Path, Content) ->
    ok = file:write_file(Path, Content),
    nil.

mkdir_p(Path) ->
    ok = filelib:ensure_dir(binary_to_list(Path) ++ "/"),
    nil.

dir_name(Path) ->
    list_to_binary(filename:dirname(binary_to_list(Path))).
