-module(kz_auth_token_util_tests).

-include_lib("eunit/include/eunit.hrl").

access_code_test_() ->
    {'foreach'
    ,fun() -> meck:new(kz_auth_util, [passthrough]) end
    ,fun(_) -> meck:unload() end
    ,[fun access_code_failure/1
     ,fun access_code_success/1
     ]
    }.

access_code_failure(_) ->
    Error = {'error', 'invalid_grant'},
    meck:expect(kz_auth_util, fetch_access_code, fun(_, _, _) -> Error end),
    Result = kz_auth_token_util:access_code(token()),
    [?_assertEqual(Error, maps:get('access_code_error', Result))
    ,?_assertNot(maps:is_key('access_token', Result))
    ].

access_code_success(_) ->
    CodeJObj = kz_json:from_list([{<<"access_token">>, <<"at">>}
                                 ,{<<"token_type">>, <<"Bearer">>}
                                 ]),
    meck:expect(kz_auth_util, fetch_access_code, fun(_, _, _) -> {'ok', CodeJObj} end),
    Result = kz_auth_token_util:access_code(token()),
    [?_assertEqual(<<"at">>, maps:get('access_token', Result))
    ,?_assertNot(maps:is_key('access_code_error', Result))
    ].

token() ->
    #{code => <<"code">>
     ,original => kz_json:from_list([{<<"app_id">>, <<"app">>}])
     }.
