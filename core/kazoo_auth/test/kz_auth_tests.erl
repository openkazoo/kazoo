-module(kz_auth_tests).

-include_lib("eunit/include/eunit.hrl").

authenticate_fold_test_() ->
    Mark = fun(Token) -> Token#{ran => 'true'} end,
    Fail = fun(Token) -> Token#{access_code_error => {'error', 'invalid_grant'}} end,
    [?_assertEqual(#{ran => 'true'}
                  ,kz_auth:authenticate_fold(#{}, [Mark])
                  )
    ,?_assertNot(maps:is_key('ran', kz_auth:authenticate_fold(#{}, [Fail, Mark])))
    ].
