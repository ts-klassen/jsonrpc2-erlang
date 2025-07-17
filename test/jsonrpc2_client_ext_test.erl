-module(jsonrpc2_client_ext_test).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Helpers used by the tests
%%--------------------------------------------------------------------

%% Simple "JSON" encoder/decoder for the purpose of unit-testing. We just use
%% Erlang term_to_binary/binary_to_term because the jsonrpc2 implementation
%% under test treats JSON encoding/decoding as an external concern.

-define(ENCODE(Term), term_to_binary(Term)).
-define(DECODE(Bin),  binary_to_term(Bin)).

encode(Term) -> ?ENCODE(Term).
decode(Bin)  -> ?DECODE(Bin).

%%--------------------------------------------------------------------
%% Tests for jsonrpc2_client:create_request/1
%%--------------------------------------------------------------------

create_request_notification_test() ->
    Method = <<"notify_hello">>,
    Params = [5],
    Expected = {[{<<"jsonrpc">>, <<"2.0">>},
                 {<<"method">>, Method},
                 {<<"params">>, Params}]},
    ?assertEqual(Expected, jsonrpc2_client:create_request({Method, Params})).

create_request_call_test() ->
    Method = <<"subtract">>,
    Params = [42, 23],
    Id = 1,
    Expected = {[{<<"jsonrpc">>, <<"2.0">>},
                 {<<"method">>, Method},
                 {<<"params">>, Params},
                 {<<"id">>, Id}]},
    ?assertEqual(Expected, jsonrpc2_client:create_request({Method, Params, Id})).

create_request_batch_test() ->
    Batch = [{<<"add">>, [1,2], 1}, {<<"ping">>, []}],
    Expected = [jsonrpc2_client:create_request(Req) || Req <- Batch],
    ?assertEqual(Expected, jsonrpc2_client:create_request(Batch)).

%%--------------------------------------------------------------------
%% Tests for jsonrpc2_client:parse_response/1
%%--------------------------------------------------------------------

parse_response_ok_test() ->
    Response = {[{<<"jsonrpc">>, <<"2.0">>},
                 {<<"result">>, 123},
                 {<<"id">>, 7}]},
    Expected = [{7, {ok, 123}}],
    ?assertEqual(Expected, jsonrpc2_client:parse_response(Response)).

parse_response_error_test() ->
    Response = {[{<<"jsonrpc">>, <<"2.0">>},
                 {<<"error">>, {[{<<"code">>, -32601},
                                  {<<"message">>, <<"Method not found.">>}]}},
                 {<<"id">>, 3}]},
    Expected = [{3, {error, {jsonrpc2, -32601, <<"Method not found.">>}}}],
    ?assertEqual(Expected, jsonrpc2_client:parse_response(Response)).

%%--------------------------------------------------------------------
%% End-to-end test for jsonrpc2_client:batch_call/5
%%--------------------------------------------------------------------

batch_call_happy_path_test() ->
    %% Two calls in the batch
    MethodsAndParams = [{<<"sum">>, [1, 2]},
                        {<<"subtract">>, [5, 3]}],
    FirstId = 1,

    %% Pre-compute what the client will send so we can craft the reply.
    RequestJson = jsonrpc2_client:create_request([{<<"sum">>, [1, 2], 1},
                                                  {<<"subtract">>, [5, 3], 2}]),
    EncodedRequest = encode(RequestJson),

    %% Build the JSON-RPC response list (order intentionally reversed to show
    %% that jsonrpc2_client reorders by id).
    ResponseJson = [
        {[{<<"jsonrpc">>, <<"2.0">>},
          {<<"result">>, 2},
          {<<"id">>, 2}]},
        {[{<<"jsonrpc">>, <<"2.0">>},
          {<<"result">>, 3},
          {<<"id">>, 1}]}
    ],
    EncodedResponse = encode(ResponseJson),

    %% Transport fun just echoes back the pre-built response when it receives
    %% the expected request.
    TransportFun = fun(ReqBin) ->
        ?assertEqual(EncodedRequest, ReqBin),
        EncodedResponse
    end,

    Expected = [{ok, 3}, {ok, 2}],
    Actual = jsonrpc2_client:batch_call(MethodsAndParams, TransportFun,
                                        fun decode/1, fun encode/1, FirstId),
    ?assertEqual(Expected, Actual).
