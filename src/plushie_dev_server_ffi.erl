-module(plushie_dev_server_ffi).
-export([extract_file_path/1, find_changed_modules/2]).

%% Extract file path from a file_system event tuple.
%% file_system sends: {file_event, WatcherPid, {Path, Events}}
extract_file_path({file_event, _Pid, {Path, _Events}}) when is_list(Path) ->
    {ok, list_to_binary(Path)};
extract_file_path({file_event, _Pid, {Path, _Events}}) when is_binary(Path) ->
    {ok, Path};
extract_file_path(_) ->
    {error, nil}.

%% Compare two lists of {ModuleAtom, Mtime} tuples and return the
%% module atoms that are new or have different mtimes.
find_changed_modules(OldList, NewList) ->
    OldMap = maps:from_list(OldList),
    lists:filtermap(fun({Mod, Mtime}) ->
        case maps:find(Mod, OldMap) of
            {ok, Mtime} -> false;  % Same mtime -- unchanged
            _ -> {true, Mod}       % New or different mtime
        end
    end, NewList).
