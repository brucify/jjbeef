%%%-------------------------------------------------------------------
%%% @author  <Bruce@THINKPAD>
%%% @copyright (C) 2011, 
%%% @doc
%%% This module takes the variables from the message and processes them
%%%
%%% @end
%%% Created : 16 Dec 2011 by  <Bruce@THINKPAD>
%%%-------------------------------------------------------------------
-module(message_reader).

%% API
-export([start/6, read_msg/3]).

%% Internal function
-export([loop/6]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% starts the process
%%
%% @spec start(Requester_pid, Uploader_pid, Peer_mutex_pid, 
%% Piece_mutex_pid, File_storage_pid, Peer_id) -> Pid
%% @end
%%--------------------------------------------------------------------
start(Requester_pid, Uploader_pid, Peer_mutex_pid, Piece_mutex_pid, File_storage_pid, Peer_id) ->
    spawn(?MODULE, loop, [Requester_pid, Uploader_pid, Peer_mutex_pid, Piece_mutex_pid, File_storage_pid, Peer_id]).

%%--------------------------------------------------------------------
%% @doc
%% sends the variables to the loop
%%
%% @spec read_msg(Pid, Type, Args) -> Message
%% @end
%%--------------------------------------------------------------------
read_msg(Pid, Type, Args) ->
    Pid ! {Type, Args}.

%%%===================================================================
%%% internal function
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% the loop
%%
%% @spec loop(Requester_pid, Uploader_pid, Peer_mutex_pid, Piece_mutex_pid, File_storage_pid, Peer_id) -> void()
%% @end
%%--------------------------------------------------------------------
loop(Requester_pid, Uploader_pid, Peer_mutex_pid, Piece_mutex_pid, File_storage_pid, Peer_id) ->
    receive
	{keep_alive, []} ->
	    piece_requester:send_event(Requester_pid, keep_alive, ok);
	{bitfield, [Bitfield, Bitfield_len]} ->
	    Bitfield_in_list = make_bitfield_with_index(<<Bitfield:Bitfield_len>>, 0),
	    %% update piece storage
	    mutex:request(Piece_mutex_pid, insert_bitfield, [Peer_id, Bitfield_in_list]),
	    mutex:received(Piece_mutex_pid),
	    
	    %% get interest from file storage
	    {ok, List_of_interest} = mutex:request(File_storage_pid, compare_bitfield, [Bitfield_in_list]),
	    mutex:received(File_storage_pid),
	    
	    %% save in fsm bitfield and interest
	    piece_requester:update_interest(Requester_pid, List_of_interest, add);	   
	{have, [Piece_index]} ->
	    %% update piece storage
	    mutex:request(Piece_mutex_pid, update_bitfield, [Peer_id, Piece_index]),
	    mutex:received(Piece_mutex_pid),

	    %% get interest from file storage
	    Am_interested = mutex:request(File_storage_pid, have, [Piece_index]),
	    mutex:received(File_storage_pid),

	    case Am_interested of
		true -> 
		    piece_requester:update_interest(Requester_pid, [Piece_index], add);
		false -> ok 
	    end;
	{am_choked, [Arg]} ->
	    piece_requester:send_event(Requester_pid, am_choked, Arg);	
	{is_interested, [Arg]} ->
	    piece_uploader:send_event(Uploader_pid, is_interested, Arg);
	{port, [_Listen_port]} ->	    
	    ok;
	{piece, [Index, Begin, Block, Block_len]} ->
	    Is_complete = mutex:request(File_storage_pid, insert_chunk, [Requester_pid, Index, Begin, Block, Block_len]),
	    mutex:received(File_storage_pid),
	    piece_requester:send_event(Requester_pid, piece, {Is_complete, Index});
	{request, [Index, Begin, Length]} ->
	    piece_uploader:send_event(Uploader_pid, request, [Index, Begin, Length]);
	{cancel, [Index, Begin, Length]} ->
	    piece_uploader:send_event(Uploader_pid, cancel, [Index, Begin, Length])
    end,
    loop(Requester_pid, Uploader_pid, Peer_mutex_pid, Piece_mutex_pid, File_storage_pid, Peer_id).

%%--------------------------------------------------------------------
%% @doc
%% take a bitfield in bitstring, return a bitfield (with index) in list 
%% [{0,0}, {0,1}, {0,2}, ... ]
%%
%% @spec make_bitfield_with_index(Bitfield_in_bin, Index) ->
%% @end
%%--------------------------------------------------------------------
make_bitfield_with_index(<<P:1>>, Index) ->
    [{P, Index}];
make_bitfield_with_index(<<P:1, Rest/bits>>, Index) ->
    [{P, Index} | make_bitfield_with_index(Rest, Index+1)].
     
