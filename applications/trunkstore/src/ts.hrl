-ifndef(TS_HRL).
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_number_manager/include/knm_phone_number.hrl").

-define(APP_NAME, <<"trunkstore">>).
-define(APP_VERSION, <<"4.0.0">>).
-define(CONFIG_CAT, ?APP_NAME).

%% couch params for the trunk store and its views
-define(TS_DB, <<"ts">>).

-define(CACHE_NAME, 'trunkstore_cache').

%% Account views
-define(TS_VIEW_DIDLOOKUP, <<"trunkstore/lookup_did">>).

%% just want to deal with binary K/V pairs
-type active_calls() :: [{binary(), 'flat_rate' | 'per_min'}].

-record(ts_callflow_state, {
    aleg_callid :: kz_term:api_ne_binary(),
    bleg_callid :: kz_term:api_ne_binary(),
    acctid = <<>> :: binary(),
    acctdb = <<>> :: binary(),
    route_req_jobj = kz_json:new() :: kz_json:object(),
    %% data for the endpoint, either an actual endpoint or an offnet request
    ep_data = kz_json:new() :: kz_json:object(),
    amqp_worker :: kz_term:api_pid(),
    callctl_q :: kz_term:api_ne_binary(),
    call_cost = 0.0 :: float(),
    failover :: kz_term:api_object(),
    kapps_call :: kapps_call:call()
}).

% unique call ID
-record(route_flags, {
    callid = <<>> :: binary(),
    % usually a DID
    to_user = <<>> :: binary(),
    to_domain = <<>> :: binary(),
    from_user = <<>> :: binary(),
    from_domain = <<>> :: binary(),
    % what username did we authenticate with
    auth_user = <<>> :: kz_term:api_binary(),
    % what realm did we auth with
    auth_realm = <<>> :: kz_term:api_binary(),
    % what direction is the call (relative to client)
    direction = <<>> :: binary(),
    % Server of the DID
    server_id = <<>> :: binary(),
    % Failover information {type, value}. Type=(sip|e164), Value=("sip:user@domain"|"+1234567890")
    failover = {} :: tuple(),
    allow_payphone = 'false' :: boolean(),
    % Name and Number for Caller ID - check DID, then server, then account, then what we got from ecallmgr
    caller_id = {} :: tuple(),
    % CallerID for E911 calls - Check DID, then server, then account
    caller_id_e911 = {} :: tuple(),
    % how does the server want the number? "E.164" | "NPANXXXXXX" | "1NPANXXXXXX" | "USERNAME"
    inbound_format = <<>> :: binary(),
    % are we in the media path or not "process" | "bypass"
    media_handling = <<>> :: binary(),
    %% for inbound with failover, how long do we wait
    progress_timeout = 'none' :: 'none' | integer(),
    %% if true, and call is outbound, don't try to route through our network; force over a carrier
    force_outbound :: boolean(),
    % what codecs to use (t38, g729, g711, etc...)
    codecs = [] :: list(),
    % rate for the inbound leg, per minute
    rate = 0.0 :: float(),
    % time, in sec, to bill per
    rate_increment = 60 :: integer(),
    % time, in sec, to bill as a minimum
    rate_minimum = 60 :: integer(),
    % rate to charge up front
    surcharge = 0.0 :: float(),
    % name of the rate
    rate_name = <<>> :: binary(),
    % options required to be handled by carriers
    route_options = [] :: list(),
    flat_rate_enabled = 'true' :: boolean(),
    % doc id of the account
    account_doc_id = <<>> :: binary(),
    % if an outbound call routes to a known DID, route internally rather than over a carrier; for billing
    diverted_account_doc_id = <<>> :: binary(),
    % the routes generated during the routing phase
    routes_generated = kz_json:new() :: kz_json:object() | kz_json:objects(),
    % what scenario have we routed over
    scenario = 'inbound' ::
        'inbound'
        | 'outbound'
        | 'inbound_failover'
        | 'outbound_inbound'
        | 'outbound_inbound_failover'
}).

-define(RESOURCE_TYPES_HANDLED, [<<"audio">>, <<"video">>]).

-define(TS_HRL, 'true').
-endif.
