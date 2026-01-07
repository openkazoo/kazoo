%%%-----------------------------------------------------------------------------
%%% @copyright 2026 Dialwave, Inc.
%%% @author Dialwave, Inc. (Rob Nichols)
%%% @doc Kazoo config validation.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_config_validate).

-export([
    all/1,
    zones/1,
    local_zone/1,
    amqp/1,
    amqp_brokers/1,
    datastore/1
]).

%%------------------------------------------------------------------------------
%% @doc Validate optional integer value.
%% @end
%%------------------------------------------------------------------------------

-spec optional_int(kz_term:ne_binary(), any()) -> 'ok'.
optional_int(_Label, 'undefined') ->
    'ok';
optional_int(Label, 'null') ->
    lager:critical("~s must be an integer, not null", [Label]),
    erlang:error({'invalid_integer', Label});
optional_int(Label, <<"null">>) ->
    lager:critical("~s must be an integer, not null", [Label]),
    erlang:error({'invalid_integer', Label});
optional_int(Label, V) ->
    try kz_term:to_integer(V) of
        I when is_integer(I) ->
            'ok'
    catch
        _:_ ->
            lager:critical("~s must be an integer (got: ~p)", [Label, V]),
            erlang:error({'invalid_integer', Label})
    end.

%%------------------------------------------------------------------------------
%% @doc Validate all sections of the config.
%% @end
%%------------------------------------------------------------------------------
-spec all(kz_term:proplist()) -> kz_term:proplist().
all(Config) ->
    Zones = zones(Config),
    _ = local_zone(Zones),
    _ = amqp(Config),
    _ = amqp_brokers(Zones),
    _ = datastore(Config),
    Config.

%%------------------------------------------------------------------------------
%% @doc Ensure zones section exists and is a non-empty list.
%% @end
%%------------------------------------------------------------------------------
-spec zones(kz_term:proplist()) -> kz_term:proplist().
zones(Config) when is_list(Config) ->
    case props:get_value(<<"zones">>, Config, 'undefined') of
        Zs when is_list(Zs), Zs =/= [] ->
            Zs;
        'undefined' ->
            lager:critical("missing required 'zones' section"),
            erlang:error('missing_zones');
        [] ->
            lager:critical("zones section is empty"),
            erlang:error('missing_zones');
        Other ->
            lager:critical("zones must be a mapping of zone name to zone settings (got: ~p)", [
                Other
            ]),
            erlang:error({'bad_zones', Other})
    end;
zones(Other) ->
    lager:critical("config root must be a mapping (got: ~p)", [Other]),
    erlang:error({'bad_config', Other}).

%%------------------------------------------------------------------------------
%% @doc Ensure at least one zone is marked as local.
%% @end
%%------------------------------------------------------------------------------
-spec local_zone(kz_term:proplist()) -> 'ok'.
local_zone(Zones) ->
    case kz_config:get_local_zone(Zones) of
        'undefined' ->
            lager:critical("no zones marked as local"),
            erlang:error('no_local_zone');
        _ ->
            'ok'
    end.

%%------------------------------------------------------------------------------
%% @doc Validate global AMQP config.
%% @end
%%------------------------------------------------------------------------------
-spec amqp(kz_term:proplist()) -> 'ok'.
amqp(Config) when is_list(Config) ->
    Amqp = props:get_value(<<"amqp">>, Config, 'undefined'),
    case Amqp of
        'undefined' ->
            'ok';
        'null' ->
            lager:critical("amqp must be a mapping, not null"),
            erlang:error({'bad_amqp_section', 'null'});
        Props when is_list(Props) ->
            _ = optional_int(
                <<"amqp.prefetch">>, props:get_value(<<"prefetch">>, Props, 'undefined')
            ),
            Pool = props:get_value(<<"pool">>, Props, 'undefined'),
            case Pool of
                'undefined' ->
                    'ok';
                'null' ->
                    lager:critical("amqp.pool must be a mapping, not null"),
                    erlang:error({'bad_amqp_pool', 'null'});
                PoolProps when is_list(PoolProps) ->
                    _ = optional_int(
                        <<"amqp.pool.size">>, props:get_value(<<"size">>, PoolProps, 'undefined')
                    ),
                    _ = optional_int(
                        <<"amqp.pool.overflow">>,
                        props:get_value(<<"overflow">>, PoolProps, 'undefined')
                    ),
                    _ = optional_int(
                        <<"amqp.pool.threshold">>,
                        props:get_value(<<"threshold">>, PoolProps, 'undefined')
                    ),
                    'ok';
                Other ->
                    lager:critical("amqp.pool must be a mapping (got: ~p)", [Other]),
                    erlang:error({'bad_amqp_pool', Other})
            end;
        Other ->
            lager:critical("amqp must be a mapping (got: ~p)", [Other]),
            erlang:error({'bad_amqp_section', Other})
    end;
amqp(_) ->
    'ok'.

%%------------------------------------------------------------------------------
%% @doc Validate AMQP brokers. Ensure at least one AMQP broker exists in the
%% zone config.
%% @end
%%------------------------------------------------------------------------------
-spec amqp_brokers(kz_term:proplist()) -> 'ok'.
amqp_brokers(Zones) ->
    case kz_config:get_amqp_brokers(Zones) of
        [] ->
            lager:critical("no AMQP brokers configured in zones"),
            erlang:error('no_amqp_brokers');
        _ ->
            'ok'
    end.

%%------------------------------------------------------------------------------
%% @doc Validate datastore config. If data.config is couchdb, ensure the couchdb
%% config exists and has at least host/ip + port.
%% @end
%%------------------------------------------------------------------------------
-spec datastore(kz_term:proplist()) -> 'ok' | no_return().
datastore(Config) when is_list(Config) ->
    Data = props:get_value(<<"data">>, Config, []),
    Driver = kz_term:to_binary(
        props:get_value(<<"config">>, Data, 'undefined')
    ),
    case Driver of
        'null' ->
            lager:critical("data.config must not be null"),
            erlang:error(bad_data_config);
        <<"couchdb">> ->
            couchdb(Driver, Config);
        _ ->
            'ok'
    end;
datastore(_) ->
    'ok'.

-spec couchdb(kz_term:ne_binary(), kz_term:proplist()) -> 'ok'.
couchdb(Section, Config) ->
    case props:get_value(Section, Config, 'undefined') of
        'undefined' ->
            lager:critical("data.config selects ~s, but the ~s section is missing", [
                Section, Section
            ]),
            erlang:error({'missing_datastore_section', Section});
        Props when is_list(Props) ->
            _ = couchdb_host_ip(Props),
            _ = couchdb_port(Props),
            'ok';
        Other ->
            lager:critical("~s must be a mapping (got: ~p)", [Section, Other]),
            erlang:error({'bad_datastore_section', Section})
    end.

-spec couchdb_host_ip(kz_term:proplist()) -> 'ok' | no_return().
couchdb_host_ip(Props) ->
    case props:get_first_defined([<<"ip">>, <<"host">>], Props, 'undefined') of
        H when H =:= 'undefined'; H =:= 'null'; H =:= <<>> ->
            lager:critical("couchdb config missing required ip/host"),
            erlang:error(missing_couchdb_host);
        _ ->
            'ok'
    end.

-spec couchdb_port(kz_term:proplist()) -> 'ok' | no_return().
couchdb_port(Props) ->
    case props:get_value(<<"port">>, Props, 'undefined') of
        P when P =:= 'undefined'; P =:= 'null' ->
            lager:critical("couchdb config missing required port"),
            erlang:error(missing_couchdb_port);
        P ->
            case catch kz_term:to_integer(P) of
                Port when is_integer(Port), Port > 0 ->
                    ok;
                _ ->
                    lager:critical("couchdb config port is invalid (~p)", [P]),
                    erlang:error(bad_couchdb_port)
            end
    end.
