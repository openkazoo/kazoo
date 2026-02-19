-ifndef(KAZOO_CONFIG_HRL).

-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo/include/kz_system_config.hrl").

-define(CONFIG_FILE_ENV, "KAZOO_CONFIG").
-define(CONFIG_FILE_ETC_LOCAL, "/usr/local/etc/kazoo/config.yaml").
-define(CONFIG_FILE_ETC, "/etc/kazoo/config.yaml").

-define(APP, 'kazoo_config').
-define(APP_NAME, atom_to_binary(?APP, 'utf8')).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(SETTINGS_KEY, '$_App_Settings').

-type section() ::
    kz_term:ne_binary() | atom().

-define(KAZOO_CONFIG_HRL, 'true').
-endif.
