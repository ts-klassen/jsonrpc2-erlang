-module(jsonrpc2_handle_edge_test).

-include_lib("eunit/include/eunit.hrl").

%% Helpers -----------------------------------------------------------

encode(Term) -> term_to_binary(Term).
decode(Bin)  -> binary_to_term(Bin).

good_handler(_Method, _Params) -> ok.

%% 1. When inner handle returns noreply -----------------------------

handle_noreply_test() ->
    Notification = {[{<<"jsonrpc">>, <<"2.0">>},
                     {<<"method">>, <<"notify">>},
                     {<<"params">>, []}]},
    Encoded = encode(Notification),
    noreply = jsonrpc2:handle(Encoded,
                              fun good_handler/2,
                              fun decode/1,
                              fun encode/1).

%% 2. JsonEncode fails once, triggers internal_error branch ---------

encode_flaky(Term) ->
    case erlang:get(encode_attempt) of
        undefined -> erlang:put(encode_attempt, 1), throw(bad_encode);
        _ -> term_to_binary(Term)
    end.

json_encode_failure_test() ->
    Call = {[{<<"jsonrpc">>, <<"2.0">>},
             {<<"method">>, <<"ping">>},
             {<<"params">>, []},
             {<<"id">>, 1}]},
    {reply, ErrBin} = jsonrpc2:handle(encode(Call),
                                      fun good_handler/2,
                                      fun decode/1,
                                      fun encode_flaky/1),
    {Map} = decode(ErrBin),
    {ErrObj} = proplists:get_value(<<"error">>, Map),
    -32603 = proplists:get_value(<<"code">>, ErrObj),
    null    = proplists:get_value(<<"id">>, Map).

%% 3. dispatch error with data --------------------------------------

dispatch_invalid_params_with_data_test() ->
    Handler = fun(_, _) -> throw({invalid_params, <<"bad">>}) end,
    Req = {[{<<"jsonrpc">>, <<"2.0">>},
            {<<"method">>, <<"foo">>},
            {<<"params">>, []},
            {<<"id">>, 5}]},
    {reply, Reply} = jsonrpc2:handle(Req, Handler),
    {List} = Reply,
    {ErrObj} = proplists:get_value(<<"error">>, List),
    -32602 = proplists:get_value(<<"code">>, ErrObj),
    <<"Invalid params.">> = proplists:get_value(<<"message">>, ErrObj),
    <<"bad">> = proplists:get_value(<<"data">>, ErrObj).

%% 4. server_error thrown from a notification -> noreply ------------

dispatch_server_error_notification_test() ->
    Handler = fun(_, _) -> throw(server_error) end,
    Notification = {[{<<"jsonrpc">>, <<"2.0">>},
                     {<<"method">>, <<"oops">>},
                     {<<"params">>, []}]},
    noreply = jsonrpc2:handle(Notification, Handler).

%% 5. notification throws {invalid_params,Data} -> noreply (covers make_error_response/4 with undefined Id)

dispatch_invalid_params_notification_with_data_test() ->
    Handler = fun(_, _) -> throw({invalid_params, <<"oops">>}) end,
    Notification = {[{<<"jsonrpc">>, <<"2.0">>},
                     {<<"method">>, <<"bar">>},
                     {<<"params">>, []}]},
    noreply = jsonrpc2:handle(Notification, Handler).

%% 6. custom error without data (covers lines 207)

custom_error_without_data_test() ->
    Code = -32050,
    Msg  = <<"Custom err">>,
    Handler = fun(_, _) -> throw({jsonrpc2, Code, Msg}) end,
    Request = {[{<<"jsonrpc">>, <<"2.0">>},
                {<<"method">>, <<"foo">>},
                {<<"params">>, []},
                {<<"id">>, 42}]},
    {reply, Reply} = jsonrpc2:handle(Request, Handler),
    {Map} = Reply,
    {ErrObj} = proplists:get_value(<<"error">>, Map),
    Code = proplists:get_value(<<"code">>, ErrObj),
    Msg  = proplists:get_value(<<"message">>, ErrObj).

%% 7. custom error with data (covers lines 210)

custom_error_with_data_test() ->
    Code = -32055,
    Msg  = <<"Boom">>,
    Data = <<"extra">>,
    Handler = fun(_, _) -> throw({jsonrpc2, Code, Msg, Data}) end,
    Request = {[{<<"jsonrpc">>, <<"2.0">>},
                {<<"method">>, <<"foo">>},
                {<<"params">>, []},
                {<<"id">>, 43}]},
    {reply, Reply} = jsonrpc2:handle(Request, Handler),
    {Map} = Reply,
    {ErrObj} = proplists:get_value(<<"error">>, Map),
    Code = proplists:get_value(<<"code">>, ErrObj),
    Msg  = proplists:get_value(<<"message">>, ErrObj),
    Data = proplists:get_value(<<"data">>, ErrObj).
