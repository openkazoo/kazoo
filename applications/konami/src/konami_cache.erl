-module(konami_cache).

-export([cache_or_fail/1]).

-export([spec/0]).

-include("konami.hrl").

-spec cache_or_fail(any()) -> boolean().
cache_or_fail(Key) ->
    case kz_cache:fetch_local(?MODULE, Key) of
        {'ok', 'true'} ->
            'false';
        {'error', 'not_found'} ->
            kz_cache:store_local(?MODULE, Key, 'true'),
            true
    end.

-spec spec() -> kz_types:sup_child_spec().
spec() ->
    ?CACHE(?MODULE).
