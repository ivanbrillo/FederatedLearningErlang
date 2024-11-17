-module(master).
-behaviour(gen_server).

%% API
-export([start_link/0, get_nodes/0, load_db/0, initialize_nodes/0,
         distribute_model/0, distribute_weights/0, train/0, train/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-include("helper/state.hrl").

%% API functions
start_link() ->
    process_flag(trap_exit, true),
    Response = gen_server:start_link({local, erlang_master}, ?MODULE, [], []),
    initialize_nodes(),
    load_nodes(),
    Response.

load_nodes() ->
    gen_server:call(erlang_master, load_nodes, 10000).

get_nodes() ->
    gen_server:call(erlang_master, get_nodes).

load_db() ->
    gen_server:call(erlang_master, load_db).

initialize_nodes() ->
    gen_server:call(erlang_master, initialize_nodes, 20000).

distribute_model() ->
    gen_server:call(erlang_master, distribute_model).

distribute_weights() ->
    gen_server:call(erlang_master, distribute_weights).

train() ->
    gen_server:cast(erlang_master, {train, 1}).

train(NEpochs) ->
    gen_server:cast(erlang_master, {train, NEpochs}).

%% gen_server callbacks
init([]) ->
    io:format("--- MASTER: Starting erlang process ---~n"),
    
    PythonModel = python_helper:init_python_process(),
    PythonUI = python_helper:init_python_process(),
    State = #state{pythonModelPID = PythonModel, pythonUiPID = PythonUI},
    
    python_helper:python_register_handler(PythonModel, master, self()),
    python_helper:python_register_handler(PythonUI, ui, self()),

    {ok, State}.

handle_call(get_nodes, _From, State) ->
    Nodes = network_helper:get_cluster_nodes(),
    message_primitives:notify_ui(State#state.pythonUiPID, {nodes, Nodes}),
    {reply, Nodes, State};

handle_call(load_nodes, _From, State) ->
    Pids = master_utils:load_nodes(State#state.currentUpNodes, State#state.pythonModelPID),
    message_primitives:notify_ui(State#state.pythonUiPID, {loaded_nodes, Pids}),
    {reply, ok, State};

handle_call(load_db, _From, State) ->
    {PidNodes, _} = lists:unzip(State#state.currentUpNodes),
    {PidList, Infos} = master_utils:load_db(PidNodes, synch),
    message_primitives:notify_ui(State#state.pythonUiPID, {db_loaded, PidList}),
    {reply, {ok, Infos}, State};

handle_call(initialize_nodes, _From, State) ->
    InitializedNodes = network_helper:initialize_nodes(),
    net_kernel:monitor_nodes(true),
    message_primitives:notify_ui(State#state.pythonUiPID, {initialized_nodes, InitializedNodes}),
    {reply, {ok, InitializedNodes}, State#state{initialUpNodes = InitializedNodes, currentUpNodes = InitializedNodes}};

handle_call(distribute_model, _From, State) ->
    {PidNodes, _} = lists:unzip(State#state.currentUpNodes),
    ResponseList = master_utils:distribute_model(State#state.pythonModelPID, PidNodes, synch),
    message_primitives:notify_ui(State#state.pythonUiPID, {distributed_nodes, ResponseList}),
    {reply, {ok, ResponseList}, State};

handle_call(distribute_weights, _From, State) ->
    {PidNodes, _} = lists:unzip(State#state.currentUpNodes),
    ResponseList = master_utils:distribute_model_weights(State#state.pythonModelPID, PidNodes, synch),
    message_primitives:notify_ui(State#state.pythonUiPID, {weights_updated_nodes, ResponseList}),
    {reply, {ok, ResponseList}, State}.

handle_cast({train, NEpochs}, State) ->
    {PidNodes, _} = lists:unzip(State#state.currentUpNodes),
    Nodes = master_utils:train(NEpochs, State#state.pythonModelPID, PidNodes, State#state.pythonUiPID),
    message_primitives:notify_ui(State#state.pythonUiPID, {train_completed, Nodes}),
    {noreply, State}.

handle_info({nodeup, Node, _}, State) ->
    io:format("--- MASTER: Node ~p connected, initializing---~n", [Node]),
    Pids = master_utils:load_nodes([Node], State#state.pythonModelPID) ++ State#state.currentUpNodes,
    {noreply, State#state{currentUpNodes = Pids}};

handle_info({nodedown, Node}, State) ->
    io:format("--- MASTER: Node ~p disconnected ---~n", [Node]),
    UpdatedUpNodes = lists:keydelete(Node, 2, State#state.currentUpNodes),
    {noreply, State#state{currentUpNodes = UpdatedUpNodes}};

handle_info({python_unhandled, Cause}, State) ->   % TODO: to be removed
    io:format("--- MASTER: Python received unhandled message: ~p ---~n", [Cause]),
    {noreply, State};

handle_info(Info, State) ->
    io:format("--- MASTER: received unhandled message: ~p ---~n", [Info]),
    {noreply, State}.

% called from supervisor shutdown
terminate(_Reason, State) ->
    io:format("--- MASTER: Terminating Procedure ---~n"),
    python:stop(State#state.pythonModelPID),      % TODO: possible shutdown procedure (eg. save python model)
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.