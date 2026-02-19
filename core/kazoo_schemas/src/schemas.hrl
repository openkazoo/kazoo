-ifndef(SCHEMAS_HRL).

-define(APP, 'kazoo_schemas').
-define(APP_NAME, atom_to_binary(?APP, 'utf8')).
-define(APP_VERSION, kz_util:application_version(?APP)).

-define(SCHEMAS_HRL, 'true').
-endif.
