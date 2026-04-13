%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2022, 2600Hz
%%% @doc
%%% @end
%%%-----------------------------------------------------------------------------
-module(fax_sup).

-behaviour(supervisor).

-include("fax.hrl").

-define(SERVER, ?MODULE).

-export([start_link/0]).
-export([cache_proc/0]).
-export([listener_proc/0]).
-export([smtp_sessions/0]).
-export([init/1]).


-define(ORIGIN_BINDINGS, [[{'db', ?KZ_FAXES_DB}, {'type', <<"faxbox">>}]
                         ]).

-define(CACHE_PROPS, [{'origin_bindings', ?ORIGIN_BINDINGS}
                     ]).

-define(SMTP_OPTIONS, [{'port', ?SMTP_PORT}
                       %% in case we want to make the settings constant per execution
                       %% ,{'sessionoptions', [?SMTP_CALLBACK_OPTIONS]}
                      ]).

-define(SMTP_CHILD, gen_smtp_server:child_spec('gen_smtp_server', 'fax_smtp', ?SMTP_OPTIONS)).

-define(CHILDREN, [?WORKER('fax_init')
                  ,?CACHE_ARGS(?CACHE_NAME, ?CACHE_PROPS)
                  ,?SUPER('fax_requests_sup')
                  ,?SUPER('fax_jobs_sup')
                  ,?SUPER('fax_worker_sup')
                  ,?WORKER('fax_global_shared_listener')
                  ,?WORKER('fax_shared_listener')
                  ,?WORKER('fax_monitor')
                  ,?SMTP_CHILD
                  ]).

%%==============================================================================
%% API functions
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc Starts the supervisor.
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    supervisor:start_link({'local', ?SERVER}, ?MODULE, []).

-spec cache_proc() -> {'ok', ?CACHE_NAME}.
cache_proc() ->
    {'ok', ?CACHE_NAME}.

-spec listener_proc() -> {'ok', pid()}.
listener_proc() ->
    [P] = [P || {Mod, P, _, _} <- supervisor:which_children(?SERVER),
                Mod =:= 'fax_listener'],
    {'ok', P}.

-spec smtp_sessions() -> non_neg_integer().
smtp_sessions() ->
    Sessions = gen_smtp_server:sessions('gen_smtp_server'),
    length(Sessions).

%%==============================================================================
%% Supervisor callbacks
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc Whenever a supervisor is started using `supervisor:start_link/[2,3]',
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%% @end
%%------------------------------------------------------------------------------
-spec init(any()) -> kz_types:sup_init_ret().
init([]) ->
    kz_util:set_startup(),
    RestartStrategy = 'one_for_one',
    MaxRestarts = 5,
    MaxSecondsBetweenRestarts = 25,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {'ok', {SupFlags, ?CHILDREN}}.
