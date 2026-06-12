%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2026, 2600Hz
%%% @doc
%%% @author 2600Hz
%%% @author Circle Cloud
%%% @end
%%%-----------------------------------------------------------------------------
-module(pm_apple_dev).
-behaviour(gen_server).

-include("pusher.hrl").

-define(SERVER, ?MODULE).

-export([start_link/0]).

-export([init/1
        ,handle_call/3
        ,handle_cast/2
        ,handle_info/2
        ,terminate/2
        ,code_change/3
        ]).

-record(state, {tab :: ets:tid()}).
-type state() :: #state{}.

-define(APNS_MAP, [{<<"Alert-Key">>, [<<"aps">>, <<"alert">>, <<"loc-key">>]}
                  ,{<<"Alert-Params">>, [<<"aps">>, <<"alert">>, <<"loc-args">>]}
                  ,{<<"Sound">>, [<<"aps">>, <<"sound">>]}
                  ,{<<"Call-ID">>, [<<"aps">>, <<"call-id">>]}
                  ,{<<"Payload">>, fun kz_json:merge/2}
                  ]).

-spec start_link() -> kz_types:startlink_ret().
start_link() ->
    gen_server:start_link({'local', ?SERVER}, ?MODULE, [],[]).

-spec init([]) -> {'ok', state()}.
init([]) ->
    kz_util:put_callid(?MODULE),
    {'ok', #state{tab=ets:new(?MODULE, [])}}.

-spec handle_call(any(), kz_term:pid_ref(), state()) -> kz_types:handle_call_ret_state(state()).
handle_call(_Request, _From, State) ->
    {'reply', {'error', 'not_implemented'}, State}.

-spec handle_cast(any(), state()) -> kz_types:handle_cast_ret_state(state()).
handle_cast({'push', JObj}, #state{tab=ETS}=State) ->
    kz_util:put_callid(JObj),
    TokenApp = kz_json:get_value(<<"Token-App">>, JObj),
    lager:debug("received push request for ~p", [{TokenApp, ETS}]),
    maybe_send_push_notification(get_apns(TokenApp, ETS), JObj),
    {'noreply', State};
handle_cast('stop', State) ->
    {'stop', 'normal', State};
handle_cast(_Msg, State) ->
    lager:debug_unsafe("unhandled cast => ~p", [_Msg]),
    {'ok', State}.

-spec handle_info(any(), state()) -> kz_types:handle_info_ret_state(state()).
handle_info({'DOWN', Ref, 'process', Pid, Reason}, #state{tab=ETS}=State) ->
    _ = case ets:lookup(ETS, Ref) of
            [{Ref, App}] ->
                lager:warning("received down message for ~s / ~p / ~p => ~p", [App, Pid, Ref, Reason]),
                ets:delete(ETS, Ref),
                ets:delete(ETS, App),
                erlang:send_after(?MILLISECONDS_IN_SECOND * 5, self(), {'reload', App});
            _ ->
                lager:critical("app not found")
        end,
    {'noreply', State};
handle_info({'reload', App}, #state{tab=ETS}=State) ->
    _ = reload_apns(App, ETS),
    {'noreply', State};
handle_info(_Msg, State) ->
    lager:debug_unsafe("unhandled message => ~p", [_Msg]),
    {'noreply', State}.

-spec terminate(any(), state()) -> 'ok'.
terminate(_Reason, #state{tab=ETS}) ->
    apns:stop(),
    ets:delete(ETS),
    'ok'.

-spec code_change(any(), state(), any()) -> {'ok', state()}.
code_change(_OldVsn, State, _Extra) ->
    {'ok', State}.

-spec maybe_send_push_notification(push_app(), kz_json:object()) -> 'ok'.
maybe_send_push_notification('undefined', _) -> 'ok';
maybe_send_push_notification({Pid, ExtraHeaders}, JObj) ->
    TokenID = kz_json:get_value(<<"Token-ID">>, JObj),
    Topic = pm_apple:apns_topic(JObj),
    lager:debug("apns_dev JObj ~p",[JObj]),
    lager:debug("apns_dev ExtraHeaders ~p",[ExtraHeaders]),
    Headers = kz_maps:merge(#{'apns_topic' => Topic}, ExtraHeaders),
    Msg = pm_apple:build_payload(JObj, ExtraHeaders),
    lager:debug_unsafe("pushing apple_dev ~s for token-id ~s : ~s"
                      ,[pm_apple:join_headers(Headers)
                       ,TokenID
                       ,kz_json:encode(kz_json:from_map(Msg), ['pretty'])
                       ]
                      ),
    try
        Result = apns:push_notification(Pid, TokenID, Msg, Headers),
        lager:debug_unsafe("apple_dev result for ~s : ~p", [Topic, Result]),
        {Code, _, Info} = Result,
        Resp = kz_json:from_list([{<<"code">>, Code},{<<"Info">>, Info}]),
        AccountId = kz_json:get_ne_binary_value(<<"Account-ID">>, JObj),
        %% send event with confirmation of push (can be received over blackhole)
        kz_edr:event(?APP_NAME, ?APP_VERSION, 'ok', 'info', kz_json:set_value(<<"apn_response">>, Resp, kz_json:from_map(Msg)), AccountId)
    catch
        ?CATCH(Ex, Msg, _ST) ->
            lager:error_unsafe("PUBLISH ERROR => ~p / ~p", [Ex, Msg]),
            ?LOGSTACK(_ST)
    end.

-spec reload_apns(kz_term:api_binary(), ets:tid()) -> 'ok' | reference().
reload_apns(App, ETS) ->
    case get_apns(App, ETS) of
        'undefined' -> erlang:send_after(?MILLISECONDS_IN_SECOND * 5, self(), {'reload', App});
        _Push -> 'ok'
    end.

-spec get_apns(kz_term:api_binary(), ets:tid()) -> push_app().
get_apns('undefined', _) -> 'undefined';
get_apns(App, ETS) ->
    case ets:lookup(ETS, App) of
        [] -> maybe_load_apns(App, ETS);
        [{App, Push}] -> Push
    end.

-spec maybe_load_apns(kz_term:api_binary(), ets:tid()) -> push_app().
maybe_load_apns(App, ETS) ->
    CertBin = kapps_config:get_ne_binary(?CONFIG_CAT, [?APPLE_DEV, <<"certificate">>], 'undefined', App),
    Host = kapps_config:get_ne_binary(?CONFIG_CAT, [?APPLE_DEV, <<"host">>], ?DEFAULT_APNS_HOST, App),
    ExtraHeaders = kapps_config:get_json(?CONFIG_CAT, [?APPLE_DEV, <<"headers">>], kz_json:new(), App),
    Routines = [fun(JObj) -> pm_apple:maybe_utc_expiration_header(JObj) end
               ,fun(JObj) -> pm_apple:maybe_priority_to_binary(JObj) end
               ],
    ExtraHeaders2 = kz_json:exec(Routines, ExtraHeaders),
    Headers = kz_maps:keys_to_atoms(kz_json:to_map(ExtraHeaders2)),
    maybe_load_apns(App, ETS, CertBin, Host, Headers).

-spec maybe_load_apns(kz_term:api_binary()
                     ,ets:tid()
                     ,kz_term:api_ne_binary()
                     ,kz_term:ne_binary()
                     ,map()
                     ) -> push_app().
maybe_load_apns(App, _, 'undefined', _, _) ->
    lager:debug("apple_dev pusher certificate for app ~s not found", [App]),
    'undefined';
maybe_load_apns(App, ETS, CertBin, Host, Headers) ->
    {Key, Cert} = pusher_util:binary_to_keycert(CertBin),
    lager:debug("starting apple_dev push connection for ~s : ~s", [App, Host]),
    Connection = #{name => kz_term:to_atom(<<"apns_", App/binary>>, 'true')
                  ,apple_host => kz_term:to_list(Host)
                  ,apple_port => 443
                  ,type => 'certdata'
                  ,certdata => Cert
                  ,keydata => Key
                  ,timeout => 10000
                  ,options => #{transport => 'tls'
                               ,trace => 'false'
                               ,http2_opts => #{keepalive => ?MILLISECONDS_IN_MINUTE  * 15}
                               }
                  },
    try apns:connect(Connection) of
        {'ok', Pid} ->
            ets:insert(ETS, {App, {Pid, Headers}}),
            Ref = erlang:monitor('process', Pid),
            ets:insert(ETS, {Ref, App}),
            {Pid, Headers};
        {'error', {'already_started', Pid}} ->
            apns:close_connection(Pid),
            maybe_load_apns(App, ETS, CertBin, Host, Headers);
        {'error', Reason} ->
            lager:error("error loading apns ~p", [Reason]),
            'undefined'
    catch
        ?CATCH(_Er, _Ex,_ST) ->
            lager:error("error loading apple_dev apns ~p / ~p", [_Er, _Ex]),
            ?LOGSTACK(_ST),
            application:start(apns),
            case catch apns:connect(Connection) of
                {'ok', Pid} ->
                    lager:debug("starting again apns apple_dev push connection for ~p: ", [Connection]),
                    ets:insert(ETS, {App, {Pid, Headers}}),
                    Ref = erlang:monitor('process', Pid),
                    ets:insert(ETS, {Ref, App}),
                    {Pid, Headers};
                {'error', Reason} ->
                    lager:error("error re-loading apns_dev ~p", [Reason]),
                    'undefined'
            end
    end.
