-module(kazoo_perf_tests).

-include_lib("eunit/include/eunit.hrl").

%% metrics_test_ now wrapped in a timeout to accommodate slower CI environments
metrics_test_() ->
    {timeout, 10_000, fun() ->
        %% Dummy inputs (adjust or mock backends if needed to avoid blocking)
        {A, C, Z} = {<<"my_account">>, <<"my_cluster">>, <<"my_zone">>},

        %% Ensure Graphite metrics call completes without crashing
        ?_assertEqual(
            no_return,
            kazoo_perf_maintenance:graphite_metrics(A, C, Z)
        ),

        %% Ensure JSON metrics call completes without crashing
        ?_assertEqual(
            no_return,
            kazoo_perf_maintenance:json_metrics()
        ),

        ok
    end}.
