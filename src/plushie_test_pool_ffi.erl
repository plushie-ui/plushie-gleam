-module(plushie_test_pool_ffi).

-export([monitor_process/1, demonitor_process/1, send_to_pid/2,
         pid_to_string/1, string_starts_with/2]).

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
