-module(jsonrpc2_jiffy_test).

%% A couple of simple integration tests that exercise jsonrpc2 with the
%% "jiffy" JSON library instead of the term_to_binary/binary_to_term stub used
%% elsewhere in the suite.  We only want to prove that jsonrpc2 can work with
%% a real JSON encoder/decoder that follows the eep0018 representation.

-include_lib("eunit/include/eunit.hrl").

%% ------------------------------------------------------------------
%% Helper wrappers so that the tests mirror existing ones --------------
%% ------------------------------------------------------------------

encode(Term) -> jiffy:encode(Term).
decode(Bin)  -> jiffy:decode(Bin).

good_handler(_Method, _Params) -> ok.

%% ------------------------------------------------------------------
%% 1. Ensure notifications encoded with jiffy are handled without reply.
%% ------------------------------------------------------------------

handle_notification_jiffy_test() ->
    Notification = {[{<<"jsonrpc">>, <<"2.0">>},
                     {<<"method">>, <<"notify">>},
                     {<<"params">>, []}]},
    Encoded = encode(Notification),
    noreply = jsonrpc2:handle(Encoded,
                              fun good_handler/2,
                              fun decode/1,
                              fun encode/1).

%% ------------------------------------------------------------------
%% 2. Round-trip a normal call using jiffy encode/decode.
%% ------------------------------------------------------------------

echo_handler(_Method, _Params) -> <<"pong">>.

handle_call_jiffy_test() ->
    Call = {[{<<"jsonrpc">>, <<"2.0">>},
             {<<"method">>, <<"ping">>},
             {<<"params">>, []},
             {<<"id">>, 1}]},
    EncodedCall = encode(Call),

    {reply, EncodedReply} = jsonrpc2:handle(EncodedCall,
                                            fun echo_handler/2,
                                            fun decode/1,
                                            fun encode/1),

    %% Decode the reply using jiffy and validate its structure.
    {[{<<"jsonrpc">>, <<"2.0">>},
       {<<"result">>, <<"pong">>},
       {<<"id">>, 1}]} = decode(EncodedReply).
