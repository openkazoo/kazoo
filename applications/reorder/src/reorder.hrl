-ifndef(REORDER_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").

-define(APP, 'reorder').
-define(APP_NAME, <<"reorder">>).
-define(APP_VERSION, kz_util:application_version(?APP)).
-define(CONFIG_CAT, ?APP_NAME).

-define(RESOURCE_TYPES_HANDLED, [<<"audio">>, <<"video">>, <<"sms">>]).

-define(REORDER_HRL, true).
-endif.
