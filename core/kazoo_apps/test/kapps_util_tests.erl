%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2021, 2600Hz
%%% @doc
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_util_tests).

-include("kazoo_apps.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("kazoo_fixturedb/include/kz_fixturedb.hrl").

all_test_() ->
    {setup, fun setup_fixtures/0, fun cleanup/1, fun(_) ->
        [{"Verify the fixture provides the master account", get_master_account_id_()}]
    end}.

setup_fixtures() ->
    ?LOG_DEBUG(":: Setting up Kazoo Util test"),

    Pid =
        case kz_fixturedb_util:start_me() of
            {error, {already_started, P}} -> P;
            P when is_pid(P) -> P
        end,

    meck:new(kz_datamgr, [unstick, passthrough]),

    meck:new(kz_fixturedb_db, [unstick, passthrough]),

    Pid.

cleanup(Pid) ->
    kz_fixturedb_util:stop_me(Pid),
    meck:unload().

get_master_account_id_() ->
    ?_assertEqual({'ok', ?FIXTURE_MASTER_ACCOUNT_ID}, kapps_util:get_master_account_id()).
