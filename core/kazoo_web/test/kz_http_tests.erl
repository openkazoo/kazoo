-module(kz_http_tests).

-include_lib("eunit/include/eunit.hrl").

default_ssl_options_test_() ->
    Opts = kz_http:default_ssl_options(),
    [?_assertEqual('verify_peer', props:get_value('verify', Opts))
    ,?_assertMatch([_|_], props:get_value('cacerts', Opts))
    ,?_assert(props:is_defined('customize_hostname_check', Opts))
    ].
