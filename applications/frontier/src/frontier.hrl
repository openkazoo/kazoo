-ifndef(FRONTIER_HRL).
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").

-define(APP, 'frontier').
-define(APP_NAME, <<"frontier">>).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(MINUTE, <<"per_minute">>).
-define(SECOND, <<"per_second">>).

-define(FRONTIER_HRL, 'true').
-endif.
