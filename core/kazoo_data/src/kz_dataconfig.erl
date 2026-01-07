%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @author Dialwave, Inc. (Rob Nichols)
%%% @doc
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_dataconfig).

-include("kz_data.hrl").

%%==============================================================================
%% API functions
%%==============================================================================

-export([connection/0, connection/1]).

-spec ensure_driver_app(map()) -> any().
ensure_driver_app(#{app := App}) ->
    application:ensure_all_started(App);
ensure_driver_app(#{driver := App}) ->
    application:ensure_all_started(App).

-spec is_driver_app(atom()) -> boolean().
is_driver_app(App) ->
    Funs = kz_data:behaviour_info('callbacks'),
    lists:all(fun({Fun, Arity}) -> erlang:function_exported(App, Fun, Arity) end, Funs).

-spec connection() -> data_connection().
connection() ->
    Section = kz_config:get_binary(<<"data">>, [<<"config">>], <<"couchdb">>),
    Props = kz_config:get_section_config(Section),
    connection(connection_options(Props)).

-spec connection_options(kz_term:proplist()) -> kz_term:proplist().
connection_options(Props) ->
    case props:get_first_defined([<<"connect_options">>, 'connect_options'], Props) of
        'undefined' ->
            Props;
        Section ->
            Options = kz_config:get_section_config(Section),
            [
                {<<"connect_options">>, Options}
                | props:delete('connect_options', props:delete(<<"connect_options">>, Props))
            ]
    end.

-spec connection(kz_term:proplist() | map()) -> data_connection().
connection(List) when is_list(List) ->
    connection(maps:from_list([{to_atom_key(K), V} || {K, V} <- List]));
connection(#{tag := Tag} = Map) when not is_atom(Tag) ->
    connection(Map#{tag => kz_term:to_atom(Tag, 'true')});
connection(#{driver := App} = Map) when
    not is_atom(App)
->
    connection(Map#{driver => kz_term:to_atom(App, 'true')});
connection(#{app := App} = Map) when
    not is_atom(App)
->
    connection(Map#{app => kz_term:to_atom(App, 'true')});
connection(#{module := App} = Map) when
    not is_atom(App)
->
    connection(Map#{module => kz_term:to_atom(App, 'true')});
connection(#{module := App, tag := Tag} = Map) ->
    _ = ensure_driver_app(Map),
    is_driver_app(App),
    #data_connection{props = Map, app = App, tag = Tag};
connection(#{driver := App, tag := Tag} = Map) ->
    _ = ensure_driver_app(Map),
    is_driver_app(App),
    #data_connection{props = Map, app = App, tag = Tag};
connection(#{} = Map) ->
    connection(maps:merge(?MERGE_MAP, Map)).

-spec to_atom_key(any()) -> atom().
to_atom_key(K) when is_atom(K) -> K;
to_atom_key(K) -> kz_term:to_atom(K, 'true').

%%==============================================================================
%% Internal functions
%%==============================================================================
