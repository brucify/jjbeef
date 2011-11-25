%%% Created by: Eva-Lisa Kedborn, Jing Liu
%%%Rarest piece algorithm: Fredrik Gustafsson
%%% Creation date: 2011-11-16

-module(piece_storage).
-export([start/1, init/1, initiate_table/1]).

-include_lib("eunit/include/eunit.hrl").

start(List) ->
    spawn(?MODULE, init, [List]).

init(List) ->
    initiate_table(List),
%    initiate_rarest(length(List)),
    loop(piece_table, length(List)).

%initiate_rarest(Max) ->
%    ets:new(rarest_table, [named_table, ordered_set]),
%    initiate_rarest(rarest_table, 1, Max).
%initiate_rarest(rarest_table, Acc, Max) when Acc =< Max ->
%    ets:insert(rarest_table, {Acc, 0}),
%    initiate_rarest(rarest_table, Acc+1, Max);
%initiate_rarest(rarest_table, _Acc, _Max) ->
%    ok.

initiate_table(List) ->
    ets:new(piece_table,[named_table, ordered_set]),
    initiate_table(piece_table, List, 0).
initiate_table(piece_table, [H|T], Index) ->
    ets:insert(piece_table, {Index, {H, []}}),
    initiate_table(piece_table, T, Index + 1);
initiate_table(piece_table, [], _Index) ->
    piece_table.

loop(piece_table, Nr_of_pieces)->
    receive
	{request, Function, Args, From} ->
	    case Function of
		insert_bitfield ->
		    io:format("This is Args ~w~n", [Args]),
		    [PeerId, [H|T]] = Args,
		    Reply = insert_bitfield(piece_table, PeerId, [H|T]);
		read_piece ->
		    [Index] = Args,
		    Reply = read_piece(piece_table, Index);
		update_bitfield ->
		    [PeerId, PieceIndex] = Args,
		    Reply = update_bitfield(piece_table, PeerId, PieceIndex);
%		    Reply = update_rarest(Updated, rarest_table, PieceIndex);
		get_piece_hash ->
		    [Index] = Args,
		    Reply = get_piece_hash(piece_table, Index);
		delete_peer ->
		    [PeerId] = Args,
		    Reply = delete_peer(piece_table,PeerId);
%		get_rarest ->
%		    Reply = get_rarest(rarest_table, Nr_of_pieces);
		delete_piece ->
		    [Index] = Args,
		    Reply = delete_piece(piece_table, Index);
		putback ->
		    [Piece] = Args,
		    Reply = putback(piece_table, Piece)
	    end,
	    From ! {reply, Reply},
	    loop(piece_table, Nr_of_pieces);
	stop -> ok
    end.

delete_piece(piece_table, Index) ->
    ets:delete(piece_table, Index).

%%Updates the rarest_table with the new have message
%update_rarest(Updated, rarest_table, Index) ->
%    case Updated of
%	false ->
%	    false;
%	_ ->
%	    [{Index, Number}] = ets:lookup(rarest_table, Index),
%	    ets:insert(rarest_table, {Index, Number+1})
%    end.
%get_rarest(rarest_table, Max) ->
%    get_rarest(rarest_table, 1, Max, undefined, undefined).
%get_rarest(rarest_table, Acc, Max, Rarest, Index) when Acc =< Max ->
%    [{Acc, Number}] = ets:lookup(rarest_table, Acc),
%    case Rarest of
%	undefined ->
%	    case Number of
%		0 ->
%		    get_rarest(rarest_table, Acc+1, Max, undefined, undefined);
%		Any_number  -> 
%		    get_rarest(rarest_table, Acc+1, Max, Any_number, Acc)
%	    end;
%	Rarest_nr_so_far  ->
%	    case Number < Rarest_nr_so_far of
%		true ->
%		    get_rarest(rarest_table, Acc+1, Max, Number, Acc);
%		_  ->
%		    get_rarest(rarest_table, Acc+1, Max, Rarest_nr_so_far, Index%)
%	    end
%    end;
%
%get_rarest(rarest_table, _Acc, _Max, _Number, Index) ->
%    Index.

%% insert a new peer that has one of the pieces we want into the table
insert_bitfield(piece_table, PeerId, [H|T]) ->
    Has = [X || {1, X} <- [H|T]],
    insert_to_table(piece_table, Has, PeerId).

%% inner function of insert_bitfield
insert_to_table(piece_table, [Has|T], PeerId) ->
    [{Index, {Hash, Peers}}] = ets:lookup(piece_table, Has),
     ets:insert(piece_table, {Index, {Hash, [PeerId|Peers]}}),
     insert_to_table(piece_table, T, PeerId);
insert_to_table(piece_table, [], _PeerId) ->
     has_inserted.

%% update piece storage when a have message is received
update_bitfield(piece_table, PeerId, PieceIndex) ->
    [{PieceIndex, {Hash, Peers}}] = ets:lookup(piece_table, PieceIndex),
    ets:insert(piece_table, {PieceIndex, {Hash, [PeerId|Peers]}}).
    
%% read the list of peers that has a certain piece by 
%% providing the piece index. 
read_piece(piece_table, Index) ->
    [Content] = ets:lookup(piece_table, Index),
    Content.

%% get the piecehash of a piece by providing the piece index
get_piece_hash(piece_table, Index) ->
    [{Index, {Piecehash, _Peers}}] = ets:lookup(piece_table, Index),
    Piecehash.

delete_peer(piece_table,PeerId)->
    delete_peer(piece_table,PeerId,0).
delete_peer(piece_table,PeerId,Index) ->
    io:format("last: ~w~n",[ets:last(piece_table)]),
    case Index > ets:last(piece_table) of
	true ->
	    has_deleted;
	false ->
	    [{Index,{Piecehash,Peers}}] = ets:lookup(piece_table,Index),
	     ets:insert(piece_table, {Index, {Piecehash, Peers--[PeerId]}}),
	    delete_peer(piece_table,PeerId,Index+1)
    end.

%% insert the piece returned from downloading_storage
putback(piece_table, Piece)->
    {PieceIndex, {Piecehash, AllPeersList}} = Piece,
    ets:insert(piece_table, {PieceIndex, {Piecehash, AllPeersList}}).



%%%%%%%% TEST CASES %%%%%%%%

setup() ->
    Pid = piece_storage:start([hash0, hash1, hash2]),
    register(?MODULE, Pid),
    Pid.

cleanup(Pid) ->
    Pid ! stop.

%% Id:                 1 
%% Title:              Initiate piece table
%% Purpose:            Ensure correct creation of table and first insertion of 
%%                     pieces and their hashes
%% Prerequisites:      None
%% Expected result:    The table has been created and pieces correctly inserted
%% Pass/Fail criteria: When run response is "All tests passed"/When run 
%%                     response is error

initiate_table_test_() ->
    {spawn,
     {setup,
      fun setup/0,
      fun cleanup/1,
      fun() ->
	      [?assertMatch([], ets:lookup(piece_table, 3)),
	       ?assertMatch([{0, {hash0, []}}], ets:lookup(piece_table, 0))]
      end
     }
    }. 

%% Id:                 2 
%% Title:              Insert bitfield info
%% Purpose:            Ensure correct insert of bitfield, peer and piece info
%% Prerequisites:      Existing piece table with pieces
%% Expected result:    Info in bitfield has been inserted
%% Pass/Fail criteria: When run response is "All tests passed"/When run 
%%                     response is error 

insert_bitfield_test_() ->  
    {spawn,
     {setup,
      fun setup/0,
      fun cleanup/1,
      fun() ->
	      ?MODULE ! {request, insert_bitfield, 
			 [peer1, [{1,0}, {1,1}, {0,2}]], self()},
	      receive {reply, _Reply} -> ok end,

	      [?assertMatch([{0, {hash0, [peer1]}}], 
			    ets:lookup(piece_table, 0)),
	       ?assertMatch([{1, {hash1, [peer1]}}], 
			    ets:lookup(piece_table, 1)),
	       ?assertMatch([{2, {hash2, []}}], ets:lookup(piece_table, 2)),
	       ?assertError(badarg, ets:lookup(piece2_table, 2))]
      end
     }
    }.

%% Id:                 3 
%% Title:              Update bitfield info
%% Purpose:            Ensure correct update of bitfield 
%% Prerequisites:      Existing table with pieces and initial bitfield info
%% Expected result:    Info in bitfield has been updated
%% Pass/Fail criteria: When run response is "All tests passed"/When run 
%%                     response is error

update_bitfield_test_() ->
    {spawn,
     {setup,
      fun setup/0,
      fun cleanup/1,
      fun() ->
	      ?MODULE ! {request, insert_bitfield, 
			 [peer1, [{1,0}, {1,1}, {0,2}]], self()},
	      receive {reply, _Reply} -> ok end,

	      ?MODULE ! {request, update_bitfield, [peer2, 2], self()},
	      receive {reply, _} -> ok end,

	      ?MODULE ! {request, update_bitfield, [peer2, 0], self()},
	      receive {reply, _} -> ok end,

	      [?assertMatch([{2, {hash2, [peer2]}}], 
			     ets:lookup(piece_table, 2)),
	       ?assertMatch([{0, {hash0, [peer2, peer1]}}], 
			    ets:lookup(piece_table, 0))]
      end
     }
    }.

%% Id:                 4 
%% Title:              Get piece info
%% Purpose:            Ensure correct extraction of piece info 
%% Prerequisites:      Existing table with pieces and bitfield info
%% Expected result:    All stored values of the requested piece is returned
%% Pass/Fail criteria: When run response is "All tests passed"/When run 
%%                     response is error

read_piece_test_() ->
    {spawn,
     {setup,
      fun setup/0,
      fun cleanup/1,
      fun() ->
	      ?MODULE ! {request, insert_bitfield, 
			 [peer1, [{1,0}, {1,1}, {0,2}]], self()},
	      receive {reply, _Reply} -> ok end,

	      ?MODULE ! {request, read_piece, [1], self()},
	      receive {reply, Reply} -> ok end,

	      [?assertEqual(Reply, {1, {hash1, [peer1]}}),
	       ?assertError(function_clause, read_piece(piece2_table, 1))]
      end
     }
    }.

%% Id:                 5 
%% Title:              Get piece hash
%% Purpose:            Ensure correct extraction of piece hash 
%% Prerequisites:      Existing table with pieces and their hash
%% Expected result:    The hash of the requested piece is returned
%% Pass/Fail criteria: When run response is "All tests passed"/When run 
%%                     response is error

get_piece_hash_test_() ->
    {spawn,
     {setup,
      fun setup/0,
      fun cleanup/1,
      fun() ->
	      ?MODULE ! {request, insert_bitfield, 
			 [peer1, [{1,0}, {1,1}, {0,2}]], self()},
	      receive {reply, _Reply} -> ok end,

	      ?MODULE ! {request, get_piece_hash, [1], self()},
	      receive {reply, Reply} -> ok end,

	      [?assertEqual(Reply, hash1),
	       ?assertError(function_clause, get_piece_hash(piece2_table, 1))]
      end
     }
    }.

%% Id:                 6 
%% Title:              Put back piece
%% Purpose:            Ensure correct insertion of piece and its info 
%% Prerequisites:      Existing piece table
%% Expected result:    The piece is correctly inserted with all its info
%% Pass/Fail criteria: When run response is "All tests passed"/When run 
%%                     response is error

putback_test_() ->
    {spawn,
     {setup,
      fun setup/0,
      fun cleanup/1,
      fun() ->
	      ?MODULE ! {request, insert_bitfield, 
			 [peer1, [{1,0}, {1,1}, {0,2}]], self()},
	      receive {reply, _} -> ok end,

	      ?MODULE ! {request, putback, [{3, {hash3, [peer3]}}], self()},
	      receive {reply, _} -> ok end,
   
	      [?assertMatch([{3, {hash3, [peer3]}}], 
			     ets:lookup(piece_table, 3)),
	       ?assertMatch([{2, {hash2, []}}], ets:lookup(piece_table, 2))]
      end
     }
    }.

%% Id:                 7 
%% Title:              Delete piece
%% Purpose:            Be able to delete a piece when it has been downloaded 
%% Prerequisites:      Existing piece table, with pieces
%% Expected result:    The piece is removed with all its info
%% Pass/Fail criteria: When run response is "All tests passed"/When run 
%%                     response is error

delete_piece_test_() ->
    {spawn,
     {setup,
      fun setup/0,
      fun cleanup/1,
      fun() ->
	      ?MODULE ! {request, insert_bitfield, 
			 [peer1, [{1,0}, {1,1}, {0,2}]], self()},
	      receive {reply, _} -> ok end,

	      ?MODULE ! {request, delete_piece, [1], self()},
	      receive {reply, _} -> ok end,
   
	      [?assertMatch([], ets:lookup(piece_table, 1)),
	       ?assertMatch([{2, {hash2, []}}], ets:lookup(piece_table, 2))]
      end
     }
    }.

%% Id:                 8 
%% Title:              Delete peer
%% Purpose:            Be able to delete a peer that has disconnected 
%% Prerequisites:      Existing piece table with pieces
%% Expected result:    The peer is correctly removed from all pieces
%% Pass/Fail criteria: When run response is "All tests passed"/When run 
%%                     response is error

delete_peer_test_() ->
    {spawn,
     {setup,
      fun setup/0,
      fun cleanup/1,
      fun() ->
	      ?MODULE ! {request, insert_bitfield, 
			 [peer1, [{1,0}, {1,1}, {0,2}]], self()},
	      receive {reply, _} -> ok end,

	      ?MODULE ! {request, insert_bitfield, 
			 [peer2, [{0,0}, {1,1}, {1,2}]], self()},
	      receive {reply, _} -> ok end,

	      ?MODULE ! {request, delete_peer, [peer1], self()},
	      receive {reply, _} -> ok end,
   
	      [?assertMatch([{0, {hash0, []}}], ets:lookup(piece_table, 0)),
	       ?assertMatch([{1, {hash1, [peer2]}}], 
			    ets:lookup(piece_table, 1)),
	       ?assertMatch([{2, {hash2, [peer2]}}], 
			    ets:lookup(piece_table, 2))]
      end
     }
    }.


		     
    
	      
	      

	      
	      
	      

