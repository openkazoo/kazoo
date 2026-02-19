-module(konami_leader).

-export([cache_or_fail/1]).

-export([spec/0]).
-export([start_link/0]).

-export([init/1]).
-export([elected/3]).
-export([surrendered/3]).
-export([from_leader/3]).
-export([handle_DOWN/3]).
-export([handle_leader_call/4]).
-export([handle_leader_cast/3]).
-export([handle_call/4]).
-export([handle_cast/3]).
-export([handle_info/3]).
-export([terminate/2]).
-export([code_change/4]).

-include("konami.hrl").

-record(state, {}).
-type state() :: #state{}.
-type shared_state() :: any().

-spec cache_or_fail(any()) -> boolean().
cache_or_fail(Key) ->
    amqp_leader_proc:leader_call(?MODULE, {'cache_or_fail', Key}).

-spec spec() -> kz_types:sup_child_spec().
spec() ->
    ?SUPER(?MODULE).

-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    amqp_leader:start_link(?MODULE, [node()], [], ?MODULE, [], []).

-spec init(_) -> {'ok', state()}.
init([]) ->
    {'ok', #state{}}.

-spec elected(state(), state(), shared_state()) -> {'ok', state(), state()}.
elected(State, _, _) ->
    {'ok', State, State}.

-spec surrendered(state(), any(), any()) -> {'ok', state()}.
surrendered(State, _, _) ->
    {'ok', State}.

-spec from_leader(any(), state(), shared_state()) -> {'ok', state()}.
from_leader(_Msg, State, _SharedState) ->
    {'ok', State}.

-spec handle_DOWN(atom(), state(), shared_state()) -> {'ok', state()}.
handle_DOWN(_Node, State, _SharedState) ->
    {'ok', State}.

-spec handle_leader_call(any(), kz_term:pid_ref(), state(), shared_state()) -> kz_types:handle_call_ret_state(state()).
handle_leader_call({'cache_or_fail', Key}, _From, State, _SharedState) ->
    Reply = konami_cache:cache_or_fail(Key),
    {'reply', Reply, State};
handle_leader_call(_Msg, _From, State, _SharedState) ->
    {'reply', {'error', 'unspecified'}, State}.

-spec handle_leader_cast(any(), state(), shared_state()) -> kz_types:handle_cast_ret_state(state()).
handle_leader_cast(_Msg, State, _SharedState) ->
    {'noreply', State}.

-spec handle_call(any(), kz_term:pid_ref(), state(), shared_state()) -> kz_types:handle_call_ret_state(state()).
handle_call(_Msg, _From, State, _SharedState) ->
    {'reply', {'error', 'unspecified'}, State}.

-spec handle_cast(any(), state(), shared_state()) -> kz_types:handle_info_ret_state(state()).
handle_cast(_Msg, State, _SharedState) ->
    {'noreply', State}.

-spec handle_info(any(), state(), shared_state()) -> kz_types:handle_info_ret_state(state()).
handle_info(_Msg, State, _SharedState) ->
    {'noreply', State}.

-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, _State) ->
    'ok'.

-spec code_change(any(), state(), shared_state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _SharedState, _Extra) ->
    {'ok', State}.
