%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2026, open-kazoo
%%% @doc A node is reported as `ecallmgr' only when ecallmgr is all it runs. A
%%% combined node, running ecallmgr alongside other kapps, counts as a kapps
%%% node, and its FreeSWITCH media servers are still counted.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kztm_node_type_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("kazoo_stdlib/include/kz_records.hrl").

-define(MEDIA_SERVER, <<"freeswitch@fs1.example.com">>).

node_type_test_() ->
    [?_assertEqual(<<"ecallmgr">>, type_of(node_running([<<"ecallmgr">>])))
    ,?_assertEqual(<<"kapps">>, type_of(node_running([<<"callflow">>, <<"crossbar">>])))
    ,?_assertEqual(<<"kapps">>, type_of(node_running([<<"callflow">>, <<"ecallmgr">>])))
    ].

combined_node_media_servers_test() ->
    Node = (node_running([<<"callflow">>, <<"ecallmgr">>]))#kz_node{media_servers=[{?MEDIA_SERVER, kz_json:new()}]},
    ?assertEqual([?MEDIA_SERVER]
                ,kz_json:get_keys(waveguide_reducer:dedupe_media_servers([extract(Node)]))
                ).

node_running(Kapps) ->
    #kz_node{node='kazoo_apps@host.example.com'
            ,version= <<"4.4">>
            ,zone='local'
            ,kapps=[{Kapp, #whapp_info{}} || Kapp <- Kapps]
            }.

type_of(Node) ->
    kz_json:get_ne_binary_value(<<"type">>, extract(Node)).

extract(Node) ->
    [Extracted] = kztm_nodes_extractor:normalize_kz_nodes([Node]),
    Extracted.
