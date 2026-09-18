#!/usr/bin/env escript
%%! +A0 -hidden
%% -*- coding: utf-8 -*-

%%%-----------------------------------------------------------------------------
%%% @doc Measure what `int' interpretation costs inside the live dev node.
%%%
%%% A step-debug breakpoint interprets the whole module it sits in (`int:i/1'),
%%% and interpreted code is one to two orders of magnitude slower -- every call
%%% to that module, from every process, routes through a single meta-interpreter.
%%% This script quantifies that so the runbook can say where a breakpoint is safe
%%% on a running node and where it is not (issue #50).
%%%
%%% It measures, for a leaf module (`kz_mochinum', proven interpretable in #34)
%%% and a hot data module (`kz_json'):
%%%   * per-call latency, compiled vs interpreted;
%%%   * throughput under 8-way concurrency, compiled vs interpreted -- the number
%%%     that actually matters, because `int' serializes and the penalty grows
%%%     with the number of concurrent callers; and
%%%   * the one-time cost of `int:i/1' itself (the pause when a breakpoint is set)
%%%     across modules of different sizes.
%%%
%%% The node is left exactly as found: nothing stays interpreted.
%%%
%%% Timing runs *on the node* -- an AST is shipped to `erl_eval:exprs/2', so it
%%% uses only node-side modules and its output carries back over our group leader
%%% (the same reason `scripts/dev_init.escript' uses `rpc' rather than `eval').
%%%
%%% Usage: boot the node (Start Kazoo, or `scripts/dev-node.sh daemon'), then:
%%%     scripts/int-bench.escript
%%% Numbers are hardware-specific; re-run to characterise your own machine.
%%% @end
%%%-----------------------------------------------------------------------------

-mode(compile).
-export([main/1]).

-define(COOKIE, "kazoo_dev_cookie").

%% enough iterations to swamp scheduling noise; best-of-N sheds GC spikes
-define(PER_CALL_N, 200000).
-define(CONC_K, 8).
-define(CONC_M, 50000).

main(_) ->
    _ = io:setopts('user', [{'encoding', 'unicode'}]),
    Node = list_to_atom("kazoo_apps@" ++ net_adm:localhost()),
    ok = connect(Node),
    report_node(Node),
    clean_all(Node),
    bench_module(Node, "kz_mochinum",
                 "kz_mochinum:digits(1.2345678901234567)"),
    bench_module(Node, "kz_json",
                 "kz_json:get_value(<<\"a\">>,"
                 " kz_json:from_list([{<<\"a\">>,1},{<<\"b\">>,2}]))"),
    setup_cost(Node, [kz_mochinum, kz_term, kz_json, kazoo_bindings, cb_context]),
    health(Node),
    halt(0).

%%% Steps

connect(Node) ->
    _ = os:cmd("epmd -daemon"),
    Host = host_of(atom_to_list(Node)),
    Self = list_to_atom("kz_int_bench_" ++ os:getpid() ++ "@" ++ Host),
    {ok, _} = net_kernel:start([Self, name_type(Host)]),
    true = erlang:set_cookie(node(), list_to_atom(?COOKIE)),
    case net_adm:ping(Node) of
        pong -> ok;
        pang ->
            abort("cannot reach ~s with cookie ~s -- is the node booted?~n"
                  "  Start it with the \"Start Kazoo\" task or"
                  " `scripts/dev-node.sh daemon'.", [Node, ?COOKIE])
    end.

report_node(Node) ->
    Apps = rpc(Node, application, which_applications, []),
    Ready = rpc(Node, kapps_controller, ready, []),
    Sched = rpc(Node, erlang, system_info, [schedulers_online]),
    io:format("node ~s: ~b OTP apps, kapps_controller:ready()=~p, ~b schedulers~n~n",
              [Node, length(Apps), Ready, Sched]).

%% leave nothing interpreted from a previous interrupted run
clean_all(Node) ->
    case rpc(Node, int, interpreted, []) of
        [] -> ok;
        Mods ->
            io:format("clearing ~b already-interpreted module(s): ~p~n~n",
                      [length(Mods), Mods]),
            _ = [rpc(Node, int, n, [M]) || M <- Mods],
            ok
    end.

bench_module(Node, ModStr, CallStr) ->
    Mod = list_to_atom(ModStr),
    io:format("### ~s : ~s~n", [ModStr, CallStr]),
    _ = per_call(Node, CallStr, 5000),                         %% warm
    Base = per_call(Node, CallStr, ?PER_CALL_N),
    ok = interpret(Node, Mod),
    Int = per_call(Node, CallStr, ?PER_CALL_N),
    io:format("  per-call:  compiled ~.3f us   interpreted ~.3f us   x~.1f~n",
              [Base, Int, ratio(Int, Base)]),
    IntC = concurrent(Node, CallStr, ?CONC_K, ?CONC_M),        %% still interpreted
    ok = uninterpret(Node, Mod),
    BaseC = concurrent(Node, CallStr, ?CONC_K, ?CONC_M),
    io:format("  ~bx~b concurrent wall:  compiled ~.1f ms   interpreted ~.1f ms   x~.1f~n~n",
              [?CONC_K, ?CONC_M, BaseC/1000, IntC/1000, ratio(IntC, BaseC)]).

setup_cost(Node, Mods) ->
    io:format("int:i/1 one-time interpret cost (module -> ms):~n"),
    [begin
         Str = io_lib:format("{US,_} = timer:tc(int, i, [~s]), US.", [M]),
         US = eval(Node, Str),
         _ = rpc(Node, int, n, [M]),
         io:format("  ~-22s ~7.1f ms~n", [M, US/1000])
     end || M <- Mods],
    io:format("~n").

health(Node) ->
    Interp = rpc(Node, int, interpreted, []),
    RunQ = rpc(Node, erlang, statistics, [run_queue]),
    Procs = rpc(Node, erlang, system_info, [process_count]),
    io:format("node left: interpreted=~p  run_queue=~p  processes=~p~n",
              [Interp, RunQ, Procs]).

%%% Benchmarks (run on the node)

%% microseconds per call, single process, best-of-3
per_call(Node, CallStr, N) ->
    Expr = io_lib:format(
        "T = fun F(0) -> ok; F(K) -> _ = ~s, F(K-1) end,"
        "{US,_} = timer:tc(fun() -> T(~b) end), US / ~b.",
        [CallStr, N, N]),
    lists:min([eval(Node, Expr) || _ <- [1,2,3]]).

%% total wall-clock microseconds for K procs each doing M calls, best-of-2
concurrent(Node, CallStr, K, M) ->
    Expr = io_lib:format(
        "Parent = self(),"
        "Work = fun F(0) -> ok; F(K) -> _ = ~s, F(K-1) end,"
        "{US,_} = timer:tc(fun() ->"
        "  Pids = [spawn_link(fun() -> Work(~b), Parent ! {done, self()} end)"
        "          || _ <- lists:seq(1, ~b)],"
        "  [receive {done, P} -> ok end || P <- Pids]"
        "end), US.",
        [CallStr, M, K]),
    lists:min([eval(Node, Expr) || _ <- [1,2]]).

%%% Internals

interpret(Node, Mod) ->
    case rpc(Node, int, i, [Mod]) of
        {module, Mod} -> ok;
        Other -> abort("int:i(~s) -> ~p", [Mod, Other])
    end.

uninterpret(Node, Mod) ->
    _ = rpc(Node, int, n, [Mod]),
    ok.

%% ship an AST to erl_eval on the node; returns the value of the last expression
eval(Node, ExprIoList) ->
    Str = lists:flatten(ExprIoList),
    {ok, Tokens, _} = erl_scan:string(Str),
    {ok, Exprs} = erl_parse:parse_exprs(Tokens),
    case rpc:call(Node, erl_eval, exprs, [Exprs, []], 120000) of
        {value, V, _Bindings} -> V;
        {badrpc, R} -> abort("eval badrpc ~p for: ~s", [R, Str])
    end.

rpc(Node, M, F, A) ->
    case rpc:call(Node, M, F, A, 60000) of
        {badrpc, R} -> abort("~s:~s/~b badrpc: ~p", [M, F, length(A), R]);
        V -> V
    end.

ratio(_, B) when B == 0.0 -> 0.0;
ratio(A, B) -> A / B.

host_of(NodeStr) ->
    case string:split(NodeStr, "@", trailing) of
        [_, Host] when Host =/= "" -> Host;
        _ -> abort("'~s' is not name@host", [NodeStr])
    end.

name_type(Host) ->
    case lists:member($., Host) of true -> longnames; false -> shortnames end.

-spec abort(string(), list()) -> no_return().
abort(Format, Args) ->
    io:format(standard_error, "int-bench: " ++ Format ++ "~n", Args),
    halt(1).
