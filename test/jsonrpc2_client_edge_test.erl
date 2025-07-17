-module(jsonrpc2_client_edge_test).

-include_lib("eunit/include/eunit.hrl").

encode(Term) -> term_to_binary(Term).
decode(Bin)  -> binary_to_term(Bin).

%% 1. parse_response invalid structure (throws) ----------------------

parse_response_invalid_test() ->
    Bad = {[{<<"result">>, ok}, {<<"id">>, 1}]},
    ?assertException(throw, invalid_jsonrpc_response,
                     jsonrpc2_client:parse_response(Bad)).

%% 2. parse_response error with data --------------------------------

parse_response_error_with_data_test() ->
    Boom  = <<"Boom">>,
    Extra = <<"extra">>,
    Resp = {[{<<"jsonrpc">>, <<"2.0">>},
             {<<"error">>, {[{<<"code">>, -32099},
                              {<<"message">>, Boom},
                              {<<"data">>, Extra}]}},
             {<<"id">>, 9}]},
    Expect = [{9, {error, {jsonrpc2, -32099, Boom, Extra}}}],
    ?assertEqual(Expect, jsonrpc2_client:parse_response(Resp)).

%% 3. parse_response both result and error present ------------------

parse_response_both_result_error_test() ->
    Bad = <<"Bad">>,
    Msg = <<"Invalid JSON-RPC 2.0 response">>,
    Resp = {[{<<"jsonrpc">>, <<"2.0">>},
             {<<"result">>, ok},
             {<<"error">>, {[{<<"code">>, -32000}, {<<"message">>, Bad}]}},
             {<<"id">>, 2}]},
    Expect = [{2, {error, {server_error, Msg}}}],
    ?assertEqual(Expect, jsonrpc2_client:parse_response(Resp)).

%% 4. parse_response neither result nor error -----------------------

parse_response_no_result_error_test() ->
    Msg = <<"Invalid JSON-RPC 2.0 response">>,
    Resp = {[{<<"jsonrpc">>, <<"2.0">>}, {<<"id">>, 3}]},
    Expect = [{3, {error, {server_error, Msg}}}],
    ?assertEqual(Expect, jsonrpc2_client:parse_response(Resp)).

%% 5. batch_call -> invalid_jsonrpc_response fallback ---------------

batch_call_invalid_jsonrpc_response_test() ->
    Methods = [{<<"foo">>, []}],
    FirstId = 1,
    SentJson = jsonrpc2_client:create_request([{<<"foo">>, [], 1}]),
    SentBin  = encode(SentJson),
    BadResp  = encode({[{<<"result">>, ok}, {<<"id">>, 1}]}),
    Transport = fun(Bin) -> ?assertEqual(SentBin, Bin), BadResp end,
    Expect = [{error, {server_error, invalid_jsonrpc_response}}],
    ?assertEqual(Expect,
                 jsonrpc2_client:batch_call(Methods, Transport,
                                            fun decode/1, fun encode/1, FirstId)).

%% 6. parse_response invalid id (binary) to cover id check throw path ---------

parse_response_invalid_id_test() ->
    Resp = {[{<<"jsonrpc">>, <<"2.0">>}, {<<"result">>, ok}, {<<"id">>, <<"str">>} ]},
    ?assertException(throw, invalid_jsonrpc_response,
                     jsonrpc2_client:parse_response(Resp)).
