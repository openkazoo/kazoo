-ifndef(ACDC_QUEUE_MANAGER_HRL).

%% Used for shipping diagnostics to `acdc_queue_manager_diag'
-define(KEY_DIAGNOSTICS_PIDS, 'diagnostics_pids').
-define(DIAG(Message), ?DIAG(Message, [])).
-define(DIAG(Message, Args),
    maybe_send_diagnostics(fun() -> io_lib:format(Message, Args) end)
).

%% rr :: Round Robin
%% mi :: Most Idle
-type queue_strategy() :: 'rr' | 'mi'.

-type queue_strategy_state() :: queue:queue() | kz_term:ne_binaries().
-record(strategy_state, {
    agents :: queue_strategy_state(),
    ringing_agents = [] :: kz_term:ne_binaries(),
    busy_agents = [] :: kz_term:ne_binaries()
}).
-type strategy_state() :: #strategy_state{}.

-record(state, {
    ignored_member_calls = dict:new() :: dict:dict(),
    account_id :: kz_term:api_ne_binary(),
    queue_id :: kz_term:api_ne_binary(),
    supervisor :: kz_term:api_pid(),
    % round-robin | most-idle
    strategy = 'rr' :: queue_strategy(),
    % based on the strategy
    strategy_state = #strategy_state{} :: strategy_state(),
    % how many agent processes are available {AgentId, Count}
    known_agents = dict:new() :: dict:dict(),
    % allow caller into queue if no agents are logged in
    enter_when_empty = 'true' :: boolean(),
    moh :: kz_term:api_ne_binary(),
    % list of current members waiting
    current_member_calls = [] :: [kapps_call:call()],
    announcements_config = [] :: kz_term:proplist(),
    announcements_pids = #{} :: announcements_pids()
}).
-type mgr_state() :: #state{}.

-type agent_change() :: 'available' | 'ringing' | 'busy' | 'unavailable'.
-type agent_change_data() :: #{}.

-define(ACDC_QUEUE_MANAGER_HRL, 'true').
-endif.
