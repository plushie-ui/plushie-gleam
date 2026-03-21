-module(plushie_test_pooled_ffi).

-export([put_pool_session/2, get_pool_session/0, erase_pool_session/0,
         wait_for_interact_response/1]).

put_pool_session(Pool, SessionId) ->
    put(plushie_pool_session, {Pool, SessionId}),
    nil.

get_pool_session() ->
    case get(plushie_pool_session) of
        undefined -> {error, nil};
        {Pool, SessionId} -> {ok, {Pool, SessionId}}
    end.

erase_pool_session() ->
    erase(plushie_pool_session),
    nil.

%% Wait for interact_step and interact_response messages from the pool.
%% Collects all interact_step event batches, then the final interact_response.
%% Returns the combined list of event maps.
wait_for_interact_response(Timeout) ->
    collect_interact_events(Timeout, []).

collect_interact_events(Timeout, Acc) ->
    receive
        %% Gleam record: {pool_event_interact_step, _SessionId, Data}
        {pool_event_interact_step, _SessionId, Data} ->
            Events = extract_events(Data),
            collect_interact_events(Timeout, Acc ++ Events);
        %% Gleam record: {pool_event_interact_response, _SessionId, Data}
        {pool_event_interact_response, _SessionId, Data} ->
            Events = extract_events(Data),
            Acc ++ Events;
        %% Also handle the raw tagged tuple from session_pool forwarding
        {plushie_pool_event, _SessionId, #{<<"type">> := <<"interact_step">>, <<"events">> := Events}} ->
            collect_interact_events(Timeout, Acc ++ Events);
        {plushie_pool_event, _SessionId, #{<<"type">> := <<"interact_response">>, <<"events">> := Events}} ->
            Acc ++ Events
    after Timeout ->
        Acc
    end.

extract_events(Data) when is_map(Data) ->
    case maps:find(<<"events">>, Data) of
        {ok, Events} when is_list(Events) -> Events;
        _ ->
            case maps:find(events, Data) of
                {ok, Events} when is_list(Events) -> Events;
                _ -> []
            end
    end;
extract_events(_) -> [].
