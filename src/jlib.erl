%%%----------------------------------------------------------------------
%%% File    : jlib.erl
%%% Author  : Alexey Shchepin <alexey@process-one.net>
%%% Purpose : General XMPP library.
%%% Created : 23 Nov 2002 by Alexey Shchepin <alexey@process-one.net>
%%%
%%%
%%% ejabberd, Copyright (C) 2002-2010   ProcessOne
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%----------------------------------------------------------------------

-module(jlib).
-author('alexey@process-one.net').

-export([parse_xdata_submit/1,
	 timestamp_to_iso/1, % TODO: Remove once XEP-0091 is Obsolete
	 timestamp_to_iso/2,
	 timestamp_to_xml/4,
	 timestamp_to_xml/1, % TODO: Remove once XEP-0091 is Obsolete
	 now_to_utc_string/1,
	 now_to_local_string/1,
	 datetime_string_to_timestamp/1,
	 decode_base64/1,
	 encode_base64/1,
	 ip_to_list/1,
	 rsm_encode/1,
	 rsm_encode/2,
	 rsm_decode/1,
	 from_old_jid/1,
	 short_jid/1,
	 short_bare_jid/1,
	 short_prepd_jid/1,
	 short_prepd_bare_jid/1]).

-include_lib("exmpp/include/exmpp.hrl").

-include("jlib.hrl").

%% @type shortjid() = {U, S, R}
%%     U = binary()
%%     S = binary()
%%     R = binary().

parse_xdata_submit(#xmlel{attrs = Attrs, children = Els}) ->
    case exmpp_xml:get_attribute_from_list_as_list(Attrs, 'type', "") of
	"submit" ->
	    lists:reverse(parse_xdata_fields(Els, []));
	_ ->
	    invalid
    end.

parse_xdata_fields([], Res) ->
    Res;
parse_xdata_fields([#xmlel{name = 'field', attrs = Attrs, children = SubEls} |
  Els], Res) ->
    case exmpp_xml:get_attribute_from_list_as_list(Attrs, 'var', "") of
	"" ->
	    parse_xdata_fields(Els, Res);
	Var ->
	    Field = {Var, lists:reverse(parse_xdata_values(SubEls, []))},
	    parse_xdata_fields(Els, [Field | Res])
    end;
parse_xdata_fields([_ | Els], Res) ->
    parse_xdata_fields(Els, Res).

parse_xdata_values([], Res) ->
    Res;
parse_xdata_values([#xmlel{name = 'value', children = SubEls} | Els], Res) ->
    Val = exmpp_xml:get_cdata_from_list_as_list(SubEls),
    parse_xdata_values(Els, [Val | Res]);
parse_xdata_values([_ | Els], Res) ->
    parse_xdata_values(Els, Res).

rsm_decode(#iq{payload=SubEl})->
	rsm_decode(SubEl);
rsm_decode(#xmlel{}=SubEl)->
	case exmpp_xml:get_element(SubEl, 'set') of
		undefined ->
			none;
		#xmlel{name = 'set', children = SubEls}->
			lists:foldl(fun rsm_parse_element/2, #rsm_in{}, SubEls)
	end.

rsm_parse_element(#xmlel{name = 'max'}=Elem, RsmIn)->
    CountStr = exmpp_xml:get_cdata_as_list(Elem),
    {Count, _} = string:to_integer(CountStr),
    RsmIn#rsm_in{max=Count};

rsm_parse_element(#xmlel{name = 'before'}=Elem, RsmIn)->
    UID = exmpp_xml:get_cdata_as_list(Elem),
    RsmIn#rsm_in{direction=before, id=UID};

rsm_parse_element(#xmlel{name = 'after'}=Elem, RsmIn)->
    UID = exmpp_xml:get_cdata_as_list(Elem),
    RsmIn#rsm_in{direction=aft, id=UID};

rsm_parse_element(#xmlel{name = 'index'}=Elem, RsmIn)->
    IndexStr = exmpp_xml:get_cdata_as_list(Elem),
    {Index, _} = string:to_integer(IndexStr),
    RsmIn#rsm_in{index=Index};


rsm_parse_element(_, RsmIn)->
    RsmIn.

rsm_encode(#iq{payload=SubEl}=IQ_Rec,RsmOut)->
    Set = #xmlel{ns = ?NS_RSM, name = 'set', children =
	   lists:reverse(rsm_encode_out(RsmOut))},
    New = exmpp_xml:prepend_child(SubEl, Set),
    IQ_Rec#iq{payload=New}.

rsm_encode(none)->
    [];
rsm_encode(RsmOut)->
    [#xmlel{ns = ?NS_RSM, name = 'set', children = lists:reverse(rsm_encode_out(RsmOut))}].
rsm_encode_out(#rsm_out{count=Count, index=Index, first=First, last=Last})->
    El = rsm_encode_first(First, Index, []),
    El2 = rsm_encode_last(Last,El),
    rsm_encode_count(Count, El2).

rsm_encode_first(undefined, undefined, Arr) ->
    Arr;
rsm_encode_first(First, undefined, Arr) ->
    [#xmlel{ns = ?NS_RSM, name = 'first', children = [#xmlcdata{cdata = list_to_binary(First)}]}|Arr];
rsm_encode_first(First, Index, Arr) ->
    [#xmlel{ns = ?NS_RSM, name = 'first', attrs = [?XMLATTR('index', Index)], children = [#xmlcdata{cdata = list_to_binary(First)}]}|Arr].

rsm_encode_last(undefined, Arr) -> Arr;
rsm_encode_last(Last, Arr) ->
    [#xmlel{ns = ?NS_RSM, name = 'last', children = [#xmlcdata{cdata = list_to_binary(Last)}]}|Arr].

rsm_encode_count(undefined, Arr)-> Arr;
rsm_encode_count(Count, Arr)->
    [#xmlel{ns = ?NS_RSM, name = 'count', children = [#xmlcdata{cdata = i2b(Count)}]} | Arr].

i2b(I) when is_integer(I) -> list_to_binary(integer_to_list(I));
i2b(L) when is_list(L)    -> list_to_binary(L).

%% Timezone = utc | {Hours, Minutes}
%% Hours = integer()
%% Minutes = integer()
timestamp_to_iso({{Year, Month, Day}, {Hour, Minute, Second}}, Timezone) ->
    Timestamp_string = lists:flatten(
      io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0w",
        [Year, Month, Day, Hour, Minute, Second])),
    Timezone_string = case Timezone of
	utc -> "Z";
	{TZh, TZm} -> 
		Sign = case TZh >= 0 of
			true -> "+";
			false -> "-"
		end,
		io_lib:format("~s~2..0w:~2..0w", [Sign, abs(TZh),TZm])
    end,
    {Timestamp_string, Timezone_string}.

timestamp_to_iso({{Year, Month, Day}, {Hour, Minute, Second}}) ->
    lists:flatten(
      io_lib:format("~4..0w~2..0w~2..0wT~2..0w:~2..0w:~2..0w",
		    [Year, Month, Day, Hour, Minute, Second])).

timestamp_to_xml(DateTime, Timezone, FromJID, Desc) ->
    {T_string, Tz_string} = timestamp_to_iso(DateTime, Timezone),
    From = exmpp_jid:to_list(FromJID),
    P1 = exmpp_xml:set_attributes(#xmlel{ns = ?NS_DELAY, name = 'delay'},
      [{'from', From},
       {'stamp', T_string ++ Tz_string}]),
    exmpp_xml:set_cdata(P1, Desc).

%% TODO: Remove this function once XEP-0091 is Obsolete
timestamp_to_xml({{Year, Month, Day}, {Hour, Minute, Second}}) ->
    Timestamp = lists:flatten(
      io_lib:format("~4..0w~2..0w~2..0wT~2..0w:~2..0w:~2..0w",
	[Year, Month, Day, Hour, Minute, Second])),
    exmpp_xml:set_attribute(#xmlel{ns = ?NS_DELAY_OLD, name = 'x'},
      'stamp', Timestamp).

now_to_utc_string({MegaSecs, Secs, MicroSecs}) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} =
	calendar:now_to_universal_time({MegaSecs, Secs, MicroSecs}),
    lists:flatten(
      io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0w.~6..0wZ",
		    [Year, Month, Day, Hour, Minute, Second, MicroSecs])).

now_to_local_string({MegaSecs, Secs, MicroSecs}) ->
    LocalTime = calendar:now_to_local_time({MegaSecs, Secs, MicroSecs}),
    UTCTime = calendar:now_to_universal_time({MegaSecs, Secs, MicroSecs}),
    Seconds = calendar:datetime_to_gregorian_seconds(LocalTime) -
            calendar:datetime_to_gregorian_seconds(UTCTime),
    {{H, M, _}, Sign} = if
			    Seconds < 0 ->
				{calendar:seconds_to_time(-Seconds), "-"};
			    true ->
				{calendar:seconds_to_time(Seconds), "+"}
    end,
    {{Year, Month, Day}, {Hour, Minute, Second}} = LocalTime,
    lists:flatten(
      io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0w.~6..0w~s~2..0w:~2..0w",
		    [Year, Month, Day, Hour, Minute, Second, MicroSecs, Sign, H, M])).


% yyyy-mm-ddThh:mm:ss[.sss]{Z|{+|-}hh:mm} -> {MegaSecs, Secs, MicroSecs}
datetime_string_to_timestamp(TimeStr) ->
    case catch parse_datetime(TimeStr) of
	{'EXIT', _Err} ->
	    undefined;
	TimeStamp ->
	    TimeStamp
    end.

parse_datetime(TimeStr) ->
    [Date, Time] = string:tokens(TimeStr, "T"),
    D = parse_date(Date),
    {T, MS, TZH, TZM} = parse_time(Time),
    S = calendar:datetime_to_gregorian_seconds({D, T}),
    S1 = calendar:datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}}),
    Seconds = (S - S1) - TZH * 60 * 60 - TZM * 60,
    {Seconds div 1000000, Seconds rem 1000000, MS}.

% yyyy-mm-dd
parse_date(Date) ->
    [Y, M, D] = string:tokens(Date, "-"),
    Date1 = {list_to_integer(Y), list_to_integer(M), list_to_integer(D)},
    case calendar:valid_date(Date1) of
	true ->
	    Date1;
	_ ->
	    false
    end.

% hh:mm:ss[.sss]TZD
parse_time(Time) ->
    case string:str(Time, "Z") of
	0 ->
	    parse_time_with_timezone(Time);
	_ ->
	    [T | _] = string:tokens(Time, "Z"),
	    {TT, MS} = parse_time1(T),
	    {TT, MS, 0, 0}
    end.

parse_time_with_timezone(Time) ->
    case string:str(Time, "+") of
	0 ->
	    case string:str(Time, "-") of
		0 ->
		    false;
		_ ->
		    parse_time_with_timezone(Time, "-")
	    end;
	_ ->
	    parse_time_with_timezone(Time, "+")
    end.

parse_time_with_timezone(Time, Delim) ->
    [T, TZ] = string:tokens(Time, Delim),
    {TZH, TZM} = parse_timezone(TZ),
    {TT, MS} = parse_time1(T),
    case Delim of
	"-" ->
	    {TT, MS, -TZH, -TZM};
	"+" ->
	    {TT, MS, TZH, TZM}
    end.

parse_timezone(TZ) ->
    [H, M] = string:tokens(TZ, ":"),
    {[H1, M1], true} = check_list([{H, 12}, {M, 60}]),
    {H1, M1}.

parse_time1(Time) ->
    [HMS | T] =  string:tokens(Time, "."),
    MS = case T of
	     [] ->
		 0;
	     [Val] ->
		 list_to_integer(string:left(Val, 6, $0))
	 end,
    [H, M, S] = string:tokens(HMS, ":"),
    {[H1, M1, S1], true} = check_list([{H, 24}, {M, 60}, {S, 60}]),
    {{H1, M1, S1}, MS}.

check_list(List) ->
    lists:mapfoldl(
      fun({L, N}, B)->
	  V = list_to_integer(L),
	  if
	      (V >= 0) and (V =< N) ->
		  {V, B};
	      true ->
		  {false, false}
	  end
      end, true, List).


%
% Base64 stuff (based on httpd_util.erl)
%

decode_base64(S) ->
    decode1_base64([C || C <- S,
			 C /= $ ,
			 C /= $\t,
			 C /= $\n,
			 C /= $\r]).

decode1_base64([]) ->
    [];
decode1_base64([Sextet1,Sextet2,$=,$=|Rest]) ->
    Bits2x6=
	(d(Sextet1) bsl 18) bor
	(d(Sextet2) bsl 12),
    Octet1=Bits2x6 bsr 16,
    [Octet1|decode1_base64(Rest)];
decode1_base64([Sextet1,Sextet2,Sextet3,$=|Rest]) ->
    Bits3x6=
	(d(Sextet1) bsl 18) bor
	(d(Sextet2) bsl 12) bor
	(d(Sextet3) bsl 6),
    Octet1=Bits3x6 bsr 16,
    Octet2=(Bits3x6 bsr 8) band 16#ff,
    [Octet1,Octet2|decode1_base64(Rest)];
decode1_base64([Sextet1,Sextet2,Sextet3,Sextet4|Rest]) ->
    Bits4x6=
	(d(Sextet1) bsl 18) bor
	(d(Sextet2) bsl 12) bor
	(d(Sextet3) bsl 6) bor
	d(Sextet4),
    Octet1=Bits4x6 bsr 16,
    Octet2=(Bits4x6 bsr 8) band 16#ff,
    Octet3=Bits4x6 band 16#ff,
    [Octet1,Octet2,Octet3|decode1_base64(Rest)];
decode1_base64(_CatchAll) ->
    "".

d(X) when X >= $A, X =<$Z ->
    X-65;
d(X) when X >= $a, X =<$z ->
    X-71;
d(X) when X >= $0, X =<$9 ->
    X+4;
d($+) -> 62;
d($/) -> 63;
d(_) -> 63.


encode_base64([]) ->
    [];
encode_base64([A]) ->
    [e(A bsr 2), e((A band 3) bsl 4), $=, $=];
encode_base64([A,B]) ->
    [e(A bsr 2), e(((A band 3) bsl 4) bor (B bsr 4)), e((B band 15) bsl 2), $=];
encode_base64([A,B,C|Ls]) ->
    encode_base64_do(A,B,C, Ls).
encode_base64_do(A,B,C, Rest) ->
    BB = (A bsl 16) bor (B bsl 8) bor C,
    [e(BB bsr 18), e((BB bsr 12) band 63), 
     e((BB bsr 6) band 63), e(BB band 63)|encode_base64(Rest)].

e(X) when X >= 0, X < 26 -> X+65;
e(X) when X>25, X<52 ->     X+71;
e(X) when X>51, X<62 ->     X-4;
e(62) ->                    $+;
e(63) ->                    $/;
e(X) ->                     exit({bad_encode_base64_token, X}).

%% Convert Erlang inet IP to list
ip_to_list({IP, _Port}) ->
    ip_to_list(IP);
ip_to_list({A,B,C,D}) ->
    lists:flatten(io_lib:format("~w.~w.~w.~w",[A,B,C,D])).

% --------------------------------------------------------------------
% Compat layer.
% --------------------------------------------------------------------

%% @spec (JID) -> New_JID
%%     JID = jid()
%%     New_JID = jid()
%% @doc Convert a JID from its ejabberd form to its exmpp form.
%%
%% Empty fields are set to `undefined', not the empty string.

%%TODO: this doesn't make sence!, it is still used?.
from_old_jid({jid, NodeRaw, DomainRaw, ResourceRaw, _, _, _}) ->
    Node = exmpp_stringprep:nodeprep(NodeRaw),
    Domain = exmpp_stringprep:resourceprep(DomainRaw),
    Resource = exmpp_stringprep:nameprep(ResourceRaw),
    exmpp_jid:make(Node,Domain,Resource).


short_jid(JID) ->
    {exmpp_jid:node(JID), exmpp_jid:domain(JID), exmpp_jid:resource(JID)}.

short_bare_jid(JID) ->
    short_jid(exmpp_jid:bare(JID)).

short_prepd_jid(JID) ->
    {exmpp_jid:prep_node(JID), 
     exmpp_jid:prep_domain(JID), 
     exmpp_jid:prep_resource(JID)}.

short_prepd_bare_jid(JID) ->
    short_prepd_jid(exmpp_jid:bare(JID)).


