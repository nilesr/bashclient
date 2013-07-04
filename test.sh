# Requires bash 4.0 or later due to switch fallthroughs
function quit {
	test -n "${command[2]}" || echo "QUIT :User closed the connection" >&3
	echo "QUIT :`echo $rawcommand | substring-2`" >&3
	echo Link broken, connection closed.
}
function closeprogram {
	( quit
	sleep 2
	test -s client.pid && kill `cat $CONFDIR/client.pid`
	rm $CONFDIR/client.pid
	cat $CONFDIR/autoconnect | sort | uniq | tee $CONFDIR/autoconnect.temp
	mv $CONFDIR/autoconnect.temp $CONFDIR/autoconnect ) &>/dev/null &
	exit
}
trap "closeprogram  &>/dev/null & exit" SIGINT SIGTERM
function prompt-for {
	read -p "$1" toreturn
	test -n "$toreturn" || toreturn="y"
	toreturn=`echo "$toreturn" | awk '{print tolower($0)}'`
	toreturn=${toreturn:0:1}
	echo $toreturn
}
function substring-2 {
	read toparse; echo $toparse | awk '{print substr($0, index($0,$2))}'; toparse=
}
function substring-3 {
	read toparse; echo $toparse | awk '{print substr($0, index($0,$3))}'; toparse=
}
function substring-4 {
	read toparse; echo $toparse | awk '{print substr($0, index($0,$4))}'; toparse=
}
function connectionloop {
	sleep 1
	echo "NICK $1" >&3
	echo "USER $2 8 * :$3" >&3
	# Server output loop
	while read rawline; do
		line=
		echo "$rawline" | tee -a $CONFDIR/client.log &> /dev/null
		line=( $rawline )
		test -n ${line[0]} || continue # If the server sends an empty line, ignore the line
		test ${line[0]} == "PING" && echo `echo $rawline | sed 's/PING/PONG/1'` >&3 # Ping/pong support
		test ${line[0]} == "ERROR" && quit &2>/dev/null # Die if the server disconnects us
		test -n ${line[1]} || continue # Returns false if there is no second argument. If it returns false, ignore the rest of the loop
		test ${line[1]} == "001" && echo "Connected: `echo $rawline | substring-4`" # Display a message when connected
		test ${line[1]} == "421" && echo "SERVER: `echo $rawline | substring-4`" # Unknown command
		test ${line[1]} == "461" && echo "SERVER: `echo $rawline | substring-4`" # Not enough parameters
		test ${line[1]} == "524" && echo "SERVER: `echo $rawline | substring-4`" # Help section unavailable

		test -n ${line[2]} || continue # Returns false if there is no third argument. If it returns false, ignore the rest of the loop
		test -n ${line[3]} || continue # Returns false if there is no fourth argument. If it returns false, ignore the rest of the loop
		nicktodisplay=`echo ${line[0]} | sed 's/![^!]*$//' `
		privmsgtolog=`echo $rawline | sed -e 's/.*:/:/g' | substring-2`
		test ${line[1]} == "PRIVMSG" && echo ${line[2]}" <$nicktodisplay> $privmsgtolog" # Displays a message
		test ${line[1]} == "JOIN" && echo "$nicktodisplay has joined ${line[2]}"
		test ${line[1]} == "PART" && echo "$nicktodisplay has left ${line[2]}"
		test ${line[1]} == "QUIT" && echo "$nicktodisplay has quit: $privmsgtolog"
		test ${line[1]} == "NICK" && echo "$nicktodisplay is now known as: $privmsgtolog"

	done <&3 &
	echo $! | tee $CONFDIR/client.pid
}

function sendmessage {
	test -n $activewindow || echo "No channel joined" && echo "PRIVMSG $activewindow :$rawcommand" >&3
}
function privmsg {
	test -n ${command[1]} || echo -n "USAGE: /msg <nickname>. "
	test -n ${command[2]} || echo -n "You tried to send a blank message" && echo "PRIVMSG `echo ${command[1]}` :`echo $rawcommand | substring-3`" >&3
	echo ""
}
function joinchannel {
	test -n $2 || chanpass=$2
	test -n $chanpass && echo "JOIN `echo $1`" >&3 || echo "JOIN `echo $1` `echo $chanpass`" >&3
	chanpass=
	activewindow=$1
}
function partchannel {
	topart=
	test -n $1 && topart=$activewindow || topart=$1
	test $topart == $activewindow && activewindow=
	test ${topart:0:1} != "#" && ( echo "USAGE: /part <channel>. You seem to be having problems with the <channel> bit."; return )
	echo "PART `echo $topart` :`echo $rawcommand | substring-3`" >&3
	echo Left channel "$topart".
	topart=
}

function query {
	test -n $1 || echo "USAGE: /query <nickname>" && activewindow=$1
}

function connect {
	test -n $1 || ( echo "Please specify a server address or name"; continue )
	socketaddr=$1
#	test -d $CONFDIR/networks/$1 && ( export socketaddr=`cat "$CONFDIR/networks/$1/addresses" | awk '{print $1}' | head -n 1`; export socketport=`cat "$CONFDIR/networks/$1/addresses" | awk '{print $2}' | head -n 1` )
	test -d $CONFDIR/networks/$1 && vianet="y" || vianet="n"
	test $vianet == "y" && socketaddr=`cat "$CONFDIR/networks/$1/addresses" | awk '{print $1}' | head -n 1`
	test $vianet == "y" && socketport=`cat "$CONFDIR/networks/$1/addresses" | awk '{print $2}' | head -n 1`
	test $vianet == "n" && test -n $2 && socketport=$2
	test -n "$socketport" || socketport="6667"
	echo $socketport
	
	exec 3<>/dev/tcp/$socketaddr/$socketport
	test $vianet == "n" && connectionloop `cat $CONFDIR/default/nickname` `cat $CONFDIR/default/username` `cat $CONFDIR/default/realname`
	test $vianet == "y" && connectionloop `cat $CONFDIR/networks/$1/nickname` `cat $CONFDIR/networks/$1/username` `cat $CONFDIR/networks/$1/realname`
	vianetwork=
	socketport=
	socketaddr=
}
function nick {
	test -n $1 || ( echo $nickname; return )
	echo "NICK :"$1 >&3
	nickname=$1
}
function networks {
	argument=`echo ${command[1]} | awk '{print tolower($0)}'`
	case $argument in
		reconfigure)
			networks-reconfigure ${command[2]}
			;;
		create)
			newnetwork
			;;
		list)
			ls -1 $CONFDIR/networks
			;;
		list-auto)
			cat $CONFDIR/autoconnect
			;;
		change-defaults)
			change-defaults
			;;
		get-defaults)
			get-defaults
			;;
		*)
			echo "USAGE: /networks <option>"
			echo "Possible options"
			echo "----------------"
			echo "reconfigure: 		Change settings on a network"
			echo "create: 		Create a new network"
			echo "list: 			List all networks available"
			echo "list-auto: 		List all networks automatically connected"
			echo "change-defaults:	Change default settings"
			echo "get-defaults:		Get default settings"
			;;
	esac
	argument=
}

function networks-reconfigure {
	test -n "$1" || ( echo -n "Enter the network to modify: "; read netname; export netname )
	test -d $CONFDIR/networks/$netname || ( echo "That network doesn't exist"; continue )
	netaddr=
	echo -n "Either enter the address of the server or enter the address then the port, with a space between: "
	read netaddr
	test -n `echo $netaddr | awk '{print $2}'` || ( echo $netaddr 6667 | tee -a $CONFDIR/networks/$netname/addresses ) && ( echo $netaddr | tee -a $CONFDIR/networks/$netname/addresses ) &>/dev/null
	netaddr=
	autoconnect=
	autoconnect=`prompt-for "Auto-connect to this network on startup? [Y] "`
	test autoconnect == "y" && ( echo $netname | tee -a $CONFDIR/autoconnect ) || ( sed -i 's/$netname//1' <$CONFDIR/autoconnect >$CONFDIR/autoconnect.temp; mv $CONFDIR/autoconnect.temp $CONFDIR/autoconnect )  &>/dev/null
	usedefault=`prompt-for "Use default nickname, etc? [Y] "`
	test usedefault == "y" || ( read -p "What nick do you want to use for this network? " customnick ; echo $customnick | tee $CONFDIR/networks/$netname/nickname &>/dev/null; read -p "What username do you want to use for this network? " customuser; echo $customuser | tee $CONFDIR/networks/$netname/username &>/dev/null; read -p "What realname do you want to use for this network? " customreal; echo $customreal | tee $CONFDIR/networks/$netname/realname &>/dev/null ) && cp $CONFDIR/default/* $CONFDIR/networks/$netname 
}
function askfornewnetwork {
	createnew=
	createnew=`prompt-for "Would you like to setup a new network now? [Y] "`
	test $createnew == "y" && newnetwork || echo "You can always create a new network with /networks create"
}
function newnetwork {
	export createnew=
	createnew=
	read -p "Enter the name for the network: " newnetname
	mkdir -p $CONFDIR/networks/$newnetname || ( echo "Failed to create, you probably can't write to the configuration directory"; exit 1 )
	cp $CONFDIR/default/* $CONFDIR/networks/$newnetname
	newnetaddr=
	echo -n "Either enter the address of the server or enter the address then the port, with a space between: "
	read newnetaddr
	test -n "`echo $newnetaddr | awk '{print $2}'`" || ( echo "$newnetaddr 6667" | tee $CONFDIR/networks/$newnetname/addresses; exit 1 ) && ( echo "$newnetaddr" | tee $CONFDIR/networks/$newnetname/addresses ) &>/dev/null
	newnetaddr=
	newautoconnect=
	newautoconnect=`prompt-for "Auto-connect to this network on startup? [Y] "`
	test $newautoconnect == "y" && ( echo $newnetname | tee -a $CONFDIR/autoconnect || echo "Failed to create, you probably can't write to the configuration directory"; exit 1 ) &>/dev/null
	echo "Continue configuration with /networks reconfigure $newnetname"
	newnetname=
}
function change-defaults {
	read -p "Current default nickname is `cat $CONFDIR/default/nickname`. [`cat $CONFDIR/default/nickname`] " newdefnick
	test -n $newdefnick || newdefnick=`cat $CONFDIR/default/nickname`
	echo $newdefnick > $CONFDIR/default/nickname
	read -p "Current default username is `cat $CONFDIR/default/username`. [`cat $CONFDIR/default/username`] " newdefuser
	test -n $newdefuser || newdefuser=`cat $CONFDIR/default/username`
	echo $newdefuser > $CONFDIR/default/username
	read -p "Current default realname is `cat $CONFDIR/default/realname`. [`cat $CONFDIR/default/realname`] " newdefreal
	test -n $newdefreal || newdefreal=`cat $CONFDIR/default/realname`
	echo $newdefreal > $CONFDIR/default/realname
}
function get-defaults {
	echo "Current default nickname is `cat $CONFDIR/default/nickname`."
	echo "Current default username is `cat $CONFDIR/default/username`."
	echo "Current default realname is `cat $CONFDIR/default/realname`."
}


function help {
	topic=`echo $1 | awk '{print tolower($1)}'`
	case $topic in
		quit) ;&
		q) ;&
		disconnect)
			echo "USAGE: 		/quit"
			echo "DESCRIPTION: 	Disconnects you from your active IRC connection, but keeps the application open"
			echo "ALIASES: 	/q, /disconnect"
			;;
		msg) ;&
		privmsg) ;&
		tell)
			echo "USAGE: 		/msg <nick> <text>"
			echo "DESCRIPTION: 	Sends a private message to <nick> containing <text>"
			echo "ALIASES: 	/privmsg, /tell"
			;;
		join) ;&
		j)
			echo "USAGE: 		/join <channel> [key]"
			echo "DESCRIPTION: 	Joins a specific <channel>, with a [key] word if requierd"
			echo "ALIASES: 	/j"
			;;
		part) ;&
		p)
			echo "USAGE: 		/part <channel>"
			echo "DESCRIPTION: 	Leaves a specific channel"
			echo "ALIASES: 	/p"
			;;
		query)
			echo "USAGE: 		/query <nick>"
			echo "DESCRIPTION: 	Switches the active chatting pane to a private message with that unique <nick>"
			;;
		eval)
			echo "USAGE: 		/eval <shell code>"
			echo "DESCRIPTION: 	Evaluates the <shell code> in a subshell"
			echo "SEE ALSO: 	/eval-global"
			;;
		eval-global)
			echo "USAGE: 		/eval-global <shell code>"
			echo "DESCRIPTION: 	Evaluates the <shell code>"
			echo "SEE ALSO: 	/eval"
			;;
		connect) ;&
		server)
			echo "USAGE: 		/connect <addr | addr port | networkname>"
			echo "DESCRIPTION: 	Connects you to a new active IRC connection, either by address, address and port or network name"
			echo "ALIASES: 	/server"
			;;
		close) ;&
		exit)
			echo "USAGE: 		/close"
			echo "DESCRIPTION: 	Closes the application and all running IRC network sessions"
			echo "ALIASES: 	/exit"
			;;
		nick)
			echo "USAGE: 		/nick <new-nickname>"
			echo "DESCRIPTION: 	Changes your nickname on the server"
			;;
		networks) ;&
		servers)
			echo "USAGE: 		/networks [command] [options]"
			echo "DESCRIPTION: 	Manages networks"
			echo "DESCRIPTION: 	For more information, run /networks or /networks help"
			;;
		quote) ;&
		ircquote)
			echo "USAGE: 		/quote <direct string>"
			echo "DESCRIPTION: 	Sends a <direct string> to the server"
			echo "ALIASES:	/ircquote"
			;;
		help) ;&
		h)
			echo "USAGE: 		/help [topic]"
			echo "DESCRIPTION: 	Checks to see if [topic] has any help available, and if it does, give it to the user"
			echo "ALIASES:	/h"
			;;
		helop)
			echo "USAGE:		/helpop [topic]"
			echo "DESCRIPTION:	Queries your currently connected server for help on a specific topic"
			;;
		*)
			echo "USAGE: 		${command[0]} [topic]"
			echo "COMMANDS:	quit, q, disconnect, msg, privmsg, tell, join, j, part, p, query, eval, eval-global, connect, server, close, exit, nick, networks, servers, quote, ircquote, help, h, helpop"
			;;
	esac
}


# Configuration check
CONFDIR=~/.bashclient
mkdir -p $CONFDIR/networks &>/dev/null
mkdir -p $CONFDIR/default &>/dev/null
test -s $CONFDIR/default/username || ( echo $USER | tee $CONFDIR/default/username ) &>/dev/null
test -s $CONFDIR/default/realname || ( echo $USER | tee $CONFDIR/default/realname ) &>/dev/null
touch $CONFDIR/autoconnect &>/dev/null
test -s $CONFDIR/default/nickname || ( echo -n "Please choose a nickname: " ; read newnickname; echo $newnickname | tee $CONFDIR/default/nickname &>/dev/null; newnickname= )

test "`ls -A $CONFDIR/networks`" || askfornewnetwork

# User input loop
while true; do
	read rawcommand
	test -n "$rawcommand" || continue # If the message is blank, ignore it
	test ${rawcommand:0:1} == "/" || sendmessage  # If the first character in the rawcommand is not a /, send it to the channel, otherwise do nothing
	command=( $rawcommand )
	basecommand=`echo ${command[0]} | awk '{print tolower(substr($1,2)); }'`
	test -n "$basecommand" || continue # If the message was just "/", ignore it
	case $basecommand in
		quit) ;&
		q) ;&
		disconnect)
			quit
			;;
		msg) ;&
		privmsg) ;&
		tell)
			privmsg
			;;
		join) ;&
		j)
			joinchannel ${command[1]} ${command[2]}
			;;
		part) ;&
		p)
			partchannel ${command[1]}
			;;
		query)
			query ${command[1]}
			;;
		eval)
			( eval `echo "$rawcommand" | substring-2` )
			;;
		eval-global)
			eval `echo "$rawcommand" | substring-2`
			;;
		connect) ;&
		server)
			connect ${command[1]} ${command[2]}
			;;
		close) ;&
		exit)
			closeprogram &>/dev/null
			;;
		nick)
			nick ${command[1]}
			;;
		networks) ;&
		servers)
			networks
			;;
		quote) ;&
		ircquote)
			echo `echo $rawcommand | substring-2` >&3
			;;
		help) ;&
		h)
			help ${command[1]}
			;;
		helpop)
			echo "HELP :`echo $rawcommand | substring-2`" >&3
			;;


		*)
			echo $rawcommand >&3 # Incorrect, needs to be changed to exclude the leading /
			;;
	
	esac
	rawcommand=
	command=
	basecommand=
done

