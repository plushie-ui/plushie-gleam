-module(toddy_test_ffi).

-export([collect_stream_values/1, identity/1]).

%% Run a stream work function, collecting emitted values in order.
%% The emit callback sends values to this process. We drain the
%% mailbox after the work function returns.
%% Returns {EmittedValues, FinalReturnValue}.
collect_stream_values(WorkFn) ->
    Ref = make_ref(),
    Self = self(),
    Emit = fun(Value) ->
        Self ! {stream_emit, Ref, Value},
        nil
    end,
    FinalValue = WorkFn(Emit),
    Values = drain_stream(Ref, []),
    {Values, FinalValue}.

drain_stream(Ref, Acc) ->
    receive
        {stream_emit, Ref, Value} ->
            drain_stream(Ref, [Value | Acc])
    after 0 ->
        lists:reverse(Acc)
    end.

%% Identity function for type coercion (types are erased at runtime).
identity(X) -> X.
