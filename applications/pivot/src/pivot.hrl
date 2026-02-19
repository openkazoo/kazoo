-ifndef(PIVOT_HRL).

%% Typical includes needed
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").

-define(CACHE_NAME, 'pivot_cache').

-define(APP, 'pivot').
-define(APP_NAME, <<"pivot">>).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(PIVOT_HRL, 'true').
-endif.
