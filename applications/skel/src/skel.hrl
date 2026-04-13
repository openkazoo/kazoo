-ifndef(SKEL_HRL).
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").

-define(APP, 'skel').
-define(APP_NAME, <<"skel">>).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(CACHE_NAME, 'skel_cache').

-define(SKEL_HRL, 'true').
-endif.
