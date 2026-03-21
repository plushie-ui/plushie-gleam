-module(toddy_screenshot_ffi).
-export([write_binary_file/2, write_binary_file_atomic/2]).

write_binary_file(Path, Data) ->
    ok = file:write_file(Path, Data),
    nil.

%% Atomic write: write to a temp file then rename.
write_binary_file_atomic(Path, Data) ->
    PathStr = binary_to_list(Path),
    TmpPath = PathStr ++ ".tmp." ++ integer_to_list(erlang:unique_integer([positive])),
    ok = file:write_file(TmpPath, Data),
    ok = file:rename(TmpPath, PathStr),
    nil.
