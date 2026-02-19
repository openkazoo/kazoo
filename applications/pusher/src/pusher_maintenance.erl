%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2013-2022, 2600Hz
%%% @doc Maintenance functions for all
%%% @author Luis Azedo
%%% @end
%%%-----------------------------------------------------------------------------
-module(pusher_maintenance).

-include("pusher.hrl").

-export([add_firebase_app/2
        ,add_apple_app/2, add_apple_app/3, add_apple_header/3, update_apple_header/3, remove_apple_header/2
        ,add_apple_dev_app/3, add_apple_dev_header/3, update_apple_dev_header/3, remove_apple_dev_header/2
        ,add_provider_header/4, update_provider_header/4, remove_provider_header/3
        ,push/2
        ]).

-spec add_firebase_app(binary(), binary()) -> 'ok'.
add_firebase_app(AppId, Filename) ->
    {'ok', Data} = file:read_file(Filename),
    JObj = kz_json:decode(Data),
    _ = kapps_config:set_node(?CONFIG_CAT, [<<"firebase">>, <<"service_account">>], JObj, AppId),
    'ok'.

-spec add_apple_app(binary(), binary()) -> 'ok' | {'error', any()}.
add_apple_app(AppId, Certfile) ->
    add_apple_app(AppId, Certfile, ?DEFAULT_APNS_HOST).

-spec add_apple_app(binary(), binary(), binary()) -> 'ok' | {'error', any()}.
add_apple_app(AppId, Certfile, Host) ->
    case file:read_file(Certfile) of
        {'ok', Binary} ->
            _ = kapps_config:set_node(?CONFIG_CAT, [?APPLE, <<"certificate">>], Binary, AppId),
            _ = kapps_config:set_node(?CONFIG_CAT, [?APPLE, <<"host">>], Host, AppId),
            'ok';
        {'error', _} = Err -> Err
    end.

-spec add_apple_header(binary(), binary(), term()) -> 'ok' | {'ok', kz_json:object()}.
add_apple_header(AppId, Key, Value) ->
    add_provider_header(AppId, Key, Value, ?APPLE).

-spec update_apple_header(binary(), binary(), term()) -> 'ok' | {'ok', kz_json:object()}.
update_apple_header(AppId, Key, Value) ->
    update_provider_header(AppId, Key, Value, ?APPLE).

-spec remove_apple_header(binary(), binary()) -> 'ok' | {'ok', kz_json:object()}.
remove_apple_header(AppId, Key) ->
    remove_provider_header(AppId, Key, ?APPLE).

-spec add_apple_dev_app(binary(), binary(), binary()) -> 'ok' | {'error', any()}.
add_apple_dev_app(AppId, Certfile, Host) ->
    case file:read_file(Certfile) of
        {'ok', Binary} ->
            _ = kapps_config:set_node(?CONFIG_CAT, [?APPLE_DEV, <<"certificate">>], Binary, AppId),
            _ = kapps_config:set_node(?CONFIG_CAT, [?APPLE_DEV, <<"host">>], Host, AppId),
            AppleHeaders =  kapps_config:get_json(?CONFIG_CAT, [?APPLE, <<"headers">>], kz_json:new(), AppId),
            kapps_config:set_node(?CONFIG_CAT, [?APPLE_DEV , <<"apns_topic">>], <<(AppId)/binary, ".voip">>, AppId ),
kapps_config:set_node(?CONFIG_CAT, [?APPLE_DEV, <<"headers">>], AppleHeaders ,AppId),
        'ok';
        {'error', _} = Err -> Err
    end.

-spec add_apple_dev_header(binary(), binary(), term()) -> 'ok' | {'ok', kz_json:object()}.
add_apple_dev_header(AppId, Key, Value) ->
    add_provider_header(AppId, Key, Value, ?APPLE_DEV).

-spec update_apple_dev_header(binary(), binary(), term()) -> 'ok' | {'ok', kz_json:object()}.
update_apple_dev_header(AppId, Key, Value) ->
    update_provider_header(AppId, Key, Value, ?APPLE_DEV).

-spec remove_apple_dev_header(binary(), binary()) -> 'ok' | {'ok', kz_json:object()}.
remove_apple_dev_header(AppId, Key) ->
    remove_provider_header(AppId, Key, ?APPLE_DEV).

-spec add_provider_header(binary(), binary(), term(), term()) -> 'ok' | {'ok', kz_json:object()}.
add_provider_header(AppId, Key, Value, Provider) ->
    Value1 = case catch kz_term:to_integer(Value) of
        {'EXIT', _ } ->
            Value;
        Integer ->
            Integer
    end,
    Headers =  kapps_config:get_json(?CONFIG_CAT, [Provider, <<"headers">>], kz_json:new(), AppId),
    kapps_config:set_node( ?CONFIG_CAT, [Provider, <<"headers">>], kz_json:insert_value(Key,Value1,Headers) , AppId).

-spec update_provider_header(binary(), binary(), term(), term()) -> 'ok' | {'ok', kz_json:object()}.
update_provider_header(AppId, Key, Value, Provider) ->
    Value1 = case catch kz_term:to_integer(Value) of
                 {'EXIT', _ } ->
                     Value;
                 Integer ->
                     Integer
             end,
    Headers =  kapps_config:get_json( ?CONFIG_CAT, [Provider, <<"headers">>], kz_json:new(), AppId),
    kapps_config:set_node( ?CONFIG_CAT, [Provider, <<"headers">>], kz_json:set_value(Key,Value1,Headers) , AppId).

-spec remove_provider_header(binary(), binary(), binary()) -> 'ok' | {'ok', kz_json:object()}.
remove_provider_header(AppId, Key, Provider) ->
    Headers =  kapps_config:get_json(?CONFIG_CAT, [Provider, <<"headers">>], kz_json:new(), AppId),
    kapps_config:set_node( ?CONFIG_CAT, [Provider, <<"headers">>], kz_json:delete_key(Key, Headers) , AppId).
%%    lager:info([Headers,Key]).
%%    kapps_config:set_node( ?CONFIG_CAT, [Provider, <<"headers">>], kz_json:kz_json:delete_key(Key, Headers) , AppId).

-spec push(kz_term:ne_binary(), kz_term:ne_binary()) -> 'ok'.
push(AccountId, DeviceId) ->
    case kzd_devices:fetch(AccountId, DeviceId) of
        {'ok', Device} -> push(kz_json:get_json_value(<<"push">>, Device));
        {'error', Error} -> io:format("error: ~p~n", [Error])
    end.

push('undefined') ->
    io:format("error: no push propeties for device~n");
push(Push) ->
    CallId = kz_binary:rand_hex(16),
    MsgId = kz_binary:rand_hex(16),
    RegToken = kz_binary:rand_hex(16),
    CallerIdNumber = <<"15555555555">>,
    CallerIdName = <<"this is a push test">>,
    TokenApp = kz_json:get_ne_binary_value(<<"Token-App">>, Push),
    TokenType = kz_json:get_ne_binary_value(<<"Token-Type">>, Push),
    TokenId = kz_json:get_ne_binary_value(<<"Token-ID">>, Push),
    TokenProxy = kz_json:get_ne_binary_value(<<"Token-Proxy">>, Push),
    Payload = [{<<"call-id">>, CallId}
              ,{<<"proxy">>, TokenProxy}
              ,{<<"caller-id-number">>, CallerIdNumber}
              ,{<<"caller-id-name">>, CallerIdName}
              ,{<<"registration-token">>, RegToken}
              ],
    Msg = [{<<"Msg-ID">>, MsgId}
          ,{<<"App-Name">>, <<"Kamailio">>}
          ,{<<"App-Version">>, <<"1.0">>}
          ,{<<"Event-Category">>, <<"notification">>}
          ,{<<"Event-Name">>, <<"push_req">>}
          ,{<<"Call-ID">>, CallId}
          ,{<<"Token-ID">>, TokenId}
          ,{<<"Token-Type">>, TokenType}
          ,{<<"Token-App">>, TokenApp}
          ,{<<"Alert-Key">>, <<"IC_SIL">>}
          ,{<<"Alert-Params">>, [CallerIdNumber]}
          ,{<<"Sound">>, <<"ring.caf">>}
          ,{<<"Payload">>, kz_json:from_list(Payload)}
          ],
    pusher_listener:push(kz_json:from_list(Msg)).
