#!/usr/bin/env escript
%%! +A0 -hidden
%% -*- coding: utf-8 -*-

%%%-----------------------------------------------------------------------------
%%% @doc Kazoo-level database bootstrap for the local dev node.
%%%
%%% Runs the SUP maintenance sequence that makes a fresh CouchDB usable:
%%% register views, refresh every database, and create the master account.
%%% Re-runnable -- every step is idempotent, and an existing master account is
%%% reported and left alone.
%%%
%%% Driven by `scripts/dev-init.sh', which supplies the node name and cookie
%%% read out of `config/vm.args.dev'. Run it through that wrapper rather than
%%% directly; the defaults below only keep this script usable on its own.
%%%
%%% == Why not core/sup/priv/sup ==
%%%
%%% `sup' builds its target as `Node ++ "@" ++ net_adm:localhost()', so it always
%%% aims at whatever hostname the machine advertises. It cannot address the dev
%%% node, which is named on a literal IP -- `kazoo_apps@127.0.0.1', see
%%% config/vm.args.dev for why. It also picks longnames/shortnames off that same
%%% hostname. This script takes the host from the node name it was given instead.
%%%
%%% == Why not bin/kazoo eval ==
%%%
%%% The release's `eval'/`rpc' go through `erl_call', which leaves the evaluated
%%% expression's group leader on the target node: `kapps_maintenance:refresh/0'
%%% prints a line per database and every one of them lands in the node's console
%%% log instead of the caller's terminal. `rpc:call/4' from a real Erlang node
%%% carries our group leader across, so the progress output arrives here.
%%% @end
%%%-----------------------------------------------------------------------------

-mode(compile).

-export([main/1]).

%% refresh/0 walks every database in the cluster; on a cold CouchDB that is a
%% few minutes of view building, so it gets its own far longer budget.
-define(REFRESH_TIMEOUT, 900 * 1000).
-define(STEP_TIMEOUT, 120 * 1000).

-define(DEFAULTS, #{node => "kazoo_apps@127.0.0.1"
                   ,cookie => "kazoo_dev_cookie"
                   ,account_name => "master"
                   ,realm => "master.dev.local"
                   ,username => "admin"
                   ,password => "admin"
                   }).

%%% API

main(Args) ->
    _ = io:setopts('user', [{'encoding', 'unicode'}]),
    Opts = parse_args(Args, ?DEFAULTS),
    'ok' = connect(Opts),
    'ok' = check_datastore(Opts),
    'ok' = register_views(Opts),
    'ok' = refresh(Opts),
    'ok' = master_account(Opts),
    summarize(Opts),
    halt(0).

%%% Steps

%% Join the node's distribution the way the node names itself: take the host
%% straight off the target so we land on the same side of the
%% longnames/shortnames split, and never consult net_adm:localhost/0.
connect(#{node := NodeStr, cookie := CookieStr}) ->
    _ = os:cmd("epmd -daemon"),
    Node = list_to_atom(NodeStr),
    Host = host_of(NodeStr),
    Self = list_to_atom("kz_dev_init_" ++ os:getpid() ++ "@" ++ Host),
    case net_kernel:start([Self, name_type(Host)]) of
        {'ok', _} -> 'ok';
        {'error', Reason} ->
            abort("could not start distribution as ~s: ~p", [Self, Reason])
    end,
    'true' = erlang:set_cookie(node(), list_to_atom(CookieStr)),
    case net_adm:ping(Node) of
        'pong' ->
            step("connected to ~s", [Node]);
        'pang' ->
            abort("cannot reach ~s with cookie ~s.~n"
                  "~n"
                  "  * Is the node running? Start it with the \"Start Kazoo\" task, or:~n"
                  "      KAZOO_CONFIG=$PWD/config/config-dev.ini \\~n"
                  "      VMARGS_PATH=$PWD/config/vm.args.dev \\~n"
                  "      RELX_CONFIG_PATH=$PWD/config/sys-dev.config \\~n"
                  "        _build/dev/rel/kazoo/bin/kazoo foreground~n"
                  "  * If it is running, the cookie disagrees: -setcookie in~n"
                  "    config/vm.args.dev must match [kazoo_apps] cookie in~n"
                  "    config/config-dev.ini, which wins once the node has booted."
                 ,[Node, CookieStr]
                 )
    end.

%% Proves CouchDB is reachable *from the node* before any step depends on it --
%% otherwise the first failure surfaces as an opaque refresh error.
check_datastore(Opts) ->
    case call(Opts, 'kz_datamgr', 'db_info', [], ?STEP_TIMEOUT) of
        {'ok', Dbs} ->
            step("CouchDB reachable from the node (~b databases)", [length(Dbs)]);
        {'error', Reason} ->
            abort("the node cannot reach CouchDB (~p).~n"
                  "~n"
                  "  * Bring the infra up:  docker compose -f docker-compose.dev.yml up -d~n"
                  "  * Host, port and credentials must match between~n"
                  "    docker-compose.dev.yml and config/config-dev.ini."
                 ,[Reason]
                 )
    end.

register_views(Opts) ->
    step("registering views", []),
    case call(Opts, 'kapps_maintenance', 'register_views', [], ?STEP_TIMEOUT) of
        'ok' -> 'ok';
        Other -> abort("register_views returned ~p", [Other])
    end.

%% refresh/0 answers 'no_return' -- it reports per-database trouble by printing
%% rather than by its return value, and that output streams back to us.
refresh(Opts) ->
    step("refreshing databases (this is the slow one on a cold CouchDB)", []),
    case call(Opts, 'kapps_maintenance', 'refresh', [], ?REFRESH_TIMEOUT) of
        'no_return' -> 'ok';
        Other -> abort("refresh returned ~p", [Other])
    end.

master_account(#{account_name := Name, realm := Realm
                ,username := User, password := Pass
                }=Opts) ->
    case call(Opts, 'kapps_util', 'get_master_account_id', [], ?STEP_TIMEOUT) of
        {'ok', AccountId} ->
            step("master account already exists (~s) -- leaving it alone", [AccountId]);
        {'error', 'no_accounts'} ->
            step("creating master account '~s' (realm ~s)", [Name, Realm]),
            create_account(Opts, [bin(Name), bin(Realm), bin(User), bin(Pass)]);
        {'error', Reason} ->
            abort("could not read the master account: ~p", [Reason])
    end.

%% The first account created is promoted to sysadmin by
%% crossbar_maintenance:maybe_promote_account/1, which is what makes it the
%% master -- so confirm the promotion landed rather than trusting the 'ok'.
create_account(Opts, Args) ->
    case call(Opts, 'crossbar_maintenance', 'create_account', Args, ?STEP_TIMEOUT) of
        'ok' ->
            case call(Opts, 'kapps_util', 'get_master_account_id', [], ?STEP_TIMEOUT) of
                {'ok', AccountId} ->
                    step("master account created: ~s", [AccountId]);
                Other ->
                    abort("account was created but did not become the master account: ~p"
                         ,[Other]
                         )
            end;
        'failed' ->
            abort("create_account failed -- see the reason printed above", []);
        Other ->
            abort("create_account returned ~p", [Other])
    end.

summarize(#{node := Node, account_name := Name, realm := Realm
           ,username := User, password := Pass
           }) ->
    out("", []),
    out("Database initialized on ~s", [Node]),
    out("  account   ~s", [Name]),
    out("  realm     ~s", [Realm]),
    out("  login     ~s / ~s", [User, Pass]),
    out("", []),
    out("Re-running this is safe: views and databases are refreshed again and an", []),
    out("existing master account is left as it is.", []).

%%% Internals

%% rpc:call/5 so io:format/2 inside the maintenance modules reaches our group
%% leader; badrpc is turned into a message that names the call that failed.
call(#{node := NodeStr}, M, F, A, Timeout) ->
    Node = list_to_atom(NodeStr),
    case rpc:call(Node, M, F, A, Timeout) of
        {'badrpc', 'timeout'} ->
            abort("~s:~s/~b timed out after ~bs", [M, F, length(A), Timeout div 1000]);
        {'badrpc', Reason} ->
            abort("~s:~s/~b failed: ~p", [M, F, length(A), Reason]);
        Result -> Result
    end.

host_of(NodeStr) ->
    case string:split(NodeStr, "@", 'trailing') of
        [_Name, Host] when Host =/= "" -> Host;
        _ -> abort("'~s' is not a fully qualified node name (name@host)", [NodeStr])
    end.

%% Matches the emulator's own rule: a dotted host means longnames. The dev node
%% is named on a literal IP, so both sides land on longnames.
name_type(Host) ->
    case lists:member($., Host) of
        'true' -> 'longnames';
        'false' -> 'shortnames'
    end.

bin(Str) -> unicode:characters_to_binary(Str).

parse_args([], Opts) -> Opts;
parse_args(["--node", V | Rest], Opts) -> parse_args(Rest, Opts#{node => V});
parse_args(["--cookie", V | Rest], Opts) -> parse_args(Rest, Opts#{cookie => V});
parse_args(["--account-name", V | Rest], Opts) -> parse_args(Rest, Opts#{account_name => V});
parse_args(["--realm", V | Rest], Opts) -> parse_args(Rest, Opts#{realm => V});
parse_args(["--username", V | Rest], Opts) -> parse_args(Rest, Opts#{username => V});
parse_args(["--password", V | Rest], Opts) -> parse_args(Rest, Opts#{password => V});
parse_args([Unknown | _], _Opts) -> abort("unknown argument '~s'", [Unknown]).

step(Format, Args) ->
    out("==> " ++ Format, Args).

out(Format, Args) ->
    io:format('standard_io', Format ++ "~n", Args).

-spec abort(string(), list()) -> no_return().
abort(Format, Args) ->
    io:format('standard_error', "dev-init: " ++ Format ++ "~n", Args),
    halt(1).

%% End of Module
