-module(toddy_screenshot_ffi).
-export([write_binary_file/2]).

write_binary_file(Path, Data) ->
    ok = file:write_file(Path, Data),
    nil.
