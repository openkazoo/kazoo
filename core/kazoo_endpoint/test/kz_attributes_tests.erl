%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2014-2021, 2600Hz
%%% @doc
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_attributes_tests).

-include("kazoo_endpoint.hrl").

-include_lib("eunit/include/eunit.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_fixturedb/include/kz_fixturedb.hrl").

-define(NEW_CF_FLAGS, [
    fun(C) -> kapps_call:set_account_id(?FIXTURE_RESELLER_ACCOUNT_ID, C) end,
    fun(C) -> kapps_call:set_authorizing_id(<<"device00000000000000000000000002">>, C) end,
    fun(C) -> kapps_call:set_owner_id(<<"user0000000000000000000000000002">>, C) end
]).

-define(MIXED_CF_FLAGS, [
    fun(C) -> kapps_call:set_account_id(?FIXTURE_PARENT_ACCOUNT_ID, C) end,
    fun(C) -> kapps_call:set_authorizing_id(<<"device00000000000000000000000003">>, C) end,
    fun(C) -> kapps_call:set_owner_id(<<"user0000000000000000000000000003">>, C) end
]).

-define(NEW_TS_FLAGS, [
    fun(C) -> kapps_call:set_account_id(?FIXTURE_RESELLER_ACCOUNT_ID, C) end,
    fun(C) -> kapps_call:set_authorizing_id(<<"trunkstore0000000000000000000002">>, C) end
]).

-define(DISA_CID_CALL, [
    fun(C) -> kapps_call:set_account_id(?FIXTURE_PARENT_ACCOUNT_ID, C) end,
    fun(C) -> kapps_call:set_caller_id_name(<<"disa">>, C) end,
    fun(C) -> kapps_call:set_caller_id_number(<<"+19995552600">>, C) end
]).

all_test_() ->
    {setup, fun setup_fixtures/0, fun cleanup/1, fun(_) ->
        [
            {"Testing get flags callflow", test_get_flags_callflow()},
            {"Testing get flags trunkstore", test_get_flags_trunkstore()},
            {"Testing process dynamic flags", test_process_dynamic_flags()},
            {"Testing account cid", test_account_cid()}
        ]
    end}.

setup_fixtures() ->
    ?LOG_DEBUG(":: Setting up Kazoo Endpoint test"),

    Pid =
        case kz_fixturedb_util:start_me() of
            {error, {already_started, P}} -> P;
            P when is_pid(P) -> P
        end,

    meck:new(kz_datamgr, [unstick, passthrough]),
    meck:expect(kz_datamgr, open_cache_doc, fun(Db, AccountId, _Options) ->
        kz_datamgr:open_doc(Db, AccountId)
    end),
    %%    meck:expect(kz_datamgr, open_cache_doc, fun
    %%           (NumberDb, NormalizedNum) ->
    %%                ?LOG_DEV("mecking kz_datamgr:open_cache_doc(~p, ~p)", [NumberDb, NormalizedNum]),
    %%                kz_datamgr:open_doc(NumberDb, NormalizedNum)
    %%           end),

    meck:new(kz_fixturedb_db, [unstick, passthrough]),

    Pid.

cleanup(Pid) ->
    kz_fixturedb_util:stop_me(Pid),
    meck:unload().

test_get_flags_callflow() ->
    Call = create_callflow_call(),
    ExpectedOld = [
        <<"user_old_static_flag">>,
        <<"device_old_static_flag">>,
        <<"account_old_static_flag">>
    ],
    ExpectedNew = [
        <<"user0000000000000000000000000002">>,
        <<"user_new_static_flag">>,
        <<"local">>,
        <<"device_new_static_flag">>,
        <<"4a6863.sip.2600hz.local">>,
        <<"account_new_static_flag">>
    ],
    ExpectedMixed = [
        <<"user_new_static_flag">>,
        <<"local">>,
        <<"device_old_static_flag">>,
        <<"user0000000000000000000000000003">>,
        <<"account_new_static_flag">>
    ],
    [
        {"verify that get flags will pull the static and dynamic flags from all sources with old formats",
            ?_assertEqual(ExpectedOld, kz_attributes:get_flags(<<"callflows">>, Call))},
        {"verify that get flags will pull the static and dynamic flags from all sources with new formats",
            ?_assertEqual(
                ExpectedNew,
                kz_attributes:get_flags(<<"callflows">>, kapps_call:exec(?NEW_CF_FLAGS, Call))
            )},
        {"verify that get flags will pull the static and dynamic flags from all sources with mixed formats",
            ?_assertEqual(
                ExpectedMixed,
                kz_attributes:get_flags(<<"callflows">>, kapps_call:exec(?MIXED_CF_FLAGS, Call))
            )}
    ].

test_get_flags_trunkstore() ->
    Call = create_trunkstore_call(),
    ExpectedOld = [<<"account_old_static_flag">>],
    ExpectedNew = [
        <<"local">>,
        <<"account_new_static_flag">>
    ],
    [
        {"verify that get flags will pull the static and dynamic flags from all sources with old formats",
            ?_assertEqual(ExpectedOld, kz_attributes:get_flags(<<"trunkstore">>, Call))},
        {"verify that get flags will pull the static and dynamic flags from all sources with new formats",
            ?_assertEqual(
                ExpectedNew,
                kz_attributes:get_flags(<<"trunkstore">>, kapps_call:exec(?NEW_TS_FLAGS, Call))
            )}
    ].

test_process_dynamic_flags() ->
    Call = create_callflow_call(),
    [
        {"verify that dynamic CCVs can be fetched and are converted to binary",
            ?_assertEqual(
                [<<"device">>],
                kz_attributes:process_dynamic_flags(
                    [<<"custom_channel_vars.authorizing_type">>], Call
                )
            )},
        {"verify that exported kapps_call functions can be used",
            ?_assertEqual(
                [<<"20255520140">>], kz_attributes:process_dynamic_flags([<<"to_user">>], Call)
            )},
        {"verify that non-exported kapps_call functions dont crash",
            ?_assertEqual([], kz_attributes:process_dynamic_flags([<<"not_exported">>], Call))},
        {"verify that the zone name can be resolved",
            ?_assertEqual([<<"local">>], kz_attributes:process_dynamic_flags([<<"zone">>], Call))},
        {"verify that dynamic flags are added to a provided list of static flags",
            ?_assertEqual(
                [<<"local">>, <<"static">>],
                kz_attributes:process_dynamic_flags([<<"zone">>], [<<"static">>], Call)
            )}
    ].

test_account_cid() ->
    Call = create_callflow_call(),
    DISACall = kapps_call:exec(?DISA_CID_CALL, Call),
    {CIDNumber, CIDName} = kz_attributes:get_account_external_cid(DISACall),

    [
        {"account external caller id number chosen", ?_assertEqual(<<"+19995552600">>, CIDNumber)},
        {"account external caller id name chosen",
            ?_assertEqual(<<"account-external-name">>, CIDName)}
    ].

create_callflow_call() ->
    ?LOG_DEV("create_callflow_call"),
    RouteReq = inbound_onnet_callflow_req(),
    RouteWin = inbound_onnet_callflow_win(),
    kapps_call:from_route_win(RouteWin, kapps_call:from_route_req(RouteReq)).

inbound_onnet_callflow_req() ->
    {ok, RouteReq} = kz_json:fixture(
        'kazoo_call', "fixtures/route_req/inbound-onnet-callflow.json"
    ),
    'true' = kapi_route:req_v(RouteReq),
    RouteReq.

inbound_onnet_callflow_win() ->
    {ok, RouteWin} = kz_json:fixture(
        'kazoo_call', "fixtures/route_win/inbound-onnet-callflow.json"
    ),
    'true' = kapi_route:win_v(RouteWin),
    RouteWin.

create_trunkstore_call() ->
    RouteReq = inbound_onnet_trunkstore_req(),
    RouteWin = inbound_onnet_trunkstore_win(),
    kapps_call:from_route_win(RouteWin, kapps_call:from_route_req(RouteReq)).

inbound_onnet_trunkstore_req() ->
    {ok, RouteReq} = kz_json:fixture(
        'kazoo_call', "fixtures/route_req/inbound-onnet-trunkstore.json"
    ),
    'true' = kapi_route:req_v(RouteReq),
    RouteReq.

inbound_onnet_trunkstore_win() ->
    {ok, RouteWin} = kz_json:fixture(
        'kazoo_call', "fixtures/route_win/inbound-onnet-trunkstore.json"
    ),
    'true' = kapi_route:win_v(RouteWin),
    RouteWin.
