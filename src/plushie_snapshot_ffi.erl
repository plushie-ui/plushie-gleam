-module(plushie_snapshot_ffi).
-export([file_exists/1, read_file/1, write_file/2, write_file_atomic/2,
         mkdir_p/1, dir_name/1]).

file_exists(Path) ->
    filelib:is_file(binary_to_list(Path)).

read_file(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> {ok, Bin};
        {error, _} -> {error, nil}
    end.

%% Direct write (kept for backward compat, but prefer write_file_atomic).
write_file(Path, Content) ->
    ok = file:write_file(Path, Content),
    nil.

%% Atomic write: write to a temp file in the same directory, then rename.
%% Prevents partial reads from concurrent tests.
write_file_atomic(Path, Content) ->
    PathStr = binary_to_list(Path),
    TmpPath = PathStr ++ ".tmp." ++ integer_to_list(erlang:unique_integer([positive])),
    ok = file:write_file(TmpPath, Content),
    ok = file:rename(TmpPath, PathStr),
    nil.

mkdir_p(Path) ->
    ok = filelib:ensure_dir(binary_to_list(Path) ++ "/"),
    nil.

dir_name(Path) ->
    list_to_binary(filename:dirname(binary_to_list(Path))).
