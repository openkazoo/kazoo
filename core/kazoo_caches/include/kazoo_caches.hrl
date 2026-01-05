-ifndef(KAZOO_CACHES_HRL).

-include_lib("kazoo_stdlib/include/kz_types.hrl").
-type callback_msg() :: 'flush' | 'erase' | 'expire' | 'timeout' | 'store'.
-type callback_fun() :: fun((any(), any(), callback_msg()) -> any()).
-type callback_funs() :: [callback_fun()].
%% {db, Database, PvtType or Id}
-type origin_tuple() ::
    {'db', kz_term:ne_binary(), kz_term:ne_binary()}
    %% {type, PvtType, Id}
    | {'type', kz_term:ne_binary(), kz_term:ne_binary()}
    %% {db, Database}
    | {'db', kz_term:ne_binary()}
    %% {db, Database, Type}
    | {'db', kz_term:ne_binary(), kz_term:ne_binary() | '_'}
    %% {database, Database} added for notify db create/delete
    | {'database', kz_term:ne_binary()}
    %% {type, PvtType}
    | {'type', kz_term:ne_binary()}.
-type origin_tuples() :: [origin_tuple()].

-define(KAZOO_CACHES_HRL, 'true').
-endif.
