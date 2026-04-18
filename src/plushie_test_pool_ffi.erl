-module(plushie_test_pool_ffi).

-export([monitor_process/1, demonitor_process/1, send_to_pid/2,
         pid_to_string/1, string_starts_with/2,
         get_pool/0, put_pool/1, extract_down_pid/1]).

monitor_process(Pid) ->
    erlang:monitor(process, Pid).

demonitor_process(Ref) ->
    erlang:demonitor(Ref, [flush]),
    nil.

send_to_pid(Pid, Msg) ->
    Pid ! Msg,
    nil.

pid_to_string(Pid) ->
    list_to_binary(pid_to_list(Pid)).

string_starts_with(Str, Prefix) ->
    PrefixSize = byte_size(Prefix),
    case Str of
        <<Prefix:PrefixSize/binary, _/binary>> -> true;
        _ -> false
    end.

%% Cache the session pool subject in persistent_term so it persists
%% across test processes within a single VM instance.
get_pool() ->
    try persistent_term:get(plushie_test_pool) of
        Pool -> {ok, Pool}
    catch
        error:badarg -> {error, nil}
    end.

put_pool(Pool) ->
    persistent_term:put(plushie_test_pool, Pool),
    nil.

%% Extract the Pid from a `{'DOWN', MonitorRef, process, Pid, Reason}` message.
%% Returns {ok, Pid} for matching tuples, {error, nil} otherwise.
extract_down_pid({'DOWN', _Ref, process, Pid, _Reason}) when is_pid(Pid) ->
    {ok, Pid};
extract_down_pid(_) ->
    {error, nil}.
