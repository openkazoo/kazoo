-ifndef(KAZOO_GLOBALS_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo/include/kz_api_literals.hrl").

-define(APP, 'kazoo_globals').
-define(APP_NAME, <<"kazoo_globals">>).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(KAZOO_GLOBALS_HRL, 'true').
-endif.
