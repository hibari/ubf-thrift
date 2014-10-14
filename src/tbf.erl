%% @doc Functions for Thrift(Binary) to Erlang data conversion.
%%
%% For most purposes, these functions are not called by code outside
%% of this library: Erlang client and Erlang server application code
%% usually have no need to use these functions.
%%
%% == Links
%%
%% <ul>
%% <li> http://incubator.apache.org/thrift </li>
%% </ul>
%%
%% == Thrift Basic Types (ABNF)
%% ------
%% message        =  message-begin struct message-end
%% message-begin  =  method-name message-type message-seqid
%% message-end    =  ""
%% method-name    =  STRING
%% message-type   =  T-CALL/ T-REPLY/ T-EXCEPTION/ T-ONEWAY
%% message-seqid  =  I32
%%
%% struct         =  struct-begin *field field-stop struct-end
%% struct-begin   =  struct-name
%% struct-end     =  ""
%% struct-name    =  STRING ;; NOTE: struct-name is not written to nor read from the network
%% field-stop     =  T-STOP
%%
%% field          =  field-begin field-data field-end
%% field-begin    =  field-name field-type field-id
%% field-end      =  ""
%% field-name     =  STRING ;; NOTE: field-name is not written to nor read from the network
%% field-type     =  T-STOP/ T-VOID/ T-BOOL/ T-BYTE/ T-I08/ T-I16/ T-I32/ T-U64/ T-I64/ T-DOUBLE/
%%                   T-BINARY/ T-STRUCT/ T-MAP/ T-SET/ T-LIST
%% field-id       =  I16
%% field-data     =  BOOL/ I08/ I16/ I32/ U64/ I64/ DOUBLE/ BINARY/
%%                   struct/ map/ list/ set
%% field-datum    =  field-data field-data
%%
%% map            =  map-begin *field-datum map-end
%% map-begin      =  map-key-type map-value-type map-size
%% map-end        =  ""
%% map-key-type   =  field-type
%% map-value-type =  field-type
%% map-size       =  I32
%%
%% list           =  list-begin *field-data list-end
%% list-begin     =  list-elem-type list-size
%% list-end       =  ""
%% list-elem-type =  field-type
%% list-size      =  I32
%%
%% set            =  set-begin *field-data set-end
%% set-begin      =  set-elem-type set-size
%% set-end        =  ""
%%
%% set-elem-type  =  field-type
%% set-size       =  I32
%%
%% ------
%%
%% == Thrift (Binary) Core Types (ABNF)
%% ------
%% BOOL           =  %x00/ %x01         ; 8/integer-signed-big
%% BYTE           =  OCTET              ; 8/integer-signed-big
%% I08            =  OCTET              ; 8/integer-signed-big
%% I16            =  2*OCTET            ; 16/integer-signed-big
%% I32            =  4*OCTET            ; 32/integer-signed-big
%% U64            =  8*OCTET            ; 64/integer-unsigned-big
%% I64            =  8*OCTET            ; 64/integer-signed-big
%% DOUBLE         =  8*OCTET            ; 64/float-signed-big
%% STRING         =  I32 UTF8-octets
%% BINARY         =  I32 *OCTET
%%
%% T-CALL         =  %x01
%% T-REPLY        =  %x02
%% T-EXCEPTION    =  %x03
%% T-ONEWAY       =  %x04
%%
%% T-STOP         =  %x00
%% T-VOID         =  %x01
%% T-BOOL         =  %x02
%% T-BYTE         =  %x03
%% T-I08          =  %x05
%% T-I16          =  %x06
%% T-I32          =  %x08
%% T-U64          =  %x09
%% T-I64          =  %x0a
%% T-DOUBLE       =  %x04
%% T-BINARY       =  %x0b
%% T-STRUCT       =  %x0c
%% T-MAP          =  %x0d
%% T-SET          =  %x0e
%% T-LIST         =  %x0f
%%
%% ------
%%
%% == Mapping: Thrift Types (Erlang)
%% ------
%% tbf::message() = {'message', tbf::method_name(), tbf::message_type(), tbf::message_seqid(), tbf::struct()}.
%% tbf::method_name() = binary().
%% tbf::message_type() = 'T-CALL' | 'T-REPLY' | 'T-EXCEPTION' | 'T-ONEWAY'.
%% tbf::message_seqid() = integer().
%%
%% tbf::struct() = {'struct', tbf::struct_name(), [tbf::field()]}.
%% tbf::struct_name() = binary().
%%
%% tbf::field() = {'field', tbf::field_name(), tbf::field_type(), tbf::field_id(), tbf::field_data()}.
%% tbf::field_name() = binary().
%% tbf::field_type() = 'T-STOP' | 'T-VOID' | 'T-BOOL' | 'T-BYTE'
%%                   | 'T-I08' | 'T-I16' | 'T-I32' | 'T-U64' | 'T-I64' | 'T-DOUBLE'
%%                   | 'T-BINARY' | 'T-STRUCT' | 'T-MAP' | 'T-SET' | 'T-LIST'.
%% tbf::field_id() = integer().
%% tbf::field_data() = tbf::void() | tbf::boolean() | integer()
%%                   | integer() | float()
%%                   | binary() | tbf::struct() | tbf::map() | tbf::set() | tbf::list().
%%
%% tbf::map() = {'map', tbf::map_type(), [tbf::map_data()]}.
%% tbf::map_type() = {tbf::field_type(), tbf::field_type()}.
%% tbf::map_data() = {tbf::field_data(), tbf::field_data()}.
%%
%% tbf::set() = {'set', tbf::set_type(), [tbf::set_data()]}.
%% tbf::set_type() = tbf::field_type().
%% tbf::set_data() = tbf::field_data().
%%
%% tbf::list() = {'list', tbf::list_type(), [tbf::list_data()]}.
%% tbf::list_type() = tbf::field_type().
%% tbf::list_data() = tbf::field_data().
%%
%% tbf::void() = 'undefined'.
%% tbf::boolean() = 'true' | 'false'.
%%
%% ------
%%
%% == Mapping: UBF Types (Erlang)
%% ------
%% ubf::tuple() = tuple().
%%
%% ubf::list() = list().
%%
%% ubf::number = integer() | float().
%%
%% ubf::string() = {'$S', [integer()]}.
%%
%% ubf::proplist() = {'$P', [{term(), term()}]}.
%%
%% ubf::binary() = binary().
%%
%% ubf::boolean() = 'true' | 'false'.
%%
%% ubf::atom() = atom().
%%
%% ubf::record() = record().
%%
%% ubf::term() = ubf::tuple() | ubf::list() | ubf::number()
%%             | ubf::string() | ubf::proplist() | ubf::binary()
%%             | ubf::boolean() | ubf::atom() | ubf::record().
%%
%% ubf::state() = ubf::atom().
%%
%% ubf::request() = ubf::term().
%% ubf::response() = {ubf::term(), ubf::state()}. % {Reply,NextState}
%%
%% ubf:event_in() = {event_in, ubf::term()}.
%% ubf:event_out() = {event_out, ubf::term()}.
%%
%% ------
%%
%% == UBF Messages
%% ------
%% Remote Procedure Call (Client -> Server -> Client)
%%   ubf::request() => ubf::response().
%%
%% Asynchronous Event (Server -> Client)
%%   'EVENT' => ubf::event_out().
%%
%% Asynchronous Event (Server <- Client)
%%   'EVENT' <= ubf::event_in().
%%
%% ------
%%
%% == Mapping: Thrift Messages&lt;->UBF Messages
%% ------
%% Remote Procedure Call (Client -> Server -> Client)
%%  ubf::request() = tbf::message().
%%  ubf::response() = tbf::message().
%%
%% Asynchronous Event (Server -> Client)
%%   ubf:event_out() = tbf::message().
%%
%% Asynchronous Event (Server <- Client)
%%   ubf:event_in() = tbf::message().
%%
%% ------
%%
%%  NOTE: Thrift has no concept of a UBF 'state' so it is not returned
%%  to the thrift client as a part of the rpc response.  This is
%%  enabled by the 'simplerpc' option.
%%
%%  TBD: Is there a Thrift-specific way to handle the following error cases?
%%  <ul>
%%  <li> encoding/decoding errors </li>
%%  <li> server breaks contract </li>
%%  <li> client breaks contract </li>
%%  </ul>
%%
%% == Mapping: Thrift Types&lt;-> UBF 'Native' Types
%% ------
%%
%% ubf::tuple() = {'struct', <<"$T">>, [{'field', <<>>, 'T-LIST', 1, {'list', 'T-STRUCT', [ubf::term()]}}]{1} }.
%%
%% ubf::list() = {'struct', <<"$L">>, [{'field', <<>>, 'T-LIST', 1, {'list', 'T-STRUCT', [ubf::term()]}}]{1} }.
%%
%% ubf::number = {'struct', <<"$N">>, [{'field', <<>>, 'T-I64', 1, integer()}]{1} | [{'field', <<>>, 'T-DOUBLE', 1, float()}]{1} }.
%%
%% ubf::string() = {'struct', <<"$S">>, [{'field', <<>>, 'T-BINARY', 1, binary()}]{1} }.
%%
%% ubf::proplist() = {'struct', <<"$P">>, [{'field', <<>>, 'T-MAP', 1, {'map', 'T-STRUCT', 'T-STRUCT', [{ubf::term(),ubf::term()}]}}]{1} }.
%%
%% ubf::binary() = {'struct', <<"$B">>, [{'field', <<>>, 'T-BINARY', 1, binary()}]{1} }.
%%
%% ubf::boolean() = {'struct', <<"$O">>, [{'field', <<>>, 'T-BOOL', 1, boolean()}]{1} }.
%%
%% ubf::atom() = {'struct', <<"$A">>, [{'field', <<>>, 'T-BINARY', 1, binary()}]{1} }.
%%
%% ubf::record() = {'struct', <<"$R">>, [{'field', <<>>, 'T-MAP', 1, {'map', 'T-BINARY', 'T-STRUCT', [{binary(),ubf::term()}]}}]{1} }.
%%   NOTE: A record's name is stored by a special key {<<>>, ubf::atom()} in the map.
%%
%% ubf::term() = ubf::tuple() | ubf::list() | ubf::number()
%%             | ubf::string() | ubf::proplist() | ubf::binary()
%%             | ubf::boolean() | ubf::atom() | ubf::record().
%%
%% ubf::state() = ubf::atom().
%%
%% ubf::request() = ubf::term().
%% ubf:response() = {ubf::term(), ubf::state()}. % {Reply,NextState}
%%
%% ubf:event_in() = {event_in, ubf::term()}.
%% ubf:event_out() = {event_out, ubf::term()}.
%%
%% ------
%%
%% == Mapping: Thrift Messages&lt;->UBF 'Native' Messages
%% ------
%% Remote Procedure Call (Client -> Server -> Client)
%%  ubf::request() = {'message', <<"$UBF">>, 'T-CALL', tbf::message_seqid(), ubf::term()}.
%%  ubf::response() = {'message', <<"$UBF">>, 'T-REPLY', tbf::message_seqid(), ubf::term()}.
%%
%% Asynchronous Event (Server -> Client)
%%   ubf:event_out() = {'message', <<"$UBF">>, 'T-ONEWAY', tbf::message_seqid(), ubf::term()}.
%%
%% Asynchronous Event (Server <- Client)
%%   ubf:event_in() = {'message', <<"$UBF">>, 'T-ONEWAY', tbf::message_seqid(), ubf::term()}.
%%
%% ------
%%
-module(tbf).
-behaviour(contract_proto).

-include_lib("ubf/include/ubf.hrl").

-export([proto_vsn/0, proto_driver/0, proto_packet_type/0]).
-export([encode/1, encode/2, encode/3]).
-export([decode_init/0, decode_init/1, decode_init/2, decode/1, decode/2, decode/3]).

-export([atom_to_binary/1]).
-export([binary_to_atom/1, binary_to_existing_atom/1]).

%% Dummy hack/kludge.
-export([contract_records/0]).

contract_records() ->
    [].


%%
%%---------------------------------------------------------------------
%%

-record(state,
        {
          x        :: binary()              % current binary to be decoded
          , stack  :: list() | tuple()      % current stack
          , type   :: undefined | term()    % current type (optional)
          , size   :: undefined | integer() % current size (optional)
          , safe   :: boolean()             % safe
          , vsn    :: undefined | integer() % version
          , mod    :: atom()                % contract
        }
       ).

-type ok() :: {done, Output::term(), Remainder::binary(), VSN::integer()}.
-type error() :: {error, Reason::term()}.
-type cont() :: {more, fun()}.

-define(VSN_MASK,  16#FFFF0000).
-define(VSN_1,     16#80010000).
-define(TYPE_MASK, 16#000000ff).

-define(CALL,      16#01).
-define(REPLY,     16#02).
-define(EXCEPTION, 16#03).
-define(ONEWAY,    16#04).

-define(FALSE,     16#00).
-define(TRUE,      16#01).

-define(STOP,      16#00).
-define(VOID,      16#01).
-define(BOOL,      16#02).
-define(BYTE,      16#03).
-define(I08,       16#05).
-define(I16,       16#06).
-define(I32,       16#08).
-define(U64,       16#09).
-define(I64,       16#0a).
-define(DOUBLE,    16#04).
-define(BINARY,    16#0b).
-define(STRUCT,    16#0c).
-define(MAP,       16#0d).
-define(SET,       16#0e).
-define(LIST,      16#0f).


%%
%%---------------------------------------------------------------------
%%
proto_vsn()         -> 'tbf1.0'.
proto_driver()      -> tbf_driver.
proto_packet_type() -> 0.


%%
%%---------------------------------------------------------------------
%%

-spec encode(Input::term()) -> iolist() | no_return().
encode(X) ->
    encode(X, ?MODULE).

-spec encode(Input::term(), module()) -> iolist() | no_return().
encode(X, Mod) ->
    encode(X, Mod, undefined).

-spec encode(Input::term(), module(), VNS::undefined | integer()) -> iolist() | no_return().
encode(X, Mod, VSN) when is_tuple(X) ->
    case element(1,X) of
        'message' ->
            encode_message(X, Mod, VSN);
        {'message',Name,_Type,_SeqId,_}=Msg
          when Name /= <<"$UBF">>, tuple_size(X) =:= 2 ->
            %% @TODO need a better way handle returning the reply to a
            %% native thrift client
            encode_message(Msg, Mod, VSN);
        _ ->
            try_encode_ubf(X, Mod, VSN)
    end;
encode(X, Mod, VSN) ->
    try_encode_ubf(X, Mod, VSN).

try_encode_ubf(X, Mod, VSN) ->
    %% @TODO special treatment for UBF-native messages
    %% automagically try to encode from native ubf
    case get('ubf_info') of
        I when I==tbf_client_driver; I==ftbf_client_driver ->
            case X of
                {event_in, {'message', _, _, _, _}=Y} ->
                    encode_message(Y, Mod, VSN);
                {event_in, Y} ->
                    encode_message({'message', <<"$UBF">>, 'T-ONEWAY', 0, Y}, Mod, VSN);
                _ ->
                    encode_message({'message', <<"$UBF">>, 'T-CALL', 0, X}, Mod, VSN)
            end;
        I when I==tbf_driver; I==ftbf_driver ->
            case X of
                {event_out, {'message', _, _, _, _}=Y} ->
                    encode_message(Y, Mod, VSN);
                {event_out, Y} ->
                    encode_message({'message', <<"$UBF">>, 'T-ONEWAY', 0, Y}, Mod, VSN);
                _ ->
                    encode_message({'message', <<"$UBF">>, 'T-REPLY', 0, X}, Mod, VSN)
            end;
        _ ->
            exit(badarg)
    end.

%%
%%---------------------------------------------------------------------
%%

-spec decode_init() -> cont().
decode_init() ->
    decode_init(false).

-spec decode_init(Safe::boolean()) -> cont().
decode_init(Safe) ->
    decode_init(Safe, <<>>).

-spec decode_init(Safe::boolean(), Input::binary()) -> cont().
decode_init(Safe, Binary) ->
    State = #state{x=Binary, safe=Safe},
    {more, fun(X, Mod) -> decode_start(X, State#state{mod=Mod}) end}.

-spec decode(Input::binary()) -> ok() | error() | cont().
decode(X) ->
    decode(X, ?MODULE).

-spec decode(Input::binary(), module()) -> ok() | error() | cont().
decode(X, Mod) ->
    decode(X, Mod, decode_init()).

-spec decode(Input::binary(), module(), cont()) -> ok() | error() | cont().
decode(X, Mod, {more, Fun}) ->
    Fun(X, Mod).

decode_start(X, #state{x=Y}=S) ->
    Z = <<Y/binary, X/binary>>,
    decode_message(S#state{x=Z}, fun decode_finish/1).

decode_finish(#state{x=X,stack=Term,vsn=VSN}) ->
    {done, try_decode_ubf(Term), X, VSN}.

try_decode_ubf(X) ->
    %% @TODO special treatment for UBF-native messages
    %% automagically try to decode to native ubf
    case get('ubf_info') of
        I when I==tbf_client_driver; I==ftbf_client_driver ->
            case X of
                {'message', <<"$UBF">>, 'T-ONEWAY', 0, Y} ->
                    {event_out, Y};
                {'message', _, 'T-ONEWAY', _, _}=Y ->
                    {event_out, Y};
                {'message', <<"$UBF">>, 'T-REPLY', 0, Y} ->
                    Y;
                _ ->
                    X
            end;
        I when I==tbf_driver; I==ftbf_driver ->
            case X of
                {'message', <<"$UBF">>, 'T-ONEWAY', 0, Y} ->
                    {event_in, Y};
                {'message', _, 'T-ONEWAY', _, _}=Y ->
                    {event_in, Y};
                {'message', <<"$UBF">>, 'T-CALL', 0, Y} ->
                    Y;
                _ ->
                    X
            end;
        _ ->
            X
    end.

decode_pause(#state{x=Y}=S, Cont, Resume) ->
    {more, fun(X, Mod) ->
                   Z = <<Y/binary, X/binary>>,
                   Resume(S#state{x=Z, mod=Mod}, Cont)
           end}.

decode_error(Type, SubType, Value, S) ->
    {error, {Type, SubType, Value, S}}.


%%
%%---------------------------------------------------------------------
%%
encode_message({'message',<<"$UBF">>=Name,Type,SeqId,UBF}, Mod, VSN) ->
    %% @TODO special treatment for UBF-native messages
    Struct = encode_ubf(UBF, Mod),
    encode_message1({'message',Name,Type,SeqId,Struct}, Mod, VSN);
encode_message(Message, Mod, VSN) ->
    encode_message1(Message, Mod, VSN).

encode_message1({'message',Name,Type,SeqId,Struct}, Mod, undefined) ->
    [encode_binary(Name, Mod)
     , encode_byte(encode_message_type(Type), Mod)
     , encode_i32(SeqId, Mod)
     , encode_struct(Struct, Mod)
    ];
encode_message1({'message',Name,Type,SeqId,Struct}, Mod, VSN) when is_integer(VSN) ->
    [encode_u32(VSN bor encode_message_type(Type), Mod)
     , encode_binary(Name, Mod)
     , encode_i32(SeqId, Mod)
     , encode_struct(Struct, Mod)
    ].

encode_message_type('T-CALL')      -> ?CALL;
encode_message_type('T-REPLY')     -> ?REPLY;
encode_message_type('T-EXCEPTION') -> ?EXCEPTION;
encode_message_type('T-ONEWAY')    -> ?ONEWAY;
encode_message_type(_)             -> exit(badarg).

encode_void(undefined, _Mod) ->
    [];
encode_void(_, _) ->
    exit(badarg).

encode_bool(false, _Mod) ->
    <<0:8/signed>>;
encode_bool(true, _Mod) ->
    <<1:8/signed>>;
encode_bool(_, _) ->
    exit(badarg).

encode_byte(X, _Mod) when is_integer(X), X >= -128, X < 128 ->
    <<X:8/signed>>;
encode_byte(<<Y:8/signed>>=X, _Mod) when byte_size(X) =:= 1 ->
    <<Y:8/signed>>;
encode_byte(_, _) ->
    exit(badarg).

encode_i08(X, _Mod) when is_integer(X), X >= -128, X < 128 ->
    <<X:8/signed>>;
encode_i08(_, _) ->
    exit(badarg).

encode_i16(X, _Mod) when is_integer(X), X >= -32768, X < 32768 ->
    <<X:16/signed>>;
encode_i16(_, _) ->
    exit(badarg).

encode_i32(X, _Mod) when is_integer(X), X >= -2147483648, X < 2147483648 ->
    <<X:32/signed>>;
encode_i32(_, _) ->
    exit(badarg).

encode_i64(X, _Mod) when is_integer(X), X >= -9223372036854775808, X < 9223372036854775808 ->
    <<X:64/signed>>;
encode_i64(_, _) ->
    exit(badarg).

encode_u32(X, _Mod) when is_integer(X), X >= 0, X < 4294967296 ->
    <<X:32/unsigned>>;
encode_u32(_, _) ->
    exit(badarg).

encode_u64(X, _Mod) when is_integer(X), X >= 0, X < 18446744073709551616 ->
    <<X:64/unsigned>>;
encode_u64(_, _) ->
    exit(badarg).

encode_double(X, _Mod) when is_float(X) -> %% no check
    <<X:64/float-signed>>;
encode_double(_, _) ->
    exit(badarg).

encode_binary(X, _Mod) ->
    Len = iolist_size(X),
    [<<Len:32/signed>>, X].

encode_struct({'struct',Name,Fields}, Mod)
  when Name == <<"$T">>;
       Name == <<"$L">>;
       Name == <<"$N">>;
       Name == <<"$S">>;
       Name == <<"$P">>;
       Name == <<"$B">>;
       Name == <<"$O">>;
       Name == <<"$A">>;
       Name == <<"$R">> ->
    %% @TODO special treatment for UBF-native messages
    [encode_binary(Name, Mod)
     , encode_fields(Fields, Mod)
     , encode_byte(?STOP, Mod)
    ];
encode_struct({'struct',_Name,Fields}, Mod) ->
    [encode_fields(Fields, Mod)
     , encode_byte(?STOP, Mod)
    ].

encode_map({'map',KeyType,ValueType,List}, Mod) ->
    [encode_byte(encode_field_type(KeyType), Mod)
     , encode_byte(encode_field_type(ValueType), Mod)
     , encode_i32(length(List), Mod)
     , encode_field_datum(KeyType, ValueType, List, Mod)
    ].

encode_set({'set',Type,List}, Mod) ->
    [encode_byte(encode_field_type(Type), Mod)
     , encode_i32(length(List), Mod)
     , encode_field_data(Type, List, Mod)
    ].

encode_list({'list',Type,List}, Mod) ->
    [encode_byte(encode_field_type(Type), Mod)
     , encode_i32(length(List), Mod)
     , encode_field_data(Type, List, Mod)
    ].

encode_fields(List, Mod) ->
    [ encode_field(Field, Mod) || Field <- List ].

encode_field({'field',_Name,Type,Id,Data}, Mod) ->
    [encode_byte(encode_field_type(Type), Mod)
     , encode_i16(Id, Mod)
     , encode_type(Type, Data, Mod)
    ].

encode_field_data(Type, List, Mod) ->
    [ encode_type(Type, Data, Mod) || Data <- List ].

encode_field_datum(KeyType, ValueType, List, Mod) ->
    [ case Data of
          {Key,Value} ->
              [encode_type(KeyType, Key, Mod), encode_type(ValueType, Value, Mod)];
          _ ->
              exit(badarg)
      end || Data <- List ].

encode_field_type('T-VOID')     -> ?VOID;
encode_field_type('T-BOOL')     -> ?BOOL;
encode_field_type('T-BYTE')     -> ?BYTE;
encode_field_type('T-I08')      -> ?I08;
encode_field_type('T-I16')      -> ?I16;
encode_field_type('T-I32')      -> ?I32;
encode_field_type('T-U64')      -> ?U64;
encode_field_type('T-I64')      -> ?I64;
encode_field_type('T-DOUBLE')   -> ?DOUBLE;
encode_field_type('T-BINARY')   -> ?BINARY;
encode_field_type('T-STRUCT')   -> ?STRUCT;
encode_field_type('T-MAP')      -> ?MAP;
encode_field_type('T-SET')      -> ?SET;
encode_field_type('T-LIST')     -> ?LIST;
encode_field_type(_)            -> exit(badarg).

encode_type('T-VOID', X, Mod)   -> encode_void(X, Mod);
encode_type('T-BOOL', X, Mod)   -> encode_bool(X, Mod);
encode_type('T-BYTE', X, Mod)   -> encode_byte(X, Mod);
encode_type('T-I08', X, Mod)    -> encode_i08(X, Mod);
encode_type('T-I16', X, Mod)    -> encode_i16(X, Mod);
encode_type('T-I32', X, Mod)    -> encode_i32(X, Mod);
encode_type('T-U64', X, Mod)    -> encode_u64(X, Mod);
encode_type('T-I64', X, Mod)    -> encode_i64(X, Mod);
encode_type('T-DOUBLE', X, Mod) -> encode_double(X, Mod);
encode_type('T-BINARY', X, Mod) -> encode_binary(X, Mod);
encode_type('T-STRUCT', X, Mod) -> encode_struct(X, Mod);
encode_type('T-MAP', X, Mod)    -> encode_map(X, Mod);
encode_type('T-SET', X, Mod)    -> encode_set(X, Mod);
encode_type('T-LIST', X, Mod)   -> encode_list(X, Mod);
encode_type(_, _, _)            -> exit(badarg).


%%
%%---------------------------------------------------------------------
%%
decode_finish('field', #state{stack=[[H,T,[T1|T2]|T3]|Stack]}=S, Cont) ->
    H1 = list_to_tuple(lists:reverse([H|T])),
    H2 = [[H1|T1]|T2],
    Cont(S#state{stack=[[H2|T3]|Stack]});
decode_finish('field-data', #state{stack=[[H,[T|T1]|T2]|Stack]}=S, Cont) ->
    H1 = [[H|T]|T1],
    Cont(S#state{stack=[[H1|T2]|Stack]});
decode_finish('field-datum', #state{stack=[[H,T,[T1|T2]|T3]|Stack]}=S, Cont) ->
    H1 = [[{T,H}|T1]|T2],
    Cont(S#state{stack=[[H1|T3]|Stack]});
decode_finish(Type, #state{stack=[[[H|T]|T1]|Stack]}=S, Cont)
  when Type =:= 'struct';
       Type =:= 'map';
       Type =:= 'set';
       Type =:= 'list' ->
    H1 = list_to_tuple(lists:reverse([lists:reverse(H)|T])),
    Cont(S#state{stack=[[H1|T1]|Stack]});
decode_finish('message', #state{stack=[H|[[]]],safe=Safe,mod=Mod}=S, Cont) ->
    H1 = list_to_tuple(lists:reverse(H)),
    case H1 of
        {'message',<<"$UBF">>,_Type,_SeqId,Struct} ->
            %% @TODO special treatment for UBF-native messages
            UBF = decode_ubf(Struct, Mod, Safe),
            Cont(S#state{stack=setelement(5,H1,UBF)});
        _ ->
            Cont(S#state{stack=H1})
    end.

decode_message(#state{x=X,stack=undefined}=S, Cont) ->
    case X of
        <<VSN:32/integer-unsigned,X1/binary>> when (VSN band ?VSN_MASK) =:= ?VSN_1 ->
            %% version 1
            case X1 of
                <<Len:32/signed,X2/binary>> when Len >= 0 ->
                    case X2 of
                        <<Name:Len/binary,Id:32/signed,X3/binary>> ->
                            Type = VSN band ?TYPE_MASK,
                            case decode_message_type(Type) of
                                undefined ->
                                    decode_error('message', 'message-type', Type, S);
                                DecodedType ->
                                    Stack1 = [[Id, DecodedType, Name, 'message'], []],
                                    Cont1 = fun(S1) -> decode_finish('message', S1, Cont) end,
                                    decode_struct(S#state{x=X3,stack=Stack1,vsn=?VSN_1}, Cont1)
                            end;
                        _ ->
                            decode_pause(S, Cont, fun decode_message/2)
                    end;
                _ ->
                    decode_pause(S, Cont, fun decode_message/2)
            end;
        <<Len:32/signed,X1/binary>> when Len >= 0 ->
            case X1 of
                <<Name:Len/binary,Type:8/signed,Id:32/signed,X2/binary>> ->
                    case decode_message_type(Type) of
                        undefined ->
                            decode_error('message', 'message-type', Type, S);
                        DecodedType ->
                            Stack1 = [[Id, DecodedType, Name, 'message'], []],
                            Cont1 = fun(S1) -> decode_finish('message', S1, Cont) end,
                            decode_struct(S#state{x=X2,stack=Stack1}, Cont1)
                    end;
                _ ->
                    decode_pause(S, Cont, fun decode_message/2)
            end;
        <<Len:32/signed>> when Len < 0 ->
            decode_error('message', 'method-name', Len, S);
        _ ->
            decode_pause(S, Cont, fun decode_message/2)
    end.

decode_message_type(?CALL)      -> 'T-CALL';
decode_message_type(?REPLY)     -> 'T-REPLY';
decode_message_type(?EXCEPTION) -> 'T-EXCEPTION';
decode_message_type(?ONEWAY)    -> 'T-ONEWAY';
decode_message_type(_)          -> undefined.

decode_struct(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Len:32/signed,X1/binary>> when Len >= 0 ->
            case X1 of
                <<Name:Len/binary,X2/binary>> ->
                    %% @TODO special treatment for UBF-native messages
                    Stack1 = push([[], Name, 'struct'], Stack),
                    decode_fields(S#state{x=X2,stack=Stack1}, Cont);
                _ ->
                    Stack1 = push([[], <<>>, 'struct'], Stack),
                    decode_fields(S#state{x=X,stack=Stack1}, Cont)
            end;
        _ ->
            Stack1 = push([[], <<>>, 'struct'], Stack),
            decode_fields(S#state{x=X,stack=Stack1}, Cont)
    end.

decode_map(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<KeyType:8/signed,ValueType:8/signed,Size:32/signed,X1/binary>> when Size >= 0 ->
            case decode_field_type(KeyType) of
                undefined ->
                    decode_error('map', 'map-key-type', KeyType, S);
                DecodedKeyType ->
                    case decode_field_type(ValueType) of
                        undefined ->
                            decode_error('map', 'map-value-type', ValueType, S);
                        DecodedValueType ->
                            Type = {KeyType,ValueType},
                            Stack1 = push([[], DecodedValueType, DecodedKeyType, 'map'], Stack),
                            Cont1 = fun(S1) -> decode_finish('map', S1, Cont) end,
                            decode_field_datum(S#state{x=X1,stack=Stack1,type=Type,size=Size}, Cont1)
                    end
            end;
        <<_KeyType:8/signed,_ValueType:8/signed,Size:32/signed>> when Size < 0 ->
            decode_error('map', 'map-size', Size, S);
        _ ->
            decode_pause(S, Cont, fun decode_map/2)
    end.

decode_set(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Type:8/signed,Size:32/signed,X1/binary>> when Size >= 0 ->
            case decode_field_type(Type) of
                undefined ->
                    decode_error('set', 'set-type', Type, S);
                DecodedType ->
                    Stack1 = push([[], DecodedType, 'set'], Stack),
                    Cont1 = fun(S1) -> decode_finish('set', S1, Cont) end,
                    decode_field_data(S#state{x=X1,stack=Stack1,type=Type,size=Size}, Cont1)
            end;
        <<_Type:8/signed,Size:32/signed>> when Size < 0 ->
            decode_error('set', 'set-size', Size, S);
        _ ->
            decode_pause(S, Cont, fun decode_set/2)
    end.

decode_list(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Type:8/signed,Size:32/signed,X1/binary>> when Size >= 0 ->
            case decode_field_type(Type) of
                undefined ->
                    decode_error('list', 'list-type', Type, S);
                DecodedType ->
                    Stack1 = push([[], DecodedType, 'list'], Stack),
                    Cont1 = fun(S1) -> decode_finish('list', S1, Cont) end,
                    decode_field_data(S#state{x=X1,stack=Stack1,type=Type,size=Size}, Cont1)
            end;
        <<_Type:8/signed,Size:32/signed>> when Size < 0 ->
            decode_error('list', 'list-size', Size, S);
        _ ->
            decode_pause(S, Cont, fun decode_list/2)
    end.

decode_fields(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<?STOP:8/signed,X1/binary>> ->
            decode_finish('struct', S#state{x=X1}, Cont);
        <<Type:8/signed,Id:16/signed,X2/binary>> ->
            case decode_field_type(Type) of
                undefined ->
                    decode_error('fields', 'field-type', Type, S);
                DecodedType ->
                    Name = <<>>,
                    Stack1 = push([Id, DecodedType, Name, 'field'], Stack),
                    Cont2 = fun(S2) -> decode_fields(S2, Cont) end,
                    Cont1 = fun(S1) -> decode_finish('field', S1, Cont2) end,
                    decode_type(Type, S#state{x=X2,stack=Stack1}, Cont1)
            end;
        _ ->
            decode_pause(S, Cont, fun decode_fields/2)
    end.

decode_field_data(#state{size=0}=S, Cont) ->
    Cont(S#state{type=undefined,size=undefined});
decode_field_data(#state{type=Type,size=Size}=S, Cont) ->
    Cont2 = fun(S2) -> decode_field_data(S2#state{type=Type,size=Size-1}, Cont) end,
    Cont1 = fun(S1) -> decode_finish('field-data', S1, Cont2) end,
    decode_type(Type, S, Cont1).

decode_field_datum(#state{size=0}=S, Cont) ->
    Cont(S#state{type=undefined,size=undefined});
decode_field_datum(#state{type={KeyType,ValueType}=Type,size=Size}=S, Cont) ->
    Cont3 = fun(S3) -> decode_field_datum(S3#state{type=Type,size=Size-1}, Cont) end,
    Cont2 = fun(S2) -> decode_finish('field-datum', S2, Cont3) end,
    Cont1 = fun(S1) -> decode_type(ValueType, S1, Cont2) end,
    decode_type(KeyType, S, Cont1).

decode_field_type(?VOID)      -> 'T-VOID';
decode_field_type(?BOOL)      -> 'T-BOOL';
decode_field_type(?BYTE)      -> 'T-BYTE';
decode_field_type(?I08)       -> 'T-I08';
decode_field_type(?I16)       -> 'T-I16';
decode_field_type(?I32)       -> 'T-I32';
decode_field_type(?U64)       -> 'T-U64';
decode_field_type(?I64)       -> 'T-I64';
decode_field_type(?DOUBLE)    -> 'T-DOUBLE';
decode_field_type(?BINARY)    -> 'T-BINARY';
decode_field_type(?STRUCT)    -> 'T-STRUCT';
decode_field_type(?MAP)       -> 'T-MAP';
decode_field_type(?SET)       -> 'T-SET';
decode_field_type(?LIST)      -> 'T-LIST';
decode_field_type(_)          -> undefined.

decode_type(?VOID, S, Cont)   -> decode_void(S, Cont);
decode_type(?BOOL, S, Cont)   -> decode_bool(S, Cont);
decode_type(?BYTE, S, Cont)   -> decode_byte(S, Cont);
decode_type(?I08, S, Cont)    -> decode_i08(S, Cont);
decode_type(?I16, S, Cont)    -> decode_i16(S, Cont);
decode_type(?I32, S, Cont)    -> decode_i32(S, Cont);
decode_type(?U64, S, Cont)    -> decode_u64(S, Cont);
decode_type(?I64, S, Cont)    -> decode_i64(S, Cont);
decode_type(?DOUBLE, S, Cont) -> decode_double(S, Cont);
decode_type(?BINARY, S, Cont) -> decode_binary(S, Cont);
decode_type(?STRUCT, S, Cont) -> decode_struct(S, Cont);
decode_type(?MAP, S, Cont)    -> decode_map(S, Cont);
decode_type(?SET, S, Cont)    -> decode_set(S, Cont);
decode_type(?LIST, S, Cont)   -> decode_list(S, Cont).


decode_void(#state{stack=Stack}=S, Cont) ->
    Stack1 = push(undefined, Stack),
    Cont(S#state{stack=Stack1}).

decode_bool(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<?FALSE:8/signed,X1/binary>> ->
            Stack1 = push(false, Stack),
            Cont(S#state{x=X1,stack=Stack1});
        <<?TRUE:8/signed,X1/binary>> ->
            Stack1 = push(true, Stack),
            Cont(S#state{x=X1,stack=Stack1});
        <<Other:8/signed,_/binary>> ->
            decode_error('bool', 'value', Other, S);
        _ ->
            decode_pause(S, Cont, fun decode_bool/2)
    end.

decode_byte(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Byte:1/binary,X1/binary>> ->
            Stack1 = push(Byte, Stack),
            Cont(S#state{x=X1,stack=Stack1});
        _ ->
            decode_pause(S, Cont, fun decode_byte/2)
    end.

decode_i08(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Int:8/signed,X1/binary>> ->
            Stack1 = push(Int, Stack),
            Cont(S#state{x=X1,stack=Stack1});
        _ ->
            decode_pause(S, Cont, fun decode_i08/2)
    end.

decode_i16(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Int:16/signed,X1/binary>> ->
            Stack1 = push(Int, Stack),
            Cont(S#state{x=X1,stack=Stack1});
        _ ->
            decode_pause(S, Cont, fun decode_i16/2)
    end.

decode_i32(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Int:32/signed,X1/binary>> ->
            Stack1 = push(Int, Stack),
            Cont(S#state{x=X1,stack=Stack1});
        _ ->
            decode_pause(S, Cont, fun decode_i16/2)
    end.

decode_u64(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Int:64/unsigned,X1/binary>> ->
            Stack1 = push(Int, Stack),
            Cont(S#state{x=X1,stack=Stack1});
        _ ->
            decode_pause(S, Cont, fun decode_u64/2)
    end.

decode_i64(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Int:64/signed,X1/binary>> ->
            Stack1 = push(Int, Stack),
            Cont(S#state{x=X1,stack=Stack1});
        _ ->
            decode_pause(S, Cont, fun decode_i64/2)
    end.

decode_double(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Double:64/float-signed,X1/binary>> ->
            Stack1 = push(Double, Stack),
            Cont(S#state{x=X1,stack=Stack1});
        _ ->
            decode_pause(S, Cont, fun decode_double/2)
    end.

decode_binary(#state{x=X,stack=Stack}=S, Cont) ->
    case X of
        <<Len:32/signed,X1/binary>> when Len >= 0 ->
            case X1 of
                <<Binary:Len/binary,X2/binary>> ->
                    Stack1 = push(Binary, Stack),
                    Cont(S#state{x=X2,stack=Stack1});
                _ ->
                    decode_pause(S, Cont, fun decode_binary/2)
            end;
        <<Len:32/signed>> when Len < 0 ->
            decode_error('binary', 'length', Len, S);
        _ ->
            decode_pause(S, Cont, fun decode_binary/2)
    end.


%%
%%---------------------------------------------------------------------
%%
encode_ubf(X, _Mod) when is_binary(X) ->
    encode_ubf_binary(X);
encode_ubf(X, _Mod) when is_integer(X) ->
    encode_ubf_integer(X);
encode_ubf(X, _Mod) when is_float(X) ->
    encode_ubf_float(X);
encode_ubf(X, _Mod) when is_atom(X) ->
    encode_ubf_atom(X);
encode_ubf(X, Mod) when is_list(X) ->
    encode_ubf_list(X, Mod);
encode_ubf(?S(X), _Mod) ->
    encode_ubf_string(X);
encode_ubf(?P(X), Mod) ->
    encode_ubf_proplist(X, Mod);
encode_ubf(X, Mod) when is_tuple(X) ->
    encode_ubf_tuple(X, Mod).

encode_ubf_binary(X) ->
    {'struct', <<"$B">>, [{'field', <<>>, 'T-BINARY', 1, X}]}.

encode_ubf_integer(X) ->
    %% @TODO optimize given the size of X
    {'struct', <<"$N">>, [{'field', <<>>, 'T-I64', 1, X}]}.

encode_ubf_float(X) ->
    {'struct', <<"$N">>, [{'field', <<>>, 'T-DOUBLE', 1, X}]}.

encode_ubf_atom(X) when X == true; X == false->
    {'struct', <<"$O">>, [{'field', <<>>, 'T-BOOL', 1, X}]};
encode_ubf_atom(X) ->
    {'struct', <<"$A">>, [{'field', <<>>, 'T-BINARY', 1, atom_to_binary(X)}]}.

encode_ubf_list(X, Mod) ->
    List = {'list', 'T-STRUCT', encode_ubf_list(X, [], Mod)},
    {'struct', <<"$L">>, [{'field', <<>>, 'T-LIST', 1, List}]}.

encode_ubf_list([], Acc, _Mod) ->
    lists:reverse(Acc);
encode_ubf_list([H|T], Acc, Mod) ->
    NewAcc = [encode_ubf(H, Mod)|Acc],
    encode_ubf_list(T, NewAcc, Mod).

encode_ubf_string(X) when is_list(X) ->
    {'struct', <<"$S">>, [{'field', <<>>, 'T-BINARY', 1, list_to_binary(X)}]}.

encode_ubf_proplist(X, Mod) when is_list(X) ->
    List = {'map', 'T-STRUCT', 'T-STRUCT', encode_ubf_proplist(X, [], Mod)},
    {'struct', <<"$P">>, [{'field', <<>>, 'T-MAP', 1, List}]}.

encode_ubf_proplist([], Acc, _Mod) ->
    lists:reverse(Acc);
encode_ubf_proplist([{K,V}|T], Acc, Mod) ->
    NewAcc = [{encode_ubf(K, Mod),encode_ubf(V, Mod)}|Acc],
    encode_ubf_proplist(T, NewAcc, Mod).


encode_ubf_tuple({}, _Mod) ->
    List = {'list', 'T-STRUCT', []},
    {'struct', <<"$T">>, [{'field', <<>>, 'T-LIST', 1, List}]};
encode_ubf_tuple(X, Mod) when not is_atom(element(1, X)) ->
    List = {'list', 'T-STRUCT', encode_ubf_tuple(1, X, [], Mod)},
    {'struct', <<"$T">>, [{'field', <<>>, 'T-LIST', 1, List}]};
encode_ubf_tuple(X, Mod) ->
    RecName = element(1, X),
    Y = {RecName, tuple_size(X)-1},
    case lists:member(Y, Mod:contract_records()) of
        false ->
            List = {'list', 'T-STRUCT', encode_ubf_tuple(1, X, [], Mod)},
            {'struct', <<"$T">>, [{'field', <<>>, 'T-LIST', 1, List}]};
        true ->
            %% @TODO optimize this code
            Keys = list_to_tuple(Mod:contract_record(Y)),
            Map = {'map', 'T-BINARY', 'T-STRUCT', [{<<>>,encode_ubf_atom(RecName)}|encode_ubf_record(2, X, Keys, [], Mod)]},
            {'struct', <<"$R">>, [{'field', <<>>, 'T-MAP', 1, Map}]}
    end.

encode_ubf_tuple(N, X, Acc, _Mod) when is_integer(N), N > tuple_size(X) ->
    lists:reverse(Acc);
encode_ubf_tuple(N, X, Acc, Mod) ->
    NewAcc = [encode_ubf(element(N, X), Mod)|Acc],
    encode_ubf_tuple(N+1, X, NewAcc, Mod).

encode_ubf_record(N, X, _Keys, Acc, _Mod) when is_integer(N), N > tuple_size(X) ->
    Acc;
encode_ubf_record(N, X, Keys, Acc, Mod) ->
    NewAcc = [{atom_to_binary(element(N-1, Keys)), encode_ubf(element(N, X), Mod)}|Acc],
    encode_ubf_record(N+1, X, Keys, NewAcc, Mod).


%%
%%---------------------------------------------------------------------
%%
decode_ubf({'struct', <<"$B">>, [{'field', <<>>, 'T-BINARY', 1, X}]}, _Mod, _Safe) when is_binary(X) ->
    X;
decode_ubf({'struct', <<"$N">>, [{'field', <<>>, 'T-I64', 1, X}]}, _Mod, _Safe) when is_integer(X) ->
    X;
decode_ubf({'struct', <<"$N">>, [{'field', <<>>, 'T-DOUBLE', 1, X}]}, _Mod, _Safe) when is_float(X) ->
    X;
decode_ubf({'struct', <<"$O">>, [{'field', <<>>, 'T-BOOL', 1, X}]}, _Mod, _Safe) when X == true; X== false ->
    X;
decode_ubf({'struct', <<"$A">>, [{'field', <<>>, 'T-BINARY', 1, X}]}, _Mod, Safe) when is_binary(X) ->
    decode_ubf_atom(X, Safe);
decode_ubf({'struct', <<"$L">>, [{'field', <<>>, 'T-LIST', 1, {'list', 'T-STRUCT', X}}]}, Mod, Safe) when is_list(X) ->
    decode_ubf_list(X, Mod, Safe);
decode_ubf({'struct', <<"$S">>, [{'field', <<>>, 'T-BINARY', 1, X}]}, _Mod, _Safe) when is_binary(X) ->
    decode_ubf_string(X);
decode_ubf({'struct', <<"$P">>, [{'field', <<>>, 'T-MAP', 1, {'map', 'T-STRUCT', 'T-STRUCT', X}}]}, Mod, Safe) when is_list(X) ->
    decode_ubf_proplist(X, Mod, Safe);
decode_ubf({'struct', <<"$T">>, [{'field', <<>>, 'T-LIST', 1, {'list', 'T-STRUCT', X}}]}, Mod, Safe) when is_list(X) ->
    decode_ubf_tuple(X, Mod, Safe);
decode_ubf({'struct', <<"$R">>, [{'field', <<>>, 'T-MAP', 1, {'map', 'T-BINARY', 'T-STRUCT', X}}]}, Mod, Safe) when is_list(X) ->
    case lists:keytake(<<>>, 1, X) of
        {value, {<<>>, RecName}, Y} ->
            decode_ubf_record(RecName, Y, Mod, Safe);
        false ->
            exit(badrecord)
    end.

decode_ubf_atom(X, true) when is_binary(X) ->
    binary_to_existing_atom(X);
decode_ubf_atom(X, false) when is_binary(X) ->
    binary_to_atom(X).

decode_ubf_list(X, Mod, Safe) ->
    decode_ubf_list(X, [], Mod, Safe).

decode_ubf_list([], Acc, _Mod, _Safe) ->
    lists:reverse(Acc);
decode_ubf_list([H|T], Acc, Mod, Safe) ->
    NewAcc = [decode_ubf(H, Mod, Safe)|Acc],
    decode_ubf_list(T, NewAcc, Mod, Safe).

decode_ubf_string(X) when is_binary(X) ->
    ?S(binary_to_list(X)).

decode_ubf_proplist(X, Mod, Safe) when is_list(X) ->
    ?P([ {decode_ubf(K, Mod, Safe), decode_ubf(V, Mod, Safe)} || {K, V} <- X ]).

decode_ubf_tuple(X, Mod, Safe) ->
    decode_ubf_tuple(X, [], Mod, Safe).

decode_ubf_tuple([], Acc, _Mod, _Safe) ->
    list_to_tuple(lists:reverse(Acc));
decode_ubf_tuple([H|T], Acc, Mod, Safe) ->
    NewAcc = [decode_ubf(H, Mod, Safe)|Acc],
    decode_ubf_tuple(T, NewAcc, Mod, Safe).

decode_ubf_record(RecNameStr, X, Mod, Safe) ->
    RecName = decode_ubf_atom(RecNameStr, Safe),
    Y = {RecName, length(X)},
    Keys = Mod:contract_record(Y),
    decode_ubf_record(RecName, Keys, X, [], Mod, Safe).

decode_ubf_record(RecName, [], [], Acc, _Mod, _Safe) ->
    list_to_tuple([RecName|lists:reverse(Acc)]);
decode_ubf_record(RecName, [H|T], X, Acc, Mod, Safe) ->
    K = atom_to_binary(H),
    case lists:keytake(K, 1, X) of
        {value, {K, V}, NewX} ->
            NewAcc = [decode_ubf(V, Mod, Safe)|Acc],
            decode_ubf_record(RecName, T, NewX, NewAcc, Mod, Safe);
        false ->
            exit({badrecord, RecName})
    end.


%%
%%---------------------------------------------------------------------
%%
atom_to_binary(X) ->
    list_to_binary(atom_to_list(X)).

binary_to_atom(X) ->
    list_to_atom(binary_to_list(X)).

binary_to_existing_atom(X) ->
    list_to_existing_atom(binary_to_list(X)).

push(X, [Top|Rest]) ->
    [[X|Top]|Rest].
