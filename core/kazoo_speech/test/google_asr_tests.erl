%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(google_asr_tests).

-include_lib("eunit/include/eunit.hrl").
-include("kazoo_speech.hrl").

-define(ASR_PROVIDER_DEFAULT, <<"ispeech">>).
-define(ASR_ACCEPT_DEFAULT, [<<"audio/mpeg">>, <<"audio/wav">>, <<"application/wav">>]).

-define(ASR_PREF_GOOGLE, <<"application/wav">>).
-define(ASR_PREF_ISPEECH, <<"application/wav">>).

all_test_() ->
    {'setup', fun setup_fixtures/0, fun cleanup/1, fun(_) ->
        [
            {"kazoo_asr google provider abstraction.", google_asr_provider()}
        ]
    end}.

setup_fixtures() ->
    ?LOG_DEBUG(":: Setting up Google Speech test"),
    meck:new(kapps_config, [unstick]),
    ok.

cleanup(_) ->
    meck:unload().

%%------------------------------------------------------------------------------
%%  Mock google kapps_config calls
%%------------------------------------------------------------------------------
config_asr_google(_, <<"asr_provider">>, _) ->
    <<"google">>.

%%------------------------------------------------------------------------------
%% Test Cases
%%------------------------------------------------------------------------------
google_asr_provider() ->
    meck:expect('kapps_config', 'get_ne_binary', fun config_asr_google/3),
    [{"Checking google is default ASR", ?_assertEqual(kazoo_asr:default_provider(), <<"google">>)}].
