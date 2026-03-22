-module(plushie_socket_adapter_ffi).
-behaviour(gen_server).

-export([start/2]).
-export([init/1, handle_info/2, handle_cast/2, handle_call/3, terminate/2]).

%% Start the socket adapter. Connects to the given address and returns
%% a Gleam Subject(IoStreamMessage) that the Bridge can send to.
%%
%% Format is the Gleam protocol.Format type:
%%   msgpack atom -> {packet, 4}
%%   json atom    -> {packet, line}
start(Addr, Format) ->
    SocketOpts = socket_options(Format),
    case connect(Addr, SocketOpts) of
        {ok, Socket} ->
            %% Create a Gleam subject in this process's context.
            %% We'll start the gen_server and transfer the subject.
            case gen_server:start(?MODULE, {Socket}, []) of
                {ok, Pid} ->
                    %% Create a subject owned by the gen_server process.
                    %% We do this by calling into the gen_server.
                    Subject = gen_server:call(Pid, get_subject),
                    {ok, Subject};
                {error, Reason} ->
                    {error, format_error(Reason)}
            end;
        {error, Reason} ->
            {error, format_error(Reason)}
    end.

socket_options(msgpack) ->
    [binary, {packet, 4}, {active, true}];
socket_options(json) ->
    [binary, {packet, line}, {active, true}].

connect(Addr, Opts) ->
    case parse_addr(Addr) of
        {unix, Path} ->
            gen_tcp:connect({local, Path}, 0, Opts);
        {tcp, Host, Port} ->
            gen_tcp:connect(Host, Port, Opts)
    end.

parse_addr(<<$/, _/binary>> = Path) ->
    {unix, binary_to_list(Path)};
parse_addr(<<$:, PortStr/binary>>) ->
    {tcp, "127.0.0.1", binary_to_integer(PortStr)};
parse_addr(Addr) ->
    case binary:split(Addr, <<":">>) of
        [Host, PortStr] when Host =/= <<>> ->
            {tcp, binary_to_list(Host), binary_to_integer(PortStr)};
        _ ->
            {unix, binary_to_list(Addr)}
    end.

format_error(Reason) ->
    list_to_binary(io_lib:format("~p", [Reason])).

%% -- gen_server callbacks ----------------------------------------------------

init({Socket}) ->
    %% Create a Gleam subject for this process.
    %% A Gleam subject is {subject, OwnerPid, UniqueTag}.
    Tag = erlang:unique_integer([positive, monotonic]),
    Subject = {subject, self(), Tag},
    {ok, #{socket => Socket, bridge => undefined, subject => Subject, tag => Tag}}.

handle_call(get_subject, _From, #{subject := Subject} = State) ->
    {reply, Subject, State};
handle_call(_Req, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Bridge sends IoStreamBridge(bridge_subject) to our Subject.
%% At the Erlang level this arrives as {Tag, {iostream_bridge, BridgeSubject}}.
handle_info({Tag, {iostream_bridge, BridgeSubject}}, #{tag := Tag} = State) ->
    {noreply, State#{bridge := BridgeSubject}};

%% Bridge sends IoStreamSend(data) to our Subject.
%% At the Erlang level: {Tag, {iostream_send, Data}}.
handle_info({Tag, {iostream_send, Data}}, #{tag := Tag, socket := Socket} = State) ->
    case gen_tcp:send(Socket, Data) of
        ok -> {noreply, State};
        {error, _Reason} -> {stop, normal, State}
    end;

%% TCP data from the socket -- forward to bridge as IoStreamData.
handle_info({tcp, Socket, Data}, #{socket := Socket, bridge := Bridge} = State) ->
    case Bridge of
        undefined -> ok;
        _ ->
            %% Send {BridgeTag, {iostream_data, Data}} to the bridge.
            send_to_subject(Bridge, {iostream_data, Data})
    end,
    {noreply, State};

%% TCP closed.
handle_info({tcp_closed, Socket}, #{socket := Socket, bridge := Bridge} = State) ->
    case Bridge of
        undefined -> ok;
        _ -> send_to_subject(Bridge, iostream_closed)
    end,
    {stop, normal, State};

%% TCP error.
handle_info({tcp_error, Socket, _Reason}, #{socket := Socket, bridge := Bridge} = State) ->
    case Bridge of
        undefined -> ok;
        _ -> send_to_subject(Bridge, iostream_closed)
    end,
    {stop, normal, State};

handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, #{socket := Socket}) ->
    gen_tcp:close(Socket),
    ok;
terminate(_Reason, _State) ->
    ok.

%% Send a message to a Gleam Subject.
%% Subject = {subject, OwnerPid, Tag}
send_to_subject({subject, Pid, Tag}, Msg) ->
    Pid ! {Tag, Msg}.
