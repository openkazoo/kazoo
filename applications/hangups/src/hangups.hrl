-ifndef(HANGUPS_HRL).

-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").

-define(APP, 'hangups').
-define(APP_NAME, <<"hangups">>).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(HANGUPS_HRL, 'true').
-endif.
