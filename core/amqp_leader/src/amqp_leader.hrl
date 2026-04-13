-ifndef(AMQP_LEADER_HRL).
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo_stdlib/include/kz_databases.hrl").

-define(APP, 'amqp_leader').
-define(APP_NAME, <<"amqp_leader">>).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(AMQP_LEADER_HRL, 'true').
-endif.
