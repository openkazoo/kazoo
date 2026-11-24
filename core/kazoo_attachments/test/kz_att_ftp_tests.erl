-module(kz_att_ftp_tests).

-include_lib("eunit/include/eunit.hrl").

%% ftp is its own OTP application since OTP 21 (it used to start with inets);
%% without it ftp:open/2 exits with noproc.
ftp_application_dependency_test_() ->
    _ = application:load('kazoo_attachments'),
    {'ok', Apps} = application:get_key('kazoo_attachments', 'applications'),
    [?_assert(lists:member('ftp', Apps))
    ,?_assert(lists:member('ssl', Apps))
    ].

get_options_test_() ->
    FTPS = kz_att_ftp:get_options('ftps', "ftp.example.com", 21),
    TLS = props:get_value('tls', FTPS),
    [?_assertEqual([{'port', 2121}], kz_att_ftp:get_options('ftp', "ftp.example.com", 2121))
    ,?_assertEqual(21, props:get_value('port', FTPS))
    ,?_assertEqual('verify_peer', props:get_value('verify', TLS))
    ,?_assertEqual("ftp.example.com", props:get_value('server_name_indication', TLS))
    ,?_assert(props:is_defined('cacerts', TLS))
    ,?_assert(props:is_defined('customize_hostname_check', TLS))
    ].
