-module(kz_http_tests).

-include_lib("eunit/include/eunit.hrl").

default_ssl_options_test_() ->
    Opts = kz_http:default_ssl_options(),
    [?_assertEqual('verify_peer', props:get_value('verify', Opts))].

%% Without an OS CA bundle, public_key:cacerts_get/0 raises; the failure must
%% surface from httpc as an error tuple, not as an exception from here.
default_ssl_options_without_cacerts_test_() ->
    {'setup'
    ,fun() ->
             meck:new(httpc, ['passthrough']),
             meck:expect(httpc, 'ssl_verify_host_options'
                        ,fun(_) -> erlang:error({'failed_load_cacerts', 'enoent'}) end
                        )
     end
    ,fun(_) -> meck:unload() end
    ,?_assertEqual([{'verify', 'verify_peer'}], kz_http:default_ssl_options())
    }.
