%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2026, open-kazoo
%%% @doc `start_default_apps/0' starts the kapps this node's selection picks,
%%% the same ones boot starts, so a node configured without ecallmgr doesn't
%%% start a second one.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kapps_controller_tests).

-include_lib("eunit/include/eunit.hrl").

default_apps_follow_selection_test_() ->
    {'setup'
    ,fun() ->
             Old = os:getenv("KAZOO_APPS"),
             'true' = os:putenv("KAZOO_APPS", "callflow, sysconf"),
             Old
     end
    ,fun('false') -> os:unsetenv("KAZOO_APPS");
        (Old) -> os:putenv("KAZOO_APPS", Old)
     end
    ,fun(_) ->
             [?_assertEqual(['sysconf', 'callflow']
                           ,kapps_controller:default_apps_to_start()
                           )
             ]
     end
    }.
