-module(plushie_gitignore_ffi).
-export([status/1]).

%% Returns one of:
%%   not_in_git_repo - cwd is not inside a git work tree (or git missing)
%%   ignored         - path is matched by .gitignore
%%   not_ignored     - path is not matched by .gitignore
status(Path) when is_binary(Path) ->
    status(binary_to_list(Path));
status(Path) when is_list(Path) ->
    case in_git_work_tree() of
        false -> not_in_git_repo;
        true ->
            case is_ignored(Path) of
                true -> ignored;
                false -> not_ignored
            end
    end.

in_git_work_tree() ->
    case run_git(["rev-parse", "--is-inside-work-tree"]) of
        {0, Output} ->
            string:trim(Output) =:= "true";
        _ ->
            false
    end.

is_ignored(Path) ->
    %% Append a trailing slash so git treats the path as a directory.
    %% Without it, a `/bin/` pattern in .gitignore won't match `bin`
    %% when the directory doesn't yet exist on disk.
    DirPath = case lists:reverse(Path) of
        [$/ | _] -> Path;
        _ -> Path ++ "/"
    end,
    case run_git(["check-ignore", "-q", "--", DirPath]) of
        {0, _} -> true;
        _ -> false
    end.

run_git(Args) ->
    case os:find_executable("git") of
        false ->
            {error, "git not found"};
        GitPath ->
            Port = erlang:open_port(
                {spawn_executable, GitPath},
                [exit_status, use_stdio, stderr_to_stdout, {args, Args}]
            ),
            collect(Port, [])
    end.

collect(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect(Port, [Acc, Data]);
        {Port, {exit_status, Status}} ->
            {Status, lists:flatten(Acc)}
    after 5000 ->
        catch port_close(Port),
        {error, "timed out"}
    end.
