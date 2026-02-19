-ifndef(KZ_AMQP_UTIL_HRL).

-include_lib("kazoo_amqp/include/kz_amqp.hrl").
-include_lib("kazoo_amqp/include/kz_api.hrl").
-include_lib("kazoo_stdlib/include/kz_types.hrl").
-include_lib("kazoo_stdlib/include/kz_log.hrl").
-include_lib("kazoo/include/kz_api_literals.hrl").

-define(APP, 'kazoo_amqp').
-define(APP_NAME, <<"kazoo_amqp">>).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(KZ_AMQP_UTIL_HRL, 'true').
-endif.
