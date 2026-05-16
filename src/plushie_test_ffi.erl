-module(plushie_test_ffi).

-export([
    atom_count/0,
    attach_bridge_update_telemetry_probe/2,
    bridge_update_telemetry_probe_handler/4,
    bump_render_count/0,
    collect_stream_values/1,
    identity/1,
    read_render_count/0,
    reset_render_count/0,
    unknown_telemetry_event/0
]).

%% Per-process counter used by widget cache_key tests to observe
%% whether `view` was actually invoked. Lives in the process
%% dictionary so the test can read it without threading state.
bump_render_count() ->
    Current = case erlang:get(plushie_test_render_count) of
        undefined -> 0;
        N -> N
    end,
    erlang:put(plushie_test_render_count, Current + 1),
    nil.

read_render_count() ->
    case erlang:get(plushie_test_render_count) of
        undefined -> 0;
        N -> N
    end.

reset_render_count() ->
    erlang:erase(plushie_test_render_count),
    nil.

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

atom_count() ->
    erlang:system_info(atom_count).

unknown_telemetry_event() ->
    unknown_telemetry_event.

attach_bridge_update_telemetry_probe(HandlerId, Handler) ->
    Result = telemetry:attach(
        HandlerId,
        [plushie, bridge, update],
        fun ?MODULE:bridge_update_telemetry_probe_handler/4,
        Handler
    ),
    case Result of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.

bridge_update_telemetry_probe_handler(_, _, _, Handler) ->
    Handler().
