-module(mod_flash_crossdomain).
-author('Yurii Rashkovskii').
-vsn('0.1').

-behavior(gen_mod).

-compile(export_all).

-include("ejabberd.hrl").

start(Host, _Opts) ->
	?INFO_MSG("mod_flash_crossdomain starting", []),
	Holder = spawn(?MODULE, socket_holder, []),
	put(socket_holder_pid, Holder),
	spawn(?MODULE, listen_843, [Host, Holder]),
    ok.

stop(_Host) ->
	?INFO_MSG("mod_flash_crossdomain stopping", []),
	get(socket_holder_pid) ! close_all,
    ok.

%%%%%%
	
socket_holder(Sockets) ->
	receive
		{add, Socket} ->
			socket_holder([Socket|Sockets]);
		close_all ->
			lists:foreach(fun (S) -> gen_tcp:close(S) end, Sockets),
			socket_holder()
	end.

socket_holder() ->
	socket_holder([]).
	
			
listen_843(Host, Holder) ->
	case gen_tcp:listen(843, [list, {packet, 0},  {active, false}]) of
		{ok, LSock} ->
			Holder ! { add, LSock },
	    	loop_843(Host, LSock);
		Error ->
		?ERROR_MSG("Error binding port 843",[Error]),
    	stop
 	end.

loop_843(Host, Listen) ->
    case gen_tcp:accept(Listen) of
		{ok, S} ->
		    spawn(?MODULE, adobe_flash_connection_handler, [Host,S]),
		    loop_843(Host, Listen);
		_ ->
		    loop_843(Host, Listen)
	end.	

adobe_flash_connection_handler(Host, Socket) ->
	case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
			% TODO we actually need to check what Data is
			case file:read_file(gen_mod:get_module_opt(Host, ?MODULE, policy_file, "/etc/crossdomain.xml")) of % FIX this stupid default
			{ok, Policy} ->
				gen_tcp:send(Socket, binary_to_list(Policy));
			Error ->
				?ERROR_MSG("Can't open policy file",[Error])
			end,
			gen_tcp:close(Socket);
        {error, closed} ->
			% FIXME: do something different here
            error
    end.
