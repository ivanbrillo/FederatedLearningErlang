-module(node).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-include("../helper/state.hrl").



init([MasterPid, MasterNode]) ->
    PythonPid = python_helper:init_python_process(),
    {ok, _Name} = python:call(PythonPid, node, register_handler, [self(), node()]),
    net_kernel:monitor_nodes(true),  % nodeup/nodedown messages
    State = #nstate{masterPid = MasterPid, masterNode = MasterNode, pythonPid = PythonPid},
    io:format("--- NODE ~p: Initialized correctly ---~n", [node()]),
    {ok, State}.


handle_call(check_status, _From, State) ->
    {reply, true, State};

handle_call(_Request, _From, State) ->
    {reply, not_implemented, State}.


handle_cast(load_db, State) ->
    Response = message_primitives:synch_message(State#nstate.pythonPid, load_db, null, db_ack),
    State#nstate.masterPid ! {db_ack, {self(), Response}},
    io:format("--- NODE ~p: Load DB completed ---~n", [node()]),
    {noreply, State};

handle_cast({initialize_model, Model}, State) ->
    message_primitives:synch_message(State#nstate.pythonPid, initialize, Model, initialize_ack),
    State#nstate.masterPid ! {initialize_ack, self()},
    io:format("--- NODE ~p: Initialization completed ---~n", [node()]),
    {noreply, State};

handle_cast({update_weights, Weights}, State) ->
    message_primitives:synch_message(State#nstate.pythonPid, update, Weights, weights_ack),
    State#nstate.masterPid ! {weights_ack, self()},
    io:format("--- NODE ~p: Weights updated successfully ---~n", [node()]),
    {noreply, State};

handle_cast(train, State) ->
    Response = message_primitives:synch_message(State#nstate.pythonPid, train, null, train_ack, 30000),
    State#nstate.masterPid ! {train_ack, {self(), Response}},
    io:format("--- NODE ~p: Training completed ---~n", [node()]),
    {noreply, State};

handle_cast({train_pipeline, Weights}, State) ->
    NewWeights = message_primitives:synch_message(State#nstate.pythonPid, train_pipeline, Weights, train_pipeline_ack),
    State#nstate.masterPid ! {train_pipeline_ack, {self(), NewWeights}},
    io:format("--- NODE ~p: Training Pipeline completed ---~n", [node()]),
    {noreply, State};

handle_cast(get_weights, State) ->
    Response = message_primitives:synch_message(State#nstate.pythonPid, get_weights, null, node_weights),
    State#nstate.masterPid ! {node_weights, {self(), Response}},
    io:format("--- NODE ~p: Weights returned ---~n", [node()]),
    {noreply, State}.

% the process will terminate if the master node is down for 5 minutes
handle_info({nodedown, MasterNode}, State) when MasterNode == State#nstate.masterNode ->
    io:format("--- NODE ~p: MASTER disconnected ---~n", [MasterNode]),
    TimerRef = erlang:send_after(300000, self(), terminate),  % 5 minutes
    {noreply, State#nstate{termination_timer = TimerRef}};

handle_info(terminate, State) ->
    {stop, normal, State};

handle_info({nodeup, MasterNode}, State) when MasterNode == State#nstate.masterNode ->
    io:format("--- NODE ~p: MASTER node reconnected.~n", [node()]),
    erlang:cancel_timer(State#nstate.termination_timer),
    {noreply, State};

handle_info(Info, State) ->
    io:format("--- NODE ~p: Received unhandled message ~p, ~p ---~n", [node(), Info, State#nstate.masterNode ]),
    {noreply, State}.


terminate(_Reason, State) ->
    io:format("--- NODE ~p: Terminating procedure ---~n", [node()]),
    python:stop(State#nstate.pythonPid),  % abort python process
    erlang:disconnect_node(State#nstate.masterNode),  % let know the master node that the node server is shutting down by disconnecting from it
    ok.