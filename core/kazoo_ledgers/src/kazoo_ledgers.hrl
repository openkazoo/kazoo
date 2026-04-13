-ifndef(KAZOO_LEDGERS_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").

-define(APP, 'kazoo_ledgers').
-define(APP_NAME, <<"kazoo_ledgers">>).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(LIST_BY_SOURCE, <<"ledgers/list_by_source">>).
-define(TOTAL_BY_SOURCE, <<"ledgers/total_by_source">>).

-define(CONFIG_CAT, <<"ledgers">>).

-define(KAZOO_LEDGERS_HRL, 'true').
-endif.
