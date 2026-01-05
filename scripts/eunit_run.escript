#!/usr/bin/env escript
%%! +A0
%%! -sasl sasl_error_logger {file, "sasl.log"}
%%! -noshell -noinput
%% -*- coding: utf-8 -*-

-mode(compile).

-export([main/1]).

main(Args) ->
    _ = io:setopts('user', [{'encoding', 'unicode'}]),
    maybe_add_ebin(),
    Opts = parse_args(Args, #{applications => [], results => []}),
    io:format("Applications under test ~p~n", [maps:get(applications, Opts)]),
    Results = lists:foldr(
        fun(A, Acc) -> run_app_tests(A, Acc) end, Opts, maps:get(applications, Opts)
    ),
    summarize(Results),
    erlang:halt().

maybe_add_ebin() ->
    {'ok', CWD} = file:get_cwd(),
    Ebin = filename:join([CWD, "ebin"]),
    case filelib:is_dir(Ebin) of
        'true' -> code:add_patha(Ebin);
        'false' -> 'ok'
    end.

parse_args([], Opts) ->
    Opts;
parse_args(["--with-cover" | Rest], Opts) ->
    parse_args(Rest, Opts#{cover => 'true'});
parse_args(["--cover-project-name", ProjectName | Rest], Opts) ->
    parse_args(Rest, Opts#{coverdata => ProjectName ++ ".coverdata"});
parse_args(["--cover-report-dir", Dir | Rest], Opts) ->
    parse_args(Rest, Opts#{report_dir => Dir});
parse_args([App | Rest], #{applications := Applications} = Opts) ->
    parse_args(Rest, Opts#{applications => [App | Applications]}).

test_modules(#{modules := []}) ->
    io:format('user', "No applicationss are specified.\n", []),
    usage();
test_modules(#{modules := Modules} = Opts) ->
    _Cover = maybe_start_cover(Opts),
    R = [test_module(Mod) || Mod <- Modules],
    maybe_stop_cover(Opts),
    R.

summarize(#{results := Results}) ->
    io:format("~n📋 Test Summary~n"),
    Summary = [summarize(App, R) || {App, R} <- lists:reverse(Results)],
    case lists:any(fun(Res) -> Res =:= fail end, Summary) of
        % fail CI
        true -> erlang:halt(1);
        false -> 'ok'
    end.

summarize(App, Results) ->
    io:format("~n📋   ~s Test Summary~n", [App]),
    [print_result(R) || R <- Results],
    case lists:any(fun({_M, Res}) -> Res =/= passed end, Results) of
        % fail CI
        true -> 'fail';
        false -> 'pass'
    end.

print_result({Mod, passed}) ->
    io:format("✅     ~p: Passed~n", [Mod]);
print_result({Mod, {failed, Reason}}) ->
    io:format("❌     ~p: Failed - ~p~n", [Mod, Reason]);
print_result({Mod, {unknown, What}}) ->
    io:format("❓     ~p: Unknown result - ~p~n", [Mod, What]).

test_module(Mod) ->
    io:format("🧪 Running ~p~n", [Mod]),
    case
        catch eunit:test(Mod, [
            {verbose, true},
            {print_depth, 10},
            {report, {eunit_surefire, [{dir, "./_build/test/logs"}]}}
        ])
    of
        ok ->
            {Mod, passed};
        {'EXIT', Reason} ->
            {Mod, {failed, Reason}};
        Other ->
            {Mod, {unknown, Other}}
    end.

maybe_start_cover(
    #{
        cover := 'true',
        coverdata := _
    } = Opts
) ->
    'ok' = filelib:ensure_dir(maps:get('report_dir', Opts, "cover") ++ "/dummy"),
    _ = cover:start(),
    cover:compile_beam_directory("test");
maybe_start_cover(#{cover := 'true'}) ->
    io:format('user', "No project name is specified.\n", []),
    usage();
maybe_start_cover(_) ->
    'ok'.

maybe_stop_cover(
    #{
        cover := 'true',
        coverdata := Coverdata
    } = Opts
) ->
    cover:export(Coverdata),
    cover:analyse_to_file(['html', {'outdir', maps:get('report_dir', Opts, "cover")}]);
maybe_stop_cover(_) ->
    'ok'.

run_app_tests(App, #{results := Results} = Opts) ->
    io:format("Application under test ~s~n", [App]),
    {ok, Modules} = get_modules(App),
    Res = test_modules(Opts#{modules => Modules}),
    Opts#{results => [{App, Res} | Results]}.

get_modules(App) ->
    %% Assumes standard layout like apps/my_app/ebin/*.beam
    AppPath = filename:join(["./_build/test/lib", App, "test"]),
    code:add_path(AppPath),
    Beams = filelib:wildcard(filename:join(AppPath, "*test*.beam")),
    Mods = [list_to_atom(filename:basename(File, ".beam")) || File <- Beams],
    {ok, Mods}.

usage() ->
    Arg0 = escript:script_name(),
    io:format(
        'user',
        "Usage: ~s [--with-cover] [--cover-project-name <project name>] [--cover-report-dir <cover report dir>] <erlang module name/>+\n",
        [filename:basename(Arg0)]
    ),
    halt(1).
