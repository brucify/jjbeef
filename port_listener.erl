%%%-------------------------------------------------------------------
%%% @author  <Bruce@THINKPAD>
%%% @copyright (C) 2011, 
%%% @doc
%%%
%%% @end
%%% Created : 18 Oct 2011 by  <Bruce@THINKPAD>
%%%-------------------------------------------------------------------
-module(port_listener).
-export([listen/3, start/3]).

-define(TCP_OPTIONS, [binary, {packet, 0}, {active, false}, {reuseaddr, true}]).

start(Port, Dl_pid, Parent) ->
    spawn(?MODULE, listen, [Port, Dl_pid, Parent]).

listen(Port, Dl_pid, Parent) ->
    {ok, LSocket} = gen_tcp:listen(Port, ?TCP_OPTIONS),
    accept(LSocket, Dl_pid, Parent).

accept(LSocket, Dl_pid, Parent) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    spawn(fun() -> recv(Socket, Dl_pid, Parent) end),
    accept(LSocket, Dl_pid, Parent).


recv(Socket, Dl_pid, Parent) ->
    My_peer_id = download_manager:get_my_id(Dl_pid),
    My_info_hash = download_manager:get_my_info_hash(Dl_pid),

    case handshake_handler:recv_handshake(Socket, My_info_hash) of
	{ok, {Socket, Peer_id}} ->
	    case handshake_handler:send_handshake({socket, Socket}, My_info_hash, My_peer_id) of
		{ok, Socket} ->
		   case peers:insert_valid_peer(Parent, Peer_id, Socket) of
		       ok ->
			   ok;
		       %%			   io:format("~n~nIncoming peers successfully handshaken and inserted! ~n~n ");
		       {error, Reason} -> {error, Reason}
		   end;
		{error, Reason} -> 
		    {error, Reason}
		   %% io:format("~n***Port_listener~w error** reason: ~w~n", [self(), Reason])
	    end;
	{error, Reason} ->
	    {error, Reason}
	  %%  io:format("~n***Port_listener~w error** reason: ~w~n", [self(), Reason])
    end.