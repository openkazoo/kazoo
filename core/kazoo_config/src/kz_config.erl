%%%-----------------------------------------------------------------------------
%%% @copyright 2026 Dialwave, Inc.
%%% @author Dialwave, Inc. (Rob Nichols)
%%% @doc YAML configuration accessors.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_config).

-export([
    all/0,
    get_section_config/1,
    get_zones_config/0,
    get_zone_config/0, get_zone_config/1,
    zone/0, zone/1,
    get_local_zone/1,
    get_amqp_brokers/1,
    get_zone_amqp_uris/1,
    get/2, get/3,
    get_integer/2, get_integer/3,
    get_boolean/2, get_boolean/3,
    get_atom/2, get_atom/3,
    get_binary/2, get_binary/3,
    lock_system_config/1,
    resolve_zone/1,
    get_vm_cookie/2
]).

-include("kazoo_config.hrl").

%%------------------------------------------------------------------------------
%% @doc Return the full config.
%% @end
%%------------------------------------------------------------------------------
-spec all() -> kz_term:proplist().
all() ->
    load().

%%------------------------------------------------------------------------------
%% @doc Top-level section accessors.
%% @end
%%------------------------------------------------------------------------------
-spec get_section_config(section()) -> kz_term:proplist().
get_section_config(Section) ->
    Config = all(),
    props:get_value(norm_section(Section), Config, []).

-spec get_zones_config() -> kz_term:proplist().
get_zones_config() ->
    Config = all(),
    props:get_value(<<"zones">>, Config, []).

-spec get_zone_config() -> kz_term:proplist().
get_zone_config() ->
    props:get_value(zone('binary'), get_zones_config(), []).

-spec get_zone_config(section()) -> kz_term:proplist().
get_zone_config(Zone) ->
    props:get_value(norm_section(Zone), get_zones_config(), []).

%%------------------------------------------------------------------------------
%% @doc Get a value from the config by path.
%% @end
%%------------------------------------------------------------------------------
-spec get(section(), [any()]) -> any().
get(Section, Path) ->
    get(Section, Path, 'undefined').

-spec get(section(), [any()], any()) -> any().
get(Section, Path, Default) ->
    Props = get_section_config(Section),
    Keys = norm_path(Path),
    props:get_value(Keys, Props, Default).

%%------------------------------------------------------------------------------
%% @doc Get an integer from the config.
%% @end
%%------------------------------------------------------------------------------
-spec get_integer(section(), [any()]) -> integer().
get_integer(Section, Path) ->
    get_integer(Section, Path, 0).

-spec get_integer(section(), [any()], integer()) -> integer().
get_integer(Section, Path, Default) ->
    kz_term:to_integer(get(Section, Path, Default)).

%%------------------------------------------------------------------------------
%% @doc Get a boolean from the config.
%% @end
%%------------------------------------------------------------------------------
-spec get_boolean(section(), [any()]) -> boolean().
get_boolean(Section, Path) ->
    get_boolean(Section, Path, 'false').

-spec get_boolean(section(), [any()], boolean()) -> boolean().
get_boolean(Section, Path, Default) ->
    kz_term:is_true(get(Section, Path, Default)).

%%------------------------------------------------------------------------------
%% @doc Get an atom from the config.
%% @end
%%------------------------------------------------------------------------------
-spec get_atom(section(), [any()]) -> atom().
get_atom(Section, Path) ->
    get_atom(Section, Path, 'undefined').

-spec get_atom(section(), [any()], atom()) -> atom().
get_atom(Section, Path, Default) ->
    Value = get(Section, Path, Default),
    kz_term:to_atom(Value, 'true').

%%------------------------------------------------------------------------------
%% @doc Get a binary from the config.
%% @end
%%------------------------------------------------------------------------------
-spec get_binary(section(), [any()]) -> kz_term:api_binary().
get_binary(Section, Path) ->
    get_binary(Section, Path, 'undefined').

-spec get_binary(section(), [any()], kz_term:api_binary()) -> kz_term:api_binary().
get_binary(Section, Path, Default) ->
    kz_term:to_api_binary(get(Section, Path, Default)).

%%------------------------------------------------------------------------------
%% @doc Update system config lock in-memory (no persistence).
%% @end
%%------------------------------------------------------------------------------
-spec lock_system_config(atom()) -> 'ok'.
lock_system_config(State) ->
    Config = all(),
    CouchdbConfig = get_section_config(<<"couchdb">>),
    NewCouchdbConfig =
        case props:get_value(<<"lock_system_config">>, CouchdbConfig) of
            'undefined' ->
                props:insert_value(<<"lock_system_config">>, State, CouchdbConfig);
            _ ->
                props:replace_value(<<"lock_system_config">>, State, CouchdbConfig)
        end,
    NewConfig = props:replace_value(<<"couchdb">>, NewCouchdbConfig, Config),
    application:set_env(?APP, ?MODULE, NewConfig).

%%------------------------------------------------------------------------------
%% @doc Zone helpers.
%% Local zone is determined by KAZOO_ZONE env var or zones.*.local: true.
%% @end
%%------------------------------------------------------------------------------
-spec zone() -> atom().
zone() ->
    case application:get_env(?APP, 'zone') of
        'undefined' ->
            Zone = resolve_zone(all()),
            application:set_env(?APP, 'zone', Zone),
            Zone;
        {'ok', Zone} ->
            Zone
    end.

-spec zone(atom()) -> kz_term:ne_binary() | atom().
zone('binary') -> kz_term:to_binary(zone());
zone(_) -> zone().

-spec resolve_zone(kz_term:proplist()) -> atom().
resolve_zone(Config) ->
    case os:getenv("KAZOO_ZONE", "noenv") of
        "noenv" ->
            Zones = kz_config_validate:zones(Config),
            _ = kz_config_validate:local_zone(Zones),
            kz_term:to_atom(get_local_zone(Zones), 'true');
        ZoneStr ->
            Zones = kz_config_validate:zones(Config),
            ZoneBin = kz_term:to_binary(ZoneStr),
            case lists:keymember(ZoneBin, 1, Zones) of
                'true' ->
                    kz_term:to_atom(ZoneStr, 'true');
                'false' ->
                    lager:critical("KAZOO_ZONE (~s) does not match any configured zone", [
                        ZoneStr
                    ]),
                    erlang:error({'unknown_zone', ZoneStr})
            end
    end.

-spec get_local_zone(kz_term:proplist()) -> kz_term:api_ne_binary().
get_local_zone(Zones) ->
    case [Z || {Z, P} <- Zones, kz_term:is_true(props:get_value(<<"local">>, P, 'false'))] of
        [ZoneName | _] ->
            ZoneName;
        [] ->
            'undefined'
    end.

%%------------------------------------------------------------------------------
%% @doc AMQP broker helpers.
%% @end
%%------------------------------------------------------------------------------
-spec get_amqp_brokers(kz_term:proplist()) -> kz_term:ne_binaries().
get_amqp_brokers(Zones) when is_list(Zones) ->
    lists:usort(lists:flatten([get_zone_amqp_brokers(Zone) || Zone <- Zones]));
get_amqp_brokers(_Other) ->
    [].

-spec get_zone_amqp_brokers({kz_term:ne_binary(), kz_term:proplist()} | any()) ->
    kz_term:ne_binaries().
get_zone_amqp_brokers({_ZoneName, ZoneConfig}) when is_list(ZoneConfig) ->
    get_zone_amqp_uris(ZoneConfig);
get_zone_amqp_brokers(_) ->
    [].

%% Return AMQP URIs for a single zone config.
-spec get_zone_amqp_uris(kz_term:proplist() | any()) -> kz_term:ne_binaries().
get_zone_amqp_uris(ZoneConfig) when is_list(ZoneConfig) ->
    Amqp = props:get_value(<<"amqp">>, ZoneConfig, []),
    Raw = props:get_value(<<"uri">>, Amqp, []),
    normalize_amqp_uris(Raw);
get_zone_amqp_uris(_) ->
    [].

-spec normalize_amqp_uris(any()) -> kz_term:ne_binaries().
normalize_amqp_uris([]) ->
    [];
normalize_amqp_uris('undefined') ->
    [];
normalize_amqp_uris('null') ->
    [];
normalize_amqp_uris(<<"null">>) ->
    [];
normalize_amqp_uris(<<>>) ->
    [];
normalize_amqp_uris(List) when is_list(List) ->
    [kz_term:to_binary(B) || B <- List, is_valid_amqp_uri(B)];
normalize_amqp_uris(One) ->
    case is_valid_amqp_uri(One) of
        'true' ->
            [kz_term:to_binary(One)];
        'false' ->
            []
    end.

-spec is_valid_amqp_uri(any()) -> boolean().
is_valid_amqp_uri(Broker) ->
    case catch amqp_uri:parse(kz_term:to_list(Broker)) of
        {'ok', _Params} ->
            'true';
        _ ->
            'false'
    end.

%%------------------------------------------------------------------------------
%% @doc Get a VM cookie from the local zone config.
%% @end
%%------------------------------------------------------------------------------
-spec get_vm_cookie(atom(), kz_term:proplist()) -> kz_term:api_ne_binary().
get_vm_cookie(VMName, Config) ->
    Zones = kz_config_validate:zones(Config),
    _ = kz_config_validate:local_zone(Zones),
    ZoneName = get_local_zone(Zones),
    ZoneConfig = props:get_value(ZoneName, Zones, []),
    VMs = props:get_value(<<"vms">>, ZoneConfig, []),
    VMKey = kz_term:to_binary(VMName),
    case lists:keyfind(VMKey, 1, lists:flatten(VMs)) of
        {Key, VMProps} when Key =:= VMKey, is_list(VMProps) ->
            kz_term:to_api_binary(props:get_value(<<"cookie">>, VMProps, 'undefined'));
        _ ->
            'undefined'
    end.

%%------------------------------------------------------------------------------
%% @doc Normalization helpers.
%% @end
%%------------------------------------------------------------------------------
-spec norm_section(any()) -> kz_term:ne_binary().
norm_section(Section) when is_binary(Section) -> Section;
norm_section(Section) when is_atom(Section) -> atom_to_binary(Section, 'utf8');
norm_section(Section) when is_list(Section) -> kz_term:to_binary(Section);
norm_section(Section) -> kz_term:to_binary(Section).

-spec norm_key(any()) -> kz_term:ne_binary().
norm_key(Key) when is_binary(Key) -> Key;
norm_key(Key) when is_atom(Key) -> atom_to_binary(Key, 'utf8');
norm_key(Key) when is_list(Key) -> kz_term:to_binary(Key);
norm_key(Key) -> kz_term:to_binary(Key).

-spec norm_path([any()] | any()) -> [kz_term:ne_binary()].
norm_path(Path) when is_list(Path) ->
    [norm_key(K) || K <- Path];
norm_path(One) ->
    [norm_key(One)].

%%------------------------------------------------------------------------------
%% @doc Load config from app env/process dictionary.
%% @end
%%------------------------------------------------------------------------------
-spec load() -> kz_term:proplist().
load() ->
    case erlang:get(?SETTINGS_KEY) of
        'undefined' ->
            case application:get_env(?APP, ?MODULE) of
                'undefined' ->
                    lager:critical("missing config in env/process dictionary"),
                    erlang:error('missing_config');
                {'ok', Settings} ->
                    Settings
            end;
        Settings ->
            erlang:put(?SETTINGS_KEY, 'undefined'),
            Settings
    end.
