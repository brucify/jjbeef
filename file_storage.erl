%%%Created by: Fredrik Gustafsson
%%%Date: 16-11-2011
-module(file_storage).
-export([start/3, init/3, get_bitfield/1, insert_piece/3]).

start(Dl_storage_pid, Files, Length) ->
    spawn(?MODULE, init, [Dl_storage_pid, Files, Length]).

init(Dl_storage_pid, Files, Length) ->
    Data = initiate_data(1, Length),
    Table_id = ets:new(torrent, [ordered_set]),
    loop(Dl_storage_pid, Files, Data, Table_id, Length).

initiate_data(Nr, Length) when Nr =< Length ->
    [0|initiate_data(Nr+1, Length)];
initiate_data(_Nr, _Length) ->
    [].

loop(Dl_storage_pid, [H|T], Data, Table_id, Length) ->
    receive
	{bitfield, From} ->
	    Bitfield = generate_bitfield(1, Length, Table_id),
	    From ! {reply, Bitfield},
	    loop(Dl_storage_pid, [H|T], Bitfield, Table_id, Length);
	{insert, From, {Index, Piece}} ->
	    ets:insert(Table_id, {Index, Piece}),
	    {ok , Io} = file:open(H, [write]),
	    ok =  write_to_file(Table_id, 1, Length, Io),
	    ok = file:close(Io),
	    %%mutex:request(Dl_storage_pid, delete, [Index]),
	    From ! {reply, ok},
	    loop(Dl_storage_pid, [H|T], Data, Table_id, Length)
    end.

generate_bitfield(Acc, Length, Table_id) when Acc =< Length ->
    case ets:lookup(Table_id, Acc) of
	[] ->
	    [0|generate_bitfield(Acc+1, Length, Table_id)];
	_  ->
	    [1|generate_bitfield(Acc+1, Length, Table_id)]
    end;

generate_bitfield(_Acc, _Length, _Table_id) ->
    [].

get_bitfield(File_storage_pid) ->
    File_storage_pid ! {bitfield, self()},
    receive
	{reply, Reply} ->
	    Reply
    end.

insert_piece(File_storage_pid, Index, Piece) ->
    File_storage_pid ! {insert, self(), {Index, Piece}},
    receive
	{reply, Reply} ->
	    Reply
    end.

write_to_file(Table_id, Acc, Length, Io) when Acc =< Length ->
    case ets:lookup(Table_id, Acc) of
	[] ->
	    write_to_file(Table_id, Acc+1, Length, Io);
	[{_, Write}]  ->
	    file:write(Io, Write),
	    write_to_file(Table_id, Acc+1, Length, Io)
    end;
write_to_file(_Table_id, _Acc, _Length, _Io) ->
    ok.
