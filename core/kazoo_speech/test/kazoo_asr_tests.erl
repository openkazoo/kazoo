%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2021, 2600Hz
%%% @doc This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kazoo_asr_tests).

-include_lib("eunit/include/eunit.hrl").
-include("kazoo_speech.hrl").

-define(ASR_PROVIDER_DEFAULT, <<"ispeech">>).
-define(ASR_ACCEPT_DEFAULT, [<<"audio/mpeg">>, <<"audio/wav">>, <<"application/wav">>]).

-define(ASR_PREF_GOOGLE, <<"application/wav">>).
-define(ASR_PREF_ISPEECH, <<"application/wav">>).

all_test_() ->
    {'setup', fun setup_fixtures/0, fun cleanup/1, fun(_) ->
        [
            {"kazoo_asr system default provider abstraction.", default_asr_provider()},
            {"kazoo_asr system default accepted content types test.", default_asr_accept()}
        ]
    end}.

setup_fixtures() ->
    ?LOG_DEBUG(":: Setting up Kazoo Speech test"),
    ok.

cleanup(_) ->
    ok.

%%------------------------------------------------------------------------------
%% Test Cases
%%------------------------------------------------------------------------------
default_asr_provider() ->
    [
        {"Checking system default ASR provider",
            ?_assertEqual(kazoo_asr:default_provider(), ?ASR_PROVIDER_DEFAULT)}
    ].

default_asr_accept() ->
    [
        {"Checking system default accepted content type",
            ?_assertEqual(kazoo_asr:accepted_content_types(), ?ASR_ACCEPT_DEFAULT)}
    ].
