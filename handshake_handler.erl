%%%-------------------------------------------------------------------
%%% @author  <Bruce@THINKPAD>
%%% @copyright (C) 2011, 
%%% @doc
%%%
%%% @end
%%% Created : 18 Oct 2011 by  <Bruce@THINKPAD>
%%%-------------------------------------------------------------------
-module(handshake_handler).
-export([send_handshake/4, recv_handshake/3]).

send_handshake({ip, Host, Port}, My_info_hash, My_peer_id, From) ->    
    case gen_tcp:connect(Host, Port, [binary, {active, false},
				      {packet, 0}], 1000) of
	{ok, Socket} ->	   	   
	    send_handshake({socket, Socket}, My_info_hash, My_peer_id, From);
	{error, Reason} ->
	    {error, Reason}
    end;
send_handshake({socket, Socket}, My_info_hash, My_peer_id, From) ->
    Msg = list_to_binary([<<19>>,<<"BitTorrent protocol">>,
			  <<3,2,1,3,2,1,2,3>>, My_info_hash,
			  list_to_binary(My_peer_id)]),
    case gen_tcp:send(Socket, Msg) of
	ok ->
	    io:format("~n~nFrom: ~w Connected, sent info_hash= ~w ~n~n", [From, My_info_hash]),
	    {ok, Socket};	    
	{error, Reason} ->
	    {error, Reason}
    end.

recv_handshake(Socket, My_info_hash, From) ->
    case gen_tcp:recv(Socket, 20) of
	{ok, <<19, "BitTorrent protocol">>} ->
	    case gen_tcp:recv(Socket, 48) of
		{ok, <<_Reserved:64,
		       Info_hash:160,
		       Peer_id:160>>} ->
		    io:format("~n~n From:~w handshake received. their info_hash= ~w ~n~n", [From, <<Info_hash:160>>]),
		    case  binary_to_list(<<Info_hash:160>>) =:= binary_to_list(My_info_hash) of
			true ->
			    {ok, {Socket, Peer_id}};
			false ->
			    gen_tcp:close(Socket),
			    {error, false_info_hash}
		    end
	    end;
	{ok, Data} ->	
	    io:format("recv handshake unknown data: ~w~n", [Data]),
	    {error, unknown_data};
	{error, Reason} ->
	    io:format("recv handshake error: ~w~n", [Reason]),
	    {error, Reason}
    end.
