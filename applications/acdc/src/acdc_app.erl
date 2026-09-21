%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2020, 2600Hz
%%% @doc
%%% @author James Aimonetti
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(acdc_app).

-behaviour(application).

-include("acdc.hrl").

%% Application callbacks
-export([start/2, stop/1]).

%% Crossbar and blackhole modules ship with this application; register them so a
%% default deployment loads their REST endpoints and websocket bindings.
-define(INTEGRATION_MODULES
       ,[{'cb_agents', 'crossbar_maintenance', 'start_module'}
        ,{'cb_queues', 'crossbar_maintenance', 'start_module'}
        ,{'cb_acdc_call_stats', 'crossbar_maintenance', 'start_module'}
        ,{'bh_acdc_agent', 'blackhole_maintenance', 'start_module'}
        ,{'bh_acdc_member', 'blackhole_maintenance', 'start_module'}
        ,{'bh_acdc_queue', 'blackhole_maintenance', 'start_module'}
        ]).

%%==============================================================================
%% Application callbacks
%%==============================================================================

%%------------------------------------------------------------------------------
%% @doc Implement the application start behaviour.
%% @end
%%------------------------------------------------------------------------------
-spec start(application:start_type(), any()) -> kz_types:startapp_ret().
start(_StartType, _StartArgs) ->
    acdc_maintenance:register_views(),
    _ = kapps_maintenance:bind_and_register_views('acdc', 'acdc_maintenance', 'register_views'),
    _ = kapps_maintenance:bind({'refresh_account', <<"*">>}, 'acdc_maintenance', 'refresh_account'),
    kz_module:application_integrations(?INTEGRATION_MODULES),
    acdc_sup:start_link().

%%------------------------------------------------------------------------------
%% @doc Implement the application stop behaviour.
%% @end
%%------------------------------------------------------------------------------
-spec stop(any()) -> any().
stop(_State) ->
    _ = kapps_maintenance:unbind('register_views', 'acdc_maintenance', 'register_views'),
    _ = kapps_maintenance:unbind({'refresh_account', <<"*">>}, 'acdc_maintenance', 'refresh_account'),
    'ok'.
