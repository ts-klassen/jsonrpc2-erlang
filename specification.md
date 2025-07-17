# Specification

## Interface Definition

### Operations

#### jsonrpc2:handle/2
* identifier: jsonrpc2.handle/2
* purpose: Execute a decoded JSON-RPC 2.0 request or batch using a user-supplied handler callback.
* invocation: synchronous (blocking)
* input-schema: DecodedRpcInput
* output-schema: RpcHandleResult
* error codes: §4 – all

#### jsonrpc2:handle/3
* identifier: jsonrpc2.handle/3
* purpose: Same as handle/2 but accepts a custom `map/2` implementation for batch processing (e.g. concurrent mapping).
* invocation: synchronous
* input-schema: DecodedRpcInput + MapFun
* output-schema: RpcHandleResult
* error codes: §4 – all

#### jsonrpc2:handle/4
* identifier: jsonrpc2.handle/4
* purpose: Parse, execute and encode a single JSON-RPC 2.0 request or batch using supplied JSON codec functions.
* invocation: synchronous
* input-schema: RawRpcInput
* output-schema: RawRpcHandleResult
* error codes: §4 – all

#### jsonrpc2:handle/5
* identifier: jsonrpc2.handle/5
* purpose: Same as handle/4 but accepts a custom `map/2` implementation for batch processing.
* invocation: synchronous
* input-schema: RawRpcInput + MapFun
* output-schema: RawRpcHandleResult
* error codes: §4 – all

#### jsonrpc2:parseerror/0
* identifier: jsonrpc2.parseerror/0
* purpose: Produce a predefined JSON-RPC *Parse error* object (code −32700) for invalid JSON received from a peer.
* invocation: synchronous
* input-schema: – (none)
* output-schema: JsonRpcErrorObject
* error codes: –

#### jsonrpc2_client:create_request/1
* identifier: jsonrpc2_client.create_request/1
* purpose: Build a valid JSON-RPC 2.0 call, notification or batch request from Erlang tuples/lists.
* invocation: synchronous
* input-schema: ClientRequestTuple
* output-schema: JsonRpcRequest
* error codes: –

#### jsonrpc2_client:parse_response/1
* identifier: jsonrpc2_client.parse_response/1
* purpose: Decompose a decoded JSON-RPC 2.0 response/batch into `{Id, {ok, Result}|{error, Err}}` pairs.
* invocation: synchronous
* input-schema: JsonRpcResponse
* output-schema: ParsedResponseList
* error codes: §4 – invalid_jsonrpc_response

#### jsonrpc2_client:batch_call/5
* identifier: jsonrpc2_client.batch_call/5
* purpose: Issue multiple calls as one JSON-RPC batch over a caller-supplied transport, returning ordered results.
* invocation: synchronous (transport may be blocking)
* input-schema: BatchCallInput
* output-schema: BatchCallResultList
* error codes: §4 – all + transport_error + invalid_json + invalid_jsonrpc_response

### Lifecycle / Sequencing Rules
1. No explicit initialisation or teardown required; functions are pure.
2. For server side (`jsonrpc2`):
   • `handle/2|3` expect already-decoded JSON; ensure decoding occurred before call.
   • `handle/4|5` must receive `JsonDecode` and `JsonEncode` functions that are inverses over the supported `json()` representation.
3. Batch requests are evaluated left-to-right. When `MapFun` is supplied the caller must guarantee that returned list order corresponds to the original order (§3.1).
4. Notifications (requests without `id`) yield the atom `noreply`; callers MUST suppress transport replies.
5. Maximum timeout is caller-defined; library imposes none.

## Data Schemas

```erlang
%% Fundamental value used throughout
-type json() :: true | false | null | binary() | [json()] |
                {[{binary(), json()}]} | #{binary() => json()}.

-type id()      :: integer() | binary() | null.
-type method()  :: binary().
-type params()  :: [json()] | {[{binary(), json()}]} | #{binary() => json()}.

%% RPC request after Erlang decoding
-type rpc_request() ::
      {method(), params(), id() | undefined}            %% call
    | {method(), params()}                              %% notification
    | invalid_request.

%% Wrapper returned by jsonrpc2:handle*
-type rpc_handle_result() ::
      noreply                                    %% notification or filtered batch
    | {reply, json()}.

%% Error object (matches JSON-RPC 2.0 spec)
-type error_obj() ::
      {[{<<"code">>, integer()},
        {<<"message">>, binary()},
        {<<"data">>, json()}]}.
```

```json
// JSON Schema – JsonRpcRequest (wire format)
{
  "$id": "#/JsonRpcRequest",
  "type": "object",
  "required": ["jsonrpc", "method"],
  "properties": {
    "jsonrpc": {"const": "2.0"},
    "method":  {"type": "string"},
    "params":  {"type": ["array", "object"]},
    "id":      {"type": ["integer", "string", "null"]}
  },
  "additionalProperties": false
}
```

```json
// JSON Schema – JsonRpcResponse
{
  "$id": "#/JsonRpcResponse",
  "type": "object",
  "required": ["jsonrpc", "id"],
  "properties": {
    "jsonrpc": {"const": "2.0"},
    "id": {"type": ["integer", "string", "null"]},
    "result": {},
    "error":  {
      "type": "object",
      "required": ["code", "message"],
      "properties": {
        "code": {"type": "integer"},
        "message": {"type": "string"},
        "data": {}
      },
      "additionalProperties": false
    }
  },
  "oneOf": [
    {"required": ["result"], "not": {"required": ["error"]}},
    {"required": ["error"],  "not": {"required": ["result"]}}
  ],
  "additionalProperties": false
}
```

### Schema Reference Map
* DecodedRpcInput → `rpc_request() | [rpc_request()]`
* RawRpcInput → `binary()` containing UTF-8 JSON
* MapFun → `fun((Fun, ListIn) -> ListOut)` compatible with `lists:map/2`
* RpcHandleResult → `rpc_handle_result()`
* RawRpcHandleResult → `binary()` (UTF-8 JSON) wrapped as `{reply, binary()}` or `noreply`
* JsonRpcRequest → `#/JsonRpcRequest`
* JsonRpcResponse → `#/JsonRpcResponse`
* JsonRpcErrorObject → `error_obj()`
* ClientRequestTuple → see `jsonrpc2_client` types below
* ParsedResponseList → `[{id(), {ok, json()} | {error, error_obj()}}]`
* BatchCallInput → `[ {method(), params()} ], TransportFun, JsonDecodeFun, JsonEncodeFun, FirstId (integer)`
* BatchCallResultList → `[{ok, json()} | {error, error_obj()}]`

## Configuration Keys
The library exposes no runtime configuration parameters. All behaviour is controlled by function arguments (handler fun, map fun, transport fun, codec funs).

## Error Catalogue
| Code | Symbol | Meaning | Client Retry Guidance |
|------|--------|---------|-----------------------|
| −32700 | parse_error | Invalid JSON; parse failed | Fix request serialization and resend |
| −32600 | invalid_request | JSON is valid but not a valid JSON-RPC envelope | Fix request structure and resend |
| −32601 | method_not_found | Requested method unknown on server | Check method spelling or server capabilities; retry will fail again |
| −32602 | invalid_params | Params invalid for method | Correct params before retry |
| −32603 | internal_error | Internal JSON-RPC error within server | Retry may succeed after server fix |
| −32000 | server_error | Implementation-defined server error | Consult `data` field; retry depends on cause |
| −32000…−32099 | – | Reserved for server/application specific errors generated via `{jsonrpc2, Code, Msg [,Data]}` | Retry rules defined by application |
| *transport_error* | – | Thrown by transport fun in client; propagated as `{server_error, Details}` | Retry depends on transport layer |
| *invalid_json* | – | Response was not valid JSON | Usually non-recoverable until server fixes |
| *invalid_jsonrpc_response* | – | Response violated JSON-RPC spec | Non-recoverable until server fixes |

## Examples

### jsonrpc2.handle/4 (single call)
```erlang
Handler = fun(<<"add">>, [A,B]) -> A + B end,
RequestBin = <<"{\"jsonrpc\":\"2.0\",\"method\":\"add\",\"params\":[3,4],\"id\":1}">>,
{reply, ReplyBin} = jsonrpc2:handle(RequestBin,
                                    Handler,
                                    fun jiffy:decode/1,
                                    fun jiffy:encode/1).
%% ReplyBin == <<"{\"jsonrpc\":\"2.0\",\"result\":7,\"id\":1}">>
```

### jsonrpc2.handle/3 (batch with custom map)
```erlang
MapFun = fun(F, L) -> plists:map(F, L) end, %% concurrent map from plists
Batch = [ {<<"echo">>, [1]}, {<<"echo">>, [2]} ],
Decoded = lists:map(fun ({M,P}) ->
                     {[{<<"jsonrpc">>,<<"2.0">>},{<<"method">>,M},{<<"params">>,P},{<<"id">>,make_ref()}]}
                   end, Batch),
jsonrpc2:handle(Decoded, Handler, MapFun).
```

### jsonrpc2.parseerror/0
```erlang
ErrorObj = jsonrpc2:parseerror().
```

### jsonrpc2_client.create_request/1
```erlang
JsonReq = jsonrpc2_client:create_request({<<"ping">>, [], 42}).
```

### jsonrpc2_client.parse_response/1
```erlang
JsonResp = {[{<<"jsonrpc">>,<<"2.0">>},{<<"result">>,<<"pong">>},{<<"id">>,42}]},
Pairs = jsonrpc2_client:parse_response(JsonResp).
%% => [{42, {ok, <<"pong">>}}]
```

### jsonrpc2_client.batch_call/5
```erlang
MPs = [{<<"sum">>, [1,2,3]}, {<<"sum">>, [4,5]}],
Transport = fun(Bin) -> httpc:request(post, {Url, [], "application/json", Bin}, [], []) end,
Results = jsonrpc2_client:batch_call(MPs, Transport, fun jiffy:decode/1, fun jiffy:encode/1, 1).
```

