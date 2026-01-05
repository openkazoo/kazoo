-ifndef(ACDC_QUEUE_MANAGER_HRL).

%% rr :: Round Robin
%% mi :: Most Idle
-type queue_strategy() :: 'rr' | 'mi' | 'sbrr' | 'all'.

% skill keys must be alphabetically sorted
-type sbrr_skill_map() :: #{kz_term:ne_binaries() := sets:set()}.
-type sbrr_id_map() :: #{kz_term:ne_binary() := kz_term:ne_binary()}.
% maps agent IDs to assigned call IDs
-type sbrr_strategy_state() :: #{
    agent_id_map := sbrr_id_map(),
    % maps assigned call IDs to agent IDs
    call_id_map := sbrr_id_map(),
    rr_queue := pqueue4:queue(),
    skill_map := sbrr_skill_map()
}.

-type queue_strategy_state() :: pqueue4:queue() | kz_term:ne_binaries() | sbrr_strategy_state().
-type ss_details() :: {non_neg_integer(), 'ringing' | 'busy' | 'undefined'}.
-record(strategy_state, {
    agents :: queue_strategy_state(),
    %% details include # of agent processes and availability
    details = dict:new() :: dict:dict(),
    ringing_agents = [] :: kz_term:ne_binaries(),
    busy_agents = [] :: kz_term:ne_binaries()
}).
-type strategy_state() :: #strategy_state{}.

-record(state, {
    ignored_member_calls = dict:new() :: dict:dict(),
    account_id :: api_kz_term:ne_binary(),
    queue_id :: api_kz_term:ne_binary(),
    supervisor :: kz_term:api_pid(),
    % round-robin | most-idle
    strategy = 'rr' :: queue_strategy(),
    % based on the strategy
    strategy_state = #strategy_state{} :: strategy_state(),
    % allow caller into queue if no agents are logged in
    enter_when_empty = 'true' :: boolean(),
    moh :: api_kz_term:ne_binary(),
    % ordered list of current members waiting
    current_member_calls = [] :: list(),
    announcements_config = [] :: kz_term:proplist(),
    announcements_pids = #{} :: announcements_kz_term:pids(),
    registered_callbacks = [] :: list()
}).
-type mgr_state() :: #state{}.

-define(ACDC_REQUIRED_SKILLS_KEY, 'acdc_required_skills').

-define(ACDC_QUEUE_MANAGER_HRL, 'true').
-endif.
