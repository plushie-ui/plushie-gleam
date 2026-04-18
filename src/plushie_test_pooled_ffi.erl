-module(plushie_test_pooled_ffi).

-export([put_pool_session/2, get_pool_session/0, erase_pool_session/0,
         receive_interact_message/1]).

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

%% Receive a single interact_step or interact_response message.
%%
%% The headless renderer emits one or more `interact_step` messages during
%% an interaction (each after an iced event batch) and blocks waiting for a
%% fresh snapshot between each step. The final message in the sequence is
%% `interact_response`. The caller processes the events from each step,
%% sends a snapshot back to the renderer, then calls this again for the
%% next message until it sees a `response`.
%%
%% Returns one of:
%%   {step, Events}     -- intermediate step; caller must send a snapshot
%%                         before calling this again
%%   {response, Events} -- final response; the interaction is complete
%%   timeout            -- no message arrived before the deadline (the
%%                         renderer is likely stuck or crashed)
receive_interact_message(Timeout) ->
    receive
        {pool_event_interact_step, _SessionId, Data} ->
            {interact_step, extract_events(Data)};
        {pool_event_interact_response, _SessionId, Data} ->
            {interact_response, extract_events(Data)};
        %% Also handle the raw tagged tuple from session_pool forwarding
        %% in case the Gleam record wrapper is bypassed.
        {plushie_pool_event, _SessionId,
            #{<<"type">> := <<"interact_step">>, <<"events">> := Events}} ->
            {interact_step, Events};
        {plushie_pool_event, _SessionId,
            #{<<"type">> := <<"interact_response">>, <<"events">> := Events}} ->
            {interact_response, Events};
        {plushie_pool_event, _SessionId,
            #{<<"type">> := <<"interact_response">>}} ->
            {interact_response, []}
    after Timeout ->
        interact_timeout
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
