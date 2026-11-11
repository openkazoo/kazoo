%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2026, open-kazoo
%%% @doc The ecallmgr stats follow whether ecallmgr is running on this node,
%%% not what the node is called, so a combined node reports them too.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_stats_tests).
-behaviour(supervisor).

-include_lib("eunit/include/eunit.hrl").

-export([init/1
        ,start_idle/0
        ]).

no_ecallmgr_test() ->
    'undefined' = whereis('ecallmgr_sup'),
    ?assertEqual([], kazoo_stats:get_ecallmgr_values([])).

ecallmgr_running_test_() ->
    {'setup'
    ,fun start_fake_ecallmgr/0
    ,fun stop_fake_ecallmgr/1
    ,fun(_) ->
             Values = kazoo_stats:get_ecallmgr_values([]),
             [?_assertEqual(['processes', 'reduction', 'register-fail']
                           ,lists:sort(proplists:get_keys(Values))
                           )
              %% ecallmgr_sup and its 3 workers, not every process in the VM
             ,?_assertEqual(4, proplists:get_value('processes', Values))
             ]
     end
    }.

%%------------------------------------------------------------------------------
%% A stand-in for ecallmgr: a supervisor registered as `ecallmgr_sup' with
%% `Workers' children, started under its own group leader the way an OTP
%% application master would start it.
%%------------------------------------------------------------------------------
start_fake_ecallmgr() ->
    start_fake_ecallmgr(3).

start_fake_ecallmgr(Workers) ->
    Parent = self(),
    GroupLeader = spawn(fun group_leader_loop/0),
    Starter = spawn(fun() ->
                            group_leader(GroupLeader, self()),
                            {'ok', Sup} = supervisor:start_link({'local', 'ecallmgr_sup'}, ?MODULE, Workers),
                            unlink(Sup),
                            Parent ! {'started', self(), Sup}
                    end),
    receive {'started', Starter, Sup} -> {GroupLeader, Sup} end.

stop_fake_ecallmgr({GroupLeader, Sup}) ->
    Ref = monitor('process', Sup),
    %% Not its parent, so a 'shutdown' would be ignored; its linked workers
    %% die with it.
    exit(Sup, 'kill'),
    receive {'DOWN', Ref, _, _, _} -> 'ok' end,
    exit(GroupLeader, 'kill').

init(Workers) ->
    Children = [#{id => Id
                 ,start => {?MODULE, 'start_idle', []}
                 }
                || Id <- lists:seq(1, Workers)
               ],
    {'ok', {#{}, Children}}.

start_idle() ->
    {'ok', spawn_link(fun idle/0)}.

idle() ->
    receive _ -> idle() end.

%% Answers io requests so anything that prints under this group leader works.
group_leader_loop() ->
    receive
        {'io_request', From, ReplyAs, _} -> From ! {'io_reply', ReplyAs, 'ok'};
        _ -> 'ok'
    end,
    group_leader_loop().
