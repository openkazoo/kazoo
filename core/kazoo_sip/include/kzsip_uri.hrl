-ifndef(KZSIP_URI_HRL).

-record(uri, {
    scheme :: nklib:scheme(),
    user = <<>> :: binary(),
    pass = <<>> :: binary(),
    domain = <<"invalid.invalid">> :: binary(),
    % 0 means "no port in message"
    port = 0 :: inet:port_number(),
    path = <<>> :: binary(),
    opts = [] :: list(),
    headers = [] :: list(),
    ext_opts = [] :: list(),
    ext_headers = [] :: list(),
    disp = <<>> :: binary()
}).

-define(KZSIP_URI_HRL, 'true').
-endif.
