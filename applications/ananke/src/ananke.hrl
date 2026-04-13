-ifndef(ANANKE_HRL).
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").

-define(APP, 'ananke').
-define(APP_NAME, <<"ananke">>).
-define(APP_VERSION, kz_util:application_version(?APP)).
-define(CONFIG_CAT, ?APP_NAME).

-type pos_integers() :: list(pos_integer()).
-type check_fun() :: 'true' | fun(() -> boolean()) | {Module :: atom(), FunName :: atom(), Args :: list()}.

-define(ANANKE_HRL, 'true').
-endif.
