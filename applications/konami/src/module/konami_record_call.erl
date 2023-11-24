%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2022, 2600Hz
%%% @doc Record something
%%% "data":{
%%%   "action":["start","stop"] // one of these
%%%   ,"time_limit":600 // in seconds, how long to record the call
%%%   ,"format":["mp3","wav"] // what format to store the recording in
%%%   ,"url":"http://server.com/path/to/dump/file" // what URL to PUT the file to
%%% }
%%%
%%% @author James Aimonetti
%%% @end
%%%-----------------------------------------------------------------------------
-module(konami_record_call).

-export([handle/2
        ,number_builder/1
        ]).

-include("konami.hrl").

-spec handle(kz_json:object(), kapps_call:call()) ->
          {'continue', kapps_call:call()}.
handle(Data, Call) ->
    Call1 = handle(Data, Call, get_action(kz_json:get_ne_binary_value(<<"action">>, Data))),
    {'continue', Call1}.

-spec handle(kz_json:object(), kapps_call:call(), kz_term:ne_binary()) ->
          kapps_call:call().
handle(_Data, Call, <<"mask">>) ->
    lager:debug("masking recording, see you on the other side"),
    kapps_call:mask_recording(Call);
handle(_Data, Call, <<"unmask">>) ->
    lager:debug("unmasking recording, see you on the other side"),
    kapps_call:unmask_recording(Call);
handle(Data, Call, <<"start">>) ->
    lager:debug("starting recording, see you on the other side"),
    Result = save_record_param(Data, Call),
    lager:debug("result saved circle_cloud param: ~p", [Result]),
    kapps_call:start_recording(Data, Call);
handle(_Data, Call, <<"stop">>) ->
    _ = kapps_call:stop_recording(Call),
    lager:debug("sent command to stop recording call"),
    Call.

-spec get_action(kz_term:api_ne_binary()) -> kz_term:ne_binary().
get_action('undefined') -> <<"start">>;
get_action(<<"mask">>) -> <<"mask">>;
get_action(<<"unmask">>) -> <<"unmask">>;
get_action(<<"stop">>) -> <<"stop">>;
get_action(_) -> <<"start">>.

-spec number_builder(kz_json:object()) -> kz_json:object().
number_builder(DefaultJObj) ->
    io:format("Let's configure a 'record_call' metaflow~n", []),

    {'ok', [Number]} = io:fread("What number should invoke 'record_call'? ", "~d"),

    K = [<<"numbers">>, kz_term:to_binary(Number)],

    case number_builder_check(kz_json:get_value(K, DefaultJObj)) of
        'undefined' -> kz_json:delete_key(K, DefaultJObj);
        NumberJObj -> kz_json:set_value(K, NumberJObj, DefaultJObj)
    end.

-spec number_builder_check(kz_term:api_object()) -> kz_term:api_object().
number_builder_check('undefined') ->
    number_builder_action(kz_json:new());
number_builder_check(NumberJObj) ->
    io:format("  Existing config for this number: ~s~n", [kz_json:encode(NumberJObj)]),
    io:format("  e. Edit Number~n", []),
    io:format("  d. Delete Number~n", []),
    {'ok', [Option]} = io:fread("What would you like to do: ", "~s"),
    number_builder_check_option(NumberJObj, Option).

-spec number_builder_check_option(kz_json:object(), string()) -> kz_term:api_object().
number_builder_check_option(NumberJObj, "e") ->
    number_builder_action(NumberJObj);
number_builder_check_option(_NumberJObj, "d") ->
    'undefined';
number_builder_check_option(NumberJObj, _Option) ->
    io:format("invalid selection~n", []),
    number_builder_check(NumberJObj).

-spec number_builder_action(kz_json:object()) -> kz_json:object().
number_builder_action(NumberJObj) ->
    {'ok', [Action]} = io:fread("What action: 'start' or 'stop': ", "~s"),
    number_builder_time_limit(NumberJObj, kz_term:to_binary(Action)).

-spec number_builder_time_limit(kz_json:object(), kz_term:ne_binary()) -> kz_json:object().
number_builder_time_limit(NumberJObj, Action) ->
    {'ok', [TimeLimit]} = io:fread("How many seconds to limit the recording to: ", "~d"),
    number_builder_format(NumberJObj, Action, TimeLimit).

-spec number_builder_format(kz_json:object(), kz_term:ne_binary(), pos_integer()) -> kz_json:object().
number_builder_format(NumberJObj, Action, TimeLimit) ->
    {'ok', [Format]} = io:fread("What format would you like the recording? ('wav' or 'mp3'): ", "~3s"),
    number_builder_url(NumberJObj, Action, TimeLimit, kz_term:to_binary(Format)).

-spec number_builder_url(kz_json:object(), kz_term:ne_binary(), pos_integer(), kz_term:ne_binary()) -> kz_json:object().
number_builder_url(NumberJObj, Action, TimeLimit, Format) ->
    {'ok', [URL]} = io:fread("What URL to send the recording to at the end: ", "~s"),
    metaflow_jobj(NumberJObj, Action, TimeLimit, Format, kz_term:to_binary(URL)).

-spec metaflow_jobj(kz_json:object(), kz_term:ne_binary(), pos_integer(), kz_term:ne_binary(), kz_term:ne_binary()) -> kz_json:object().
metaflow_jobj(NumberJObj, Action, TimeLimit, Format, URL) ->
    kz_json:set_values([{<<"module">>, <<"record_call">>}
                       ,{<<"data">>, data(Action, TimeLimit, Format, URL)}
                       ], NumberJObj).

-spec data(kz_term:ne_binary(), pos_integer(), kz_term:ne_binary(), kz_term:ne_binary()) -> kz_json:object().
data(Action, TimeLimit, Format, URL) ->
    kz_json:from_list([{<<"action">>, Action}
                      ,{<<"time_limit">>, TimeLimit}
                      ,{<<"format">>, Format}
                      ,{<<"url">>, URL}
                      ]).

-spec save_record_param(kz_term:ne_binary() | kz_json:object(), kapps_call:call()) ->
    {'ok', kz_json:object() | kz_json:objects()} |
    kz_datamgr:data_error().
save_record_param(Data,Call) ->
    lager:debug(" CircleData : ~p ", [Data]),
    CallId = case source_leg_of_dtmf(Data, Call) of
                 'a' ->
                     lager:debug("circle_cloud leg 'a' "),
                     kapps_call:call_id(Call);
                 'b' ->
                     lager:debug("circle_cloud leg 'b' "),
                     kapps_call:other_leg_call_id(Call)
             end,
    lager:debug("circle_cloud CallId: ~p",[CallId]),
    VObj = kz_json:set_value(<<"record_initiator_id">>, CallId, kz_json:new()),
    VObj1 = kz_json:set_value(<<"record_start_at">>, kz_time:current_unix_tstamp(), VObj),
    KObj = kz_json:set_value(<<"key">>, CallId, kz_json:new()),
    Obj = kz_json:set_value(<<"value">>,  VObj1, KObj),
    Doc = kz_doc:set_id(Obj, CallId),
    lager:debug("circle_cloud doc :~p ", [Doc]),
    kz_datamgr:save_doc(kapps_call:account_db(Call), Doc).

-spec source_leg_of_dtmf(kz_term:ne_binary() | kz_json:object(), kapps_call:call()) -> 'a' | 'b'.
source_leg_of_dtmf(<<_/binary>> = SourceDTMF, Call) ->
    case kapps_call:call_id(Call) =:= SourceDTMF of
        'true' -> 'a';
        'false' -> 'b'
    end;
source_leg_of_dtmf(Data, Call) ->
    source_leg_of_dtmf(kz_json:get_value(<<"dtmf_leg">>, Data), Call).
