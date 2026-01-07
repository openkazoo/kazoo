%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2022, 2600Hz
%%% @author Dialwave, Inc. (Rob Nichols)
%%% @doc Karls Hackity Hack....
%%% We want to block during startup until we have a AMQP connection
%%% but due to the way `kz_amqp_mgr' is structured we can't block in
%%% init there.  So this module will bootstrap `kz_amqp_mgr'
%%% and block until a connection becomes available, after that it
%%% removes itself.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_amqp_bootstrap).
-behaviour(gen_server).

-export([start_link/0]).
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-include("kz_amqp_util.hrl").

-define(SERVER, ?MODULE).

-record(state, {}).
-type state() :: #state{}.

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the server.
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_server:start_link({'local', ?SERVER}, ?MODULE, [], []).

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Initializes the server.
%% @end
%%------------------------------------------------------------------------------
-spec init([]) -> {'ok', state(), timeout()}.
init([]) ->
    kz_util:put_callid(?DEFAULT_LOG_SYSTEM_ID),
    process_config(),
    lager:info("waiting for first amqp connection..."),
    kz_amqp_connections:wait_for_available(),
    timer:sleep(2 * ?MILLISECONDS_IN_SECOND),
    kz_amqp_util:targeted_exchange(),
    {'ok', #state{}, 100}.

%%------------------------------------------------------------------------------
%% @doc Handling call messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call(_Request, _From, State) ->
    {'reply', {'error', 'not_implemented'}, State}.

%%------------------------------------------------------------------------------
%% @doc Handling cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast(_Msg, State) ->
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc Handling all non call/cast messages.
%% @end
%%------------------------------------------------------------------------------
-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info('timeout', State) ->
    _ = kz_amqp_sup:stop_bootstrap(),
    {'noreply', State};
handle_info(_Info, State) ->
    lager:debug("unhandled message: ~p", [_Info]),
    {'noreply', State}.

%%------------------------------------------------------------------------------
%% @doc This function is called by a `gen_server' when it is about to
%% terminate. It should be the opposite of `Module:init/1' and do any
%% necessary cleaning up. When it returns, the `gen_server' terminates
%% with Reason. The return value is ignored.
%% @end
%%------------------------------------------------------------------------------
-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _State) ->
    lager:debug("amqp bootstrap terminating: ~p", [_Reason]).

%%------------------------------------------------------------------------------
%% @doc Convert process state when code is changed.
%% @end
%%------------------------------------------------------------------------------
-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
process_config() ->
    Zones = kz_config:get_zones_config(),
    lists:foreach(fun process_zone/1, Zones).

-spec process_zone({kz_term:ne_binary(), kz_term:proplist()}) -> 'ok'.
process_zone({ZoneNameBin, ZoneConfig}) when is_list(ZoneConfig) ->
    IsLocal = kz_term:is_true(props:get_value(<<"local">>, ZoneConfig, 'false')),
    Brokers = kz_config:get_zone_amqp_uris(ZoneConfig),
    ZoneIdentifier =
        case IsLocal of
            'true' ->
                'local';
            'false' ->
                kz_term:to_atom(ZoneNameBin, 'true')
        end,
    lists:foreach(fun(Broker) -> kz_amqp_connections:add(Broker, ZoneIdentifier) end, Brokers),
    'ok';
process_zone(_) ->
    'ok'.
