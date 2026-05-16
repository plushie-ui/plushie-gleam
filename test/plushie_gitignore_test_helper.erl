-module(plushie_gitignore_test_helper).
-export([
    setup_non_git_dir/0,
    setup_git_repo_with_gitignore/1,
    run_in_dir/2
]).

setup_non_git_dir() ->
    Dir = tmpdir("plushie-no-git-"),
    list_to_binary(Dir).

setup_git_repo_with_gitignore(Contents) when is_binary(Contents) ->
    setup_git_repo_with_gitignore(binary_to_list(Contents));
setup_git_repo_with_gitignore(Contents) when is_list(Contents) ->
    Dir = tmpdir("plushie-git-"),
    %% git init must succeed; if not, the test will reveal it.
    {0, _} = sh(Dir, "git", ["init", "-q"]),
    ok = file:write_file(filename:join(Dir, ".gitignore"), Contents),
    list_to_binary(Dir).

run_in_dir(Dir, Work) when is_binary(Dir) ->
    run_in_dir(binary_to_list(Dir), Work);
run_in_dir(Dir, Work) ->
    {ok, Prev} = file:get_cwd(),
    try
        ok = file:set_cwd(Dir),
        _ = Work(),
        nil
    after
        _ = file:set_cwd(Prev)
    end.

tmpdir(Prefix) ->
    Base = case os:getenv("TMPDIR") of
        false -> "/tmp";
        "" -> "/tmp";
        Value -> Value
    end,
    Unique = integer_to_list(erlang:unique_integer([positive])),
    Dir = filename:join(Base, Prefix ++ Unique),
    ok = filelib:ensure_dir(filename:join(Dir, "dummy")),
    Dir.

sh(Dir, Program, Args) ->
    case os:find_executable(Program) of
        false -> {error, "not found"};
        Path ->
            Port = erlang:open_port(
                {spawn_executable, Path},
                [exit_status, use_stdio, stderr_to_stdout,
                 {cd, Dir}, {args, Args}]
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
