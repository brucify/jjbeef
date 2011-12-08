%%% Created by: Eva-Lisa Kedborn, Jing Liu
%%% Creation date: 2011-11-18
%%% This module module stores piece info

-module(downloading_storage).
-export([start/0, init/0]).

-include_lib("eunit/include/eunit.hrl").

start() ->
    spawn(?MODULE, init, []).

%% get the pid of piece_storage to be able to put the piece back
init() ->
    Tid = ets:new(db, []),
    loop(Tid).

loop(Tid) ->
    receive
	{request, Function, Args, From} ->
	    case Function of
		write_piece ->
		    [PieceIndex, Tuple, Pid] = Args,
		    From ! {reply, write(Tid, PieceIndex, Tuple, Pid)};
		put_back ->
		    [Pid] = Args,
		    From ! {reply, put_back(Tid, Pid)};
		compare_hash ->
		    [FileIndex, FileHash] = Args,
		    From ! {reply,compare_hash(Tid, FileIndex, FileHash)};
		put_back_without_pid ->
		    [FileIndex] = Args,
		    From ! {reply,put_back_without_pid(Tid, FileIndex)}
		%% delete_peer ->
		%%     [PieceIndex, PeerId] = Args,
		%%     Reply = delete_peer(Tid, PieceIndex, PeerId),
		%%     case Reply of
		%% 	true -> From ! {reply, Reply};
		%% 	%_piece -> Piece_storage_pid ! {putback, Reply},
		%% 		  From ! {reply, has_putback}
		%% 		  %delete_piece(Tid, PieceIndex)
		%%     end
	    end,
	    loop(Tid);
	{lookup, Data, From} -> Result = ets:lookup(Tid, Data),
				From ! {reply, Result},
				loop(Tid);
	stop -> ok	
    end.

%% insert new piece that has chosen to be downloaded
write(Tid, PieceIndex, Tuple, Pid) ->
    {PieceIndex, {Hash, Peers}} = Tuple,
    ets:insert(Tid, {Pid, {PieceIndex, {Hash, Peers}}}).

%% if peer has disconnected, remove its peerId from the list storing which
%% peers are downloading the paticular piece.
%% delete_peer(Tid, PieceIndex, PeerId)->
%%     [PieceIndex, {PieceHash, AllPeerList, DownloadingPeerList}] =
%% 	ets:lookup(Tid, PieceIndex),
%%     case DownloadingPeerList of
%% 	[_H|[]]->
%% 	    put_back(Tid, PieceIndex);
%% 	[_H|_T]->
%% 	    ets:insert(Tid, {PieceIndex, {PieceHash, AllPeerList,
%% 				DownloadingPeerList -- [PeerId]}})
%%     end.

%% return the piece to be put back in the piece_storage


put_back(Tid, Pid)->
    case ets:lookup(Tid, Pid) of
	[] ->
	    [];
	[{Pid, {Index, {Hash, Peers}}}] ->
	    {Index, {Hash, Peers}}
    end.

put_back_without_pid(Tid, FileIndex)->
    First_key = ets:first(Tid),
    put_back_new(Tid, FileIndex, First_key).

put_back_new(Tid, FileIndex, Key)->
    [{_Pid, {Index, {Hash, Peers}}}] = ets:lookup(Tid, Key),
    case FileIndex =:= Index of
	true->
	    {Index, {Hash, Peers}};
	false ->
	    Next_key = ets:next(Tid, Key),
	    case Next_key of
		'$end_of_table' ->
		    end_of_table;
		_found ->
		    put_back_new(Tid, FileIndex, Next_key)
	
	    end
     end.

compare_hash(Tid, FileIndex, FileHash)->
    First_key = ets:first(Tid),
    compare_hash(Tid, FileIndex, FileHash, First_key).
compare_hash(Tid, FileIndex, FileHash, Key)->
    [{_Pid, {Index, {Hash, _Peers}}}] = ets:lookup(Tid, Key),
    case FileIndex =:= Index of
	true ->
	    FileHash =:= Hash;
	false->
	    Next_key = ets:next(Tid, Key),
	    case Next_key of
		'$end_of_table' ->
		    end_of_table;
		_found ->
		    compare_hash(Tid, FileIndex, FileHash, Next_key)
	
	    end
     end.

	    
