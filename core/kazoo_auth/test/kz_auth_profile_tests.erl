-module(kz_auth_profile_tests).

-include_lib("eunit/include/eunit.hrl").

%% A failed access-code exchange leaves no access token, so loading the profile
%% throws and the token has no `profile'. token/1 used to loop forever in
%% maybe_add_user_identity/1 from there.
token_without_profile_test_() ->
    Token = #{auth_provider => #{name => <<"keycloak">>
                                ,profile_url => <<"https://idp.example.com/userinfo">>
                                }
             ,access_token => #{}
             },
    {'timeout', 5
    ,fun() ->
             Result = kz_auth_profile:token(Token),
             ?assertNot(maps:is_key('profile', Result)),
             ?assertNot(maps:is_key('user_identity', Result)),
             ?assertNot(maps:is_key('display_name', Result))
     end
    }.
