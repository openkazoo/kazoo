-module(kz_json_schema_extensions_tests).

-include_lib("eunit/include/eunit.hrl").

is_valid_ftp_url_test_() ->
    {'setup'
    ,fun() ->
             meck:new(kz_http_util, [passthrough]),
             meck:expect(kz_http_util, client_host_blacklist, fun() -> 'undefined' end),
             meck:expect(kz_http_util, client_ip_blacklist, fun() -> 'undefined' end)
     end
    ,fun(_) -> meck:unload() end
    ,[?_assert(kz_json_schema_extensions:is_valid_ftp_url(<<"ftp://ftp.example.com/recordings">>))
     ,?_assert(kz_json_schema_extensions:is_valid_ftp_url(<<"ftp://user:pass@ftp.example.com:2121/recordings">>))
     ,?_assert(kz_json_schema_extensions:is_valid_ftp_url(<<"ftps://user:pass@ftp.example.com/recordings">>))
     ,?_assertNot(kz_json_schema_extensions:is_valid_ftp_url(<<"ftps://ftp.example.com/recordings">>))
     ,?_assertNot(kz_json_schema_extensions:is_valid_ftp_url(<<"ftp:///recordings">>))
     ,?_assertNot(kz_json_schema_extensions:is_valid_ftp_url(<<"ftp://exa mple.com/recordings">>))
     ]
    }.
