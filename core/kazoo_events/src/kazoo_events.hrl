-ifndef(KAZOO_EVENTS_HRL).

-include_lib("kazoo_stdlib/include/kz_databases.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo/include/kz_system_config.hrl").

-define(APP, 'kazoo_events').
-define(APP_NAME, <<"kazoo_events">>).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(KAZOO_EVENTS_HRL, 'true').
-endif.
