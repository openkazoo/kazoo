-module(cb_context_tests).

-include_lib("eunit/include/eunit.hrl").

-spec path_tokens_test_() -> [tuple()].
path_tokens_test_() ->
    [{"Preserve literal plus in path segment"
     ,?_assertEqual(<<"+12223334444">>, last_path_token(<<"/+12223334444">>))
     }
    ,{"Preserve encoded plus in path segment"
     ,?_assertEqual(<<"+12223334444">>, last_path_token(<<"/%2B12223334444">>))
     }
    ,{"Decode encoded spaces in path segment"
     ,?_assertEqual(<<"a b">>, last_path_token(<<"/a%20b">>))
     }
    ].

-spec path_tokens(binary()) -> [binary()].
path_tokens(Path) ->
    cb_context:path_tokens(cb_context:set_raw_path(cb_context:new(), Path)).

-spec last_path_token(binary()) -> binary().
last_path_token(Path) ->
    lists:last(path_tokens(Path)).
