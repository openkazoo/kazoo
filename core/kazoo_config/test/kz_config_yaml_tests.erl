%%%-----------------------------------------------------------------------------
%%% @copyright 2026 Dialwave, Inc.
%%% @author Dialwave, Inc. (Rob Nichols)
%%% @doc EUnit tests for YAML config.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_config_yaml_tests).

-include_lib("eunit/include/eunit.hrl").

yaml_config_compat_test_() ->
    {setup, fun setup/0, fun cleanup/1, fun(_) ->
        [
            ?_assertEqual(50, kz_config:get_integer(<<"amqp">>, [<<"prefetch">>], 0)),
            ?_assertEqual('none', kz_config:get_atom(<<"log">>, [<<"console">>], 'notice')),
            ?_assertEqual('local', kz_config:zone()),
            ?_assertEqual(['change_me'], kazoo_config_init:read_cookie('kazoo_apps')),
            ?_assertEqual(
                <<"kazoo_fixturedb">>, kz_config:get_binary(<<"data">>, [<<"config">>], 'undefined')
            ),
            ?_assertEqual(
                <<"kazoo_fixturedb">>,
                props:get_value(<<"driver">>, kz_config:get_section_config(<<"kazoo_fixturedb">>))
            ),
            begin
                ok = kz_config:lock_system_config('true'),
                ?_assertEqual('true', kapps_config:is_locked())
            end,
            begin
                ok = kz_config:lock_system_config('false'),
                ?_assertEqual('false', kapps_config:is_locked())
            end
        ]
    end}.

typed_casting_compat_test_() ->
    {setup,
        fun() ->
            %% Force reload from app env rather than the process dictionary cache.
            erlang:put('$_App_Settings', 'undefined'),
            application:set_env(
                kazoo_config,
                kz_config,
                [
                    {<<"amqp">>, [
                        {<<"prefetch">>, <<"32">>},
                        {<<"pool">>, [
                            {<<"size">>, <<"150">>},
                            {<<"server_confirms">>, <<"false">>}
                        ]}
                    ]},
                    {<<"zones">>, [
                        {<<"test">>, [{<<"local">>, 'true'}]}
                    ]}
                ]
            ),
            ok
        end,
        fun(_State) ->
            ok
        end,
        fun(_) ->
            [
                ?_assertEqual(32, kz_config:get_integer(<<"amqp">>, [<<"prefetch">>], 0)),
                ?_assertEqual(150, kz_config:get_integer(<<"amqp">>, [<<"pool">>, <<"size">>], 0)),
                ?_assertEqual(
                    'false',
                    kz_config:get_boolean(<<"amqp">>, [<<"pool">>, <<"server_confirms">>], 'true')
                )
            ]
        end}.

setup() ->
    %% Ensure config is loaded (expects KAZOO_CONFIG to be set by the test runner).
    _ = kazoo_config_init:reload(),
    ok.

cleanup(_State) ->
    ok.
