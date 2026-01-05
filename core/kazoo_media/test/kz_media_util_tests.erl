%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2021, 2600Hz
%%% @doc Tests for kz_media_util
%%% @author James Aimonetti
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_media_util_tests).

-include("kazoo_media.hrl").
-include_lib("eunit/include/eunit.hrl").

all_test_() ->
    {setup, fun setup_fixtures/0, fun cleanup/1, fun(_) ->
        [{"Testing get prompt", get_prompt_()}]
    end}.

setup_fixtures() ->
    ?LOG_DEBUG(":: Setting up Kazoo Media test"),

    Pid =
        case kz_fixturedb_util:start_me() of
            {error, {already_started, P}} -> P;
            P when is_pid(P) -> P
        end,

    meck:new(kz_datamgr, [unstick, passthrough]),

    meck:new(kz_fixturedb_db, [unstick, passthrough]),

    Pid.

cleanup(Pid) ->
    kz_fixturedb_util:stop_me(Pid),
    meck:unload().

get_prompt_() ->
    Tests = [
        {"untouched tone_stream", [<<"tone_stream://%(250,250,480,620);loops=25">>],
            <<"tone_stream://%(250,250,480,620);loops=25">>},
        {"untouched tone_stream with lang",
            [<<"tone_stream://%(250,250,480,620);loops=25">>, <<"en-us">>],
            <<"tone_stream://%(250,250,480,620);loops=25">>},
        {"untouched tone_stream with lang and account",
            [<<"tone_stream://%(250,250,480,620);loops=25">>, <<"en-us">>, kz_binary:rand_hex(16)],
            <<"tone_stream://%(250,250,480,620);loops=25">>},

        {"untouched prompt", [<<"prompt://system_media/vm-full/en-us">>],
            <<"prompt://system_media/vm-full/en-us">>},
        {"full prompt path", [<<"vm-full">>], <<"prompt://system_media/vm-full/en-us">>},
        {"full prompt path with lang", [<<"vm-full">>, <<"mk-bs">>],
            <<"prompt://system_media/vm-full/mk-bs">>}
    ],

    [
        {Description, ?_assertEqual(Expected, apply_get_prompt(Args))}
     || {Description, Args, Expected} <- Tests
    ].

apply_get_prompt([Name]) ->
    kz_media_util:get_prompt(Name);
apply_get_prompt([Name, Lang]) ->
    kz_media_util:get_prompt(Name, Lang);
apply_get_prompt([Name, Lang, AccountId]) ->
    kz_media_util:get_prompt(Name, Lang, AccountId).
