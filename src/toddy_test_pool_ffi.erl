-module(toddy_test_pool_ffi).

-export([monitor_process/1, demonitor_process/1, send_to_pid/2]).

monitor_process(Pid) ->
    erlang:monitor(process, Pid).

demonitor_process(Ref) ->
    erlang:demonitor(Ref, [flush]),
    nil.

send_to_pid(Pid, Msg) ->
    Pid ! Msg,
    nil.
