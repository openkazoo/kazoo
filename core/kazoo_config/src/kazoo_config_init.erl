%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2022, 2600Hz
%%% @author Dialwave, Inc. (Rob Nichols)
%%% @doc
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_config_init).

-include("kazoo_config.hrl").

-export([
    start_link/0,
    reload/0
]).

-export([read_cookie/1]).

%%------------------------------------------------------------------------------
%% @doc Starts the application for inclusion in a supervisor tree.
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    set_env(),
    'ignore'.

%%------------------------------------------------------------------------------
%% @doc Resolve config path.
%% @end
%%------------------------------------------------------------------------------
-spec config_path() -> kz_term:api_list().
config_path() ->
    case os:getenv(?CONFIG_FILE_ENV) of
        'false' ->
            case readable_file(?CONFIG_FILE_ETC_LOCAL) of
                'true' ->
                    ?CONFIG_FILE_ETC_LOCAL;
                'false' ->
                    case readable_file(?CONFIG_FILE_ETC) of
                        'true' -> ?CONFIG_FILE_ETC;
                        'false' -> 'undefined'
                    end
            end;
        Path when is_list(Path), Path =/= [] ->
            Path;
        _ ->
            'undefined'
    end.

%%------------------------------------------------------------------------------
%% @doc Check if a file is readable.
%% @end
%%------------------------------------------------------------------------------
-spec readable_file(file:name_all()) -> boolean().
readable_file(Path) ->
    filelib:is_regular(Path).

%%------------------------------------------------------------------------------
%% @doc Load config from file.
%% @end
%%------------------------------------------------------------------------------
-spec load_config() -> kz_term:proplist().
load_config() ->
    case config_path() of
        'undefined' ->
            lager:critical("config file not found (set KAZOO_CONFIG or install config.yaml)"),
            erlang:error('no_config_file');
        Path ->
            try
                _ = application:ensure_all_started('yamerl'),
                case yamerl_constr:file(Path, [str_node_as_binary]) of
                    [Doc | _] when is_list(Doc) ->
                        lager:notice("loaded config (~s): ~p", [Path, Doc]),
                        kz_config_validate:all(Doc),
                        Doc;
                    _ ->
                        lager:critical("config file has an unexpected structure (~s)", [Path]),
                        erlang:error('bad_config_structure')
                end
            catch
                Class:Reason ->
                    lager:critical("failed to parse config (~s): ~p:~p", [Path, Class, Reason]),
                    erlang:error({'bad_config', Path, Class, Reason})
            end
    end.

%%------------------------------------------------------------------------------
%% @doc Set the environment variables.
%% @end
%%------------------------------------------------------------------------------
-spec set_env() -> 'ok'.
set_env() ->
    Config = load_config(),
    application:set_env(?APP, 'kz_config', Config),
    erlang:put(?SETTINGS_KEY, Config),
    Zone = kz_config:resolve_zone(Config),
    lager:notice("setting zone to ~p", [Zone]),
    application:set_env(?APP, 'zone', Zone).

%%------------------------------------------------------------------------------
%% @doc Reload the config.
%% @end
%%------------------------------------------------------------------------------
-spec reload() -> 'ok'.
reload() ->
    set_env().

%%------------------------------------------------------------------------------
%% @doc Reads `config.yaml' without starting the `kazoo_config' application.
%% @end
%%------------------------------------------------------------------------------
-spec read_cookie(atom()) -> [atom()].
read_cookie(VMName) ->
    Config = load_config(),
    case kz_config:get_vm_cookie(VMName, Config) of
        'undefined' -> [];
        CookieBin -> [kz_term:to_atom(CookieBin, 'true')]
    end.
