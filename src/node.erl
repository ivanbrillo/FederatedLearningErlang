-module(node).
-behaviour(gen_server).

%% API
-export([start_link/1, load_db/1, initialize_model/2, update_weights/2,
         train/1, get_weights/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% API functions
start_link(MasterPid) ->
    gen_server:start(?MODULE, [MasterPid], []).

load_db(Pid) ->
    gen_server:cast(Pid, load_db).

initialize_model(Pid, Model) ->
    gen_server:cast(Pid, {initialize_model, Model}).

update_weights(Pid, Weights) ->
    gen_server:cast(Pid, {update_weights, Weights}).

train(Pid) ->
    gen_server:cast(Pid, train).

get_weights(Pid) ->
    gen_server:cast(Pid, get_weights).

%% gen_server callbacks
init([MasterPid]) ->
    PythonCodePath = code:priv_dir(ds_proj),
    {ok, PythonPid} = python:start([{python_path, PythonCodePath}, {python, "python3"}]),
    Response = python:call(PythonPid, node, register_handler, [self(), node()]),
    io:format("~p~n", [Response]),
    {ok, #{master_pid => MasterPid, python_pid => PythonPid}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(load_db, State = #{master_pid := MasterPid, python_pid := PythonPid}) ->
    Response = message_primitives:synch_message(PythonPid, load_db, null, db_ack),
    MasterPid ! {db_ack, {self(), Response}},
    io:format("NODE ~p, Load DB completed~n", [node()]),
    {noreply, State};

handle_cast({initialize_model, Model}, State = #{master_pid := MasterPid, python_pid := PythonPid}) ->
    message_primitives:synch_message(PythonPid, initialize, Model, initialize_ack),
    MasterPid ! {initialize_ack, self()},
    io:format("NODE ~p, Initialization completed~n", [node()]),
    {noreply, State};

handle_cast({update_weights, Weights}, State = #{master_pid := MasterPid, python_pid := PythonPid}) ->
    message_primitives:synch_message(PythonPid, update, Weights, weights_ack),
    MasterPid ! {weights_ack, self()},
    io:format("NODE ~p, Weights updated successfully~n", [node()]),
    {noreply, State};

handle_cast(train, State = #{master_pid := MasterPid, python_pid := PythonPid}) ->
    Response = message_primitives:synch_message(PythonPid, train, null, train_ack),
    MasterPid ! {train_ack, {self(), Response}},
    io:format("NODE ~p, Training completed~n", [node()]),
    {noreply, State};

handle_cast(get_weights, State = #{master_pid := MasterPid, python_pid := PythonPid}) ->
    Response = message_primitives:synch_message(PythonPid, get_weights, null, node_weights),
    MasterPid ! {node_weights, {self(), Response}},
    io:format("NODE ~p, Weights returned~n", [node()]),
    {noreply, State}.

handle_info(_Info, State) ->
    io:format("Invalid message discarded in node: ~p~n", [_Info]),
    {noreply, State}.

terminate(_Reason, #{python_pid := PythonPid}) ->
    python:stop(PythonPid),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.