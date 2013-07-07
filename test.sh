# Niles Rogoff <nilesrogoff@gmail.com>
#
# Requires bash 4.0 or later due to switch fallthroughs
function quit {
	test -n "$1" || echo "QUIT :User closed the connection" >&3
	echo "QUIT :`echo $rawcommand | substring-2`" >&3
}
function closeprogram {
	( quit "nonzero string" &>/dev/null
	sleep 2
	test -s client.pid && kill `cat $CONFDIR/client.pid`
	rm $CONFDIR/client.pid
	cat $CONFDIR/autoconnect | sort | uniq | tee $CONFDIR/autoconnect.temp
	mv $CONFDIR/autoconnect.temp $CONFDIR/autoconnect ) &>/dev/null &
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
function substring-5 {
	read toparse; echo $toparse | awk '{print substr($0, index($0,$5))}'; toparse=
}
function ctcp {
	ctcpall=`echo $1 | sed 's/[^0-9a-zA-Z\ ]//g'`
	ctcpcommand=`echo $ctcpall | awk '{print toupper($1)}'`
	test "$ctcpcommand" == "ACTION" && ( echo "${line[2]} * $nicktodisplay `echo $rawline | substring-5`"; exit 0 ) && return
	echo "Recieved CTCP $ctcpall from $nicktodisplay"
	case ctcpcommand in
		VERSION)
			echo "PRIVMSG $nicktodisplay :`echo -n $soh`VERSION BashClient:Alpha:`uname -v``echo -n $soh`" >&3
			;;
		SOURCE)
			echo "PRIVMSG $nicktodisplay :`echo -n $soh`SOURCE niles.mooo.com:/:test.sh`echo -n $soh`" >&3
			echo "PRIVMSG $nicktodisplay :`echo -n $soh`SOURCE`echo -n $soh`" >&3
	esac
	ctcpcommand=
	ctcpall=
}
function connectionloop {
	sleep 1
	echo "NICK $1" >&3
	echo "USER $2 8 * :$3" >&3
	# Server output loop
	while read rawline; do
		line=
		#rawline=`echo $rawline | sed 's/*//g'`
		echo "$rawline" | tee -a $CONFDIR/client.log &> /dev/null
		line=( $rawline )
		test -n "${line[0]}" || continue # If the server sends an empty line, ignore the line
		test ${line[0]} == "PING" && echo `echo $rawline | sed 's/PING/PONG/1'` >&3 # Ping/pong support
		test ${line[0]} == "ERROR" && ( quit &2>/dev/null; echo Server connection closed. ) # Die if the server disconnects us
		test -n "${line[1]}" || continue # Returns false if there is no second argument. If it returns false, ignore the rest of the loop
		test ${line[1]} == "001" && ( echo "Connected: `echo $rawline | substring-4 | cut -c 2-`"; test -n "$4" && has-connected "$4" ) # Display a message when connected
		test ${line[1]} == "005" && ( test ${line[2]} == ":Try" && ( quit; connect ${line[4]} ${line[6]} ) ) # RFC 2812 compliance. Server redirect (RPL_BOUNCE).
		test ${line[1]} == "010" && ( quit; connect ${line[2]} ${line[3]} ) # Server redirect (Incidentally also RPL_BOUNCE. Also known as RPL_REDIR).
		test ${line[1]} == "043" && echo "That nick is already in use. Your nickname has been changed. SERVER: `echo $rawline | substring-3 | cut -c 2-`" # RPL_SAVENICK
		test ${line[1]} == "200" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Trace info (RPL_TRACELINK)
		test ${line[1]} == "201" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Trace info (RPL_TRACECONNECTING)
		test ${line[1]} == "202" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Trace info (RPL_TRACEHANDSHAKE)
		test ${line[1]} == "203" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Trace info (RPL_TRACEUNKNOWN)
		test ${line[1]} == "204" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Trace info (RPL_TRACEOPERATOR)
		test ${line[1]} == "205" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Trace info (RPL_TRACEUSER)
		test ${line[1]} == "206" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Trace info (RPL_TRACESERVER)
		test ${line[1]} == "208" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Trace info (RPL_TRACENEWTYPE)
		test ${line[1]} == "209" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 2182 compliance. Trace info (RPL_TRACECLASS)
		test ${line[1]} == "210" && ( echo "TRACE/SERVER: `echo $rawline | substring-4`"; echo "WARNING: This may be incorrect. Servers running aircd use RPL_STATS instead of RPL_TRACERECONNECT, against RFC 2182." ) # RFC 2182 compliance. Trace info (RPL_TRACERECONNECT)
		test ${line[1]} == "211" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSLINKINFO)
		test ${line[1]} == "212" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSCOMMANDS)
		test ${line[1]} == "213" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSCLINE)
		test ${line[1]} == "214" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info. Depreciated (RPL_STATSNLINE, also known as RPL_STATSOLDNLINE)
		test ${line[1]} == "215" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSILINE)
		test ${line[1]} == "216" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSKLINE)
		test ${line[1]} == "217" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSPLINE, also RPL_STATSPLINE in ircu)
		test ${line[1]} == "218" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSYLINE)
		test ${line[1]} == "219" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_ENDOFSTATS)
		test ${line[1]} == "220" && echo "STATS/SERVER: `echo $rawline | substring-4`" # Hybrid only. Stats info (RPL_STATSPLINE)
		test ${line[1]} == "221" && echo "Your usermodes: `echo $rawline | substring-4`" # RFC 1459 compliance. Replies with your usermodes. (RPL_UMODEIS)
		test ${line[1]} == "222" && echo "STATS/SERVER: `echo $rawline | substring-4`" # Stats crap
		test ${line[1]} == "223" && echo "STATS/SERVER: `echo $rawline | substring-4`" # More stats crap
		test ${line[1]} == "224" && echo "STATS/SERVER: `echo $rawline | substring-4`" # Even more stats crap
		test ${line[1]} == "225" && echo "STATS/SERVER: `echo $rawline | substring-4`" # Exorbitant amounts of even more stats crap
		test ${line[1]} == "226" && echo "STATS/SERVER: `echo $rawline | substring-4`" # STATS
		test ${line[1]} == "227" && echo "STATS/SERVER: `echo $rawline | substring-4`" # TOTALLY NOT STATS
		test ${line[1]} == "228" && echo "STATS/SERVER: `echo $rawline | substring-4`" # JUST KIDDING, IT'S MORE STATS. None of this crap is referenced anywhere in the RFC by the way.
		test ${line[1]} == "231" && echo "SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. (RPL_SERVICEINFO)
		test ${line[1]} == "232" && ( echo "SERVER: `echo $rawline | substring-4`"; echo "WARNING: On servers running unreal, this may also be the rules, as unreal ignores RFC 1459 and uses RPL_RULES instead of RPL_ENDOFSERVICES" ) # RFC 1459 compliance. (RPL_ENDOFSERVICES)
		test ${line[1]} == "233" && echo "SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. (RPL_SERVICE)
		test ${line[1]} == "234" && echo "SERVER: `echo $rawline | substring-4`" # RFC 2812 compliance. (RPL_SERVLIST)
		test ${line[1]} == "235" && echo "SERVER: `echo $rawline | substring-4`" # RFC 2812 compliance. (RPL_SERVLISTEND)
		test ${line[1]} == "236" && echo "STATS/SERVER: `echo $rawline | substring-4`" # ircu only. (RPL_STATSVERBOSE)
		test ${line[1]} == "237" && echo "STATS/SERVER: `echo $rawline | substring-4`" # ircu only. (RPL_STATSENGINE)
		test ${line[1]} == "238" && echo "STATS/SERVER: `echo $rawline | substring-4`" # ircu only. (RPL_STATSFLINE)
		test ${line[1]} == "239" && echo "STATS/SERVER: `echo $rawline | substring-4`" # IRCnet only. (RPL_STATSIAUTH)
		test ${line[1]} == "240" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 2812 says this should be RPL_STATSVLINE, AustHex says fuck your shit RFC 2812, I'm using RPL_STATSXLINE
		test ${line[1]} == "241" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSLLINE)
		test ${line[1]} == "242" && echo "STATS/SERVER: `echo $rawline | substring-4 | cut -c 2-`" # RFC 1459 compliance. Stats info (RPL_STATSUPTIME)
		test ${line[1]} == "243" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSOLINE)
		test ${line[1]} == "244" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Stats info (RPL_STATSHLINE)
		test ${line[1]} == "245" && echo "STATS/SERVER: `echo $rawline | substring-4`" # Bahamut, IRCnet, and Hybrid only. Stats info (RPL_STATSHLINE)
		test ${line[1]} == "246" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 2812 compliance. Stats info (RPL_STATSPING). ircu uses this as RPL_STATSTLINE and Hybrid uses this as RPL_STATSULINE
		test ${line[1]} == "247" && echo "STATS/SERVER: `echo $rawline | substring-4`" # I don't feel like dealing with this shit
		test ${line[1]} == "248" && echo "STATS/SERVER: `echo $rawline | substring-4`" # I don't feel like dealing with this shit
		test ${line[1]} == "249" && echo "STATS/SERVER: `echo $rawline | substring-4`" # I don't feel like dealing with this shit
		test ${line[1]} == "250" && echo "STATS/SERVER: `echo $rawline | substring-4`" # RFC 2812 compliance. Stats info (RPL_STATSDLINE) ircu and Unreal use RPL_STATSCONN
		test ${line[1]} == "251" && echo "LUSERS/SERVER: `echo $rawline | substring-4 | cut -c 2-`" # RFC 1459 compliance. List users info (RPL_LUSERCLIENT)
		test ${line[1]} == "252" && echo "There are ${line[2]} operators online. LUSERS/SERVER: `echo $rawline | substring-3 | cut -c 2-`" # RFC 1459 compliance. List users info (RPL_LUSEROP)
		test ${line[1]} == "253" && echo "There are ${line[2]} unknown or unregistered connections. LUSERS/SERVER: `echo $rawline | substring-3 | cut -c 2-`" # RFC 1459 compliance. List users info (RPL_LUSERUNKNOWN)
		test ${line[1]} == "254" && echo "There are ${line[2]} channels formed. LUSERS/SERVER: `echo $rawline | substring-3 | cut -c 2-`" # RFC 1459 compliance. List users info (RPL_LUSERCHANNELS)
		test ${line[1]} == "255" && echo "LUSERS/SERVER: `echo $rawline | substring-4 | cut -c 2-`" # RFC 1459 compliance. List users info (RPL_LUSERME)
		test ${line[1]} == "256" && echo "ADMIN/SERVER: `echo ${line[3]}`: `echo $rawline | substring-3 | cut -c 2-`" # RFC 1459 compliance. Admin info (RPL_ADMINME)
		test ${line[1]} == "257" && echo "ADMIN/SERVER: location: `echo $rawline | substring-4 | cut -c 2-`" # RFC 1459 compliance. Admin info (RPL_ADMINLOC1)
		test ${line[1]} == "258" && echo "ADMIN/SERVER: location: `echo $rawline | substring-4 | cut -c 2-`" # RFC 1459 compliance. Admin info (RPL_ADMINLOC2)
		test ${line[1]} == "259" && echo "ADMIN/SERVER: email address: `echo $rawline | substring-4 | cut -c 2-`" # RFC 1459 compliance. Admin (RPL_ADMINEMAIL)
		test ${line[1]} == "261" && echo "TRACE/SERVER: `echo $rawline | substring-4`" # RFC 1459 compliance. Trace info (RPL_TRACELOG)
		test ${line[1]} == "262" && echo "TRACE/SERVER: `echo $rawline | substring-4 | sed 's/://g'`" # RFC 2812 compliance. Trace info (RPL_TRACEEND)
		test ${line[1]} == "263" && echo "Server dropped the command without executing it. ERROR/SERVER: `echo $rawline | substring-2`" # RFC 2812 compliance. When a server drops a command without processing it, it MUST use this reply. (RPL_TRYAGAIN aka RPL_LOAD_THROTTLED or RPL_LOAD2HI)
#		test ${line[1]} == "265" && echo "SERVER: `echo $rawline | substring-3

		test ${line[1]} == "307" && echo "WHOIS/SERVER: `echo $rawline | substring-4`" # WHOIS info
		test ${line[1]} == "310" && echo "WHOIS/SERVER: `echo $rawline | substring-4`" # WHOIS info
		test ${line[1]} == "311" && echo "WHOIS/SERVER: `echo $rawline | substring-4`" # WHOIS info
		test ${line[1]} == "312" && echo "WHOIS/SERVER: `echo $rawline | substring-4`" # WHOIS info
		test ${line[1]} == "317" && echo "WHOIS/SERVER: `echo $rawline | substring-4`" # WHOIS info
		test ${line[1]} == "318" && echo "WHOIS/SERVER: `echo $rawline | substring-4`" # WHOIS info
		test ${line[1]} == "338" && echo "WHOIS/SERVER: `echo $rawline | substring-4`" # WHOIS info
		test ${line[1]} == "421" && echo "SERVER: `echo $rawline | substring-4`" # Unable to send to channel

		test ${line[1]} == "433" && echo "Nickname already in use. ERROR/SERVER: `echo $rawline | substring-4`" # Nick already in use
		test ${line[1]} == "461" && echo "SERVER: `echo $rawline | substring-4`" # Not enough parameters
		test ${line[1]} == "524" && echo "SERVER: `echo $rawline | substring-4`" # Help section unavailable
		test ${line[1]} == "713" && echo "SERVER: `echo $rawline | substring-4`" # Cannot knock, channel is open


		test -n "${line[2]}" || continue # Returns false if there is no third argument. If it returns false, ignore the rest of the loop
		test -n "${line[3]}" || continue # Returns false if there is no fourth argument. If it returns false, ignore the rest of the loop
		nicktodisplay=`echo ${line[0]} | sed 's/![^!]*$//' | cut -c 2-`
		privmsgtolog=`echo $rawline | substring-4`
		echo "${line[3]}" | grep -F $'\001' && ( ctcp "`echo $rawline | substring-4`"; exit 0 ) && continue
		test ${line[1]} == "PRIVMSG" && echo ${line[2]}" <$nicktodisplay> $privmsgtolog" # Displays a message
		test ${line[1]} == "NOTICE" && echo ${line[2]}" <notice/$nicktodisplay> $privmsgtolog" # Displays a notice
		test ${line[1]} == "JOIN" && echo "$nicktodisplay has joined `echo ${line[2]} | cut -c 2-`"
		test ${line[1]} == "PART" && echo "$nicktodisplay has left `echo ${line[2]} | cut -c 2-`"
		test ${line[1]} == "QUIT" && echo "$nicktodisplay has quit: `echo $rawline | substring-3 | cut -c 2-`"
		test ${line[1]} == "NICK" && echo "$nicktodisplay is now known as: `echo ${line[2]} | cut -c 2-`"

	done <&3 &
	echo $! | tee $CONFDIR/client.pid
}
function has-connected {
	#cat $CONFDIR/networks/$1/autorun >&3
	while read runtoexec; do
		test "${runtoexec:0:1}" == "#" || echo "$runtoexec" >&3	
	done < $CONFDIR/networks/$1/autorun
	test -n "`cat $CONFDIR/networks/$1/nickserv`" && echo "PRIVMSG NickServ :identify `cat $CONFDIR/networks/$1/nickserv`" >&3
	for channeltojoin in `cat $CONFDIR/networks/$1/autojoin`; do
		joinchannel $channeltojoin
		channeltojoin=
	done
}

function sendmessage {
	test -n "$activewindow" || echo "No channel joined" && echo "PRIVMSG $activewindow :$rawcommand" >&3
}
function privmsg {
	test -n "${command[1]}" || echo -n "USAGE: /msg <nickname>. "
	test -n "${command[2]}" || echo -n "You tried to send a blank message" && echo "PRIVMSG `echo ${command[1]}` :`echo $rawcommand | substring-3`" >&3
}
function joinchannel {
	test -n "$2" || chanpass=$2
	test -n "$chanpass" && echo "JOIN `echo $1`" >&3 || echo "JOIN `echo $1` `echo $chanpass`" >&3
	chanpass=
	activewindow=$1
}
function partchannel {
	topart=
	test -n "$1" && topart=$activewindow || topart=$1
	test $topart == $activewindow && activewindow=
	test ${topart:0:1} != "#" && ( echo "USAGE: /part <channel>. You seem to be having problems with the <channel> bit."; exit 0 ) && continue
	echo "PART `echo $topart` :`echo $rawcommand | substring-3`" >&3
	echo Left channel "$topart".
	topart=
}

function query {
	test -n "$1" || echo "USAGE: /query <nickname>" && activewindow=$1
}

function connect {
	test -n "$1" || ( echo "Please specify a server address or name"; exit 1 ) || return # If the first argument is null exit
	socketaddr=$1
#	test -d $CONFDIR/networks/$1 && ( export socketaddr=`cat "$CONFDIR/networks/$1/addresses" | awk '{print $1}' | head -n 1`; export socketport=`cat "$CONFDIR/networks/$1/addresses" | awk '{print $2}' | head -n 1` )
	test -d $CONFDIR/networks/$1 && vianet="y" || vianet="n"
	test $vianet == "y" && socketaddr=`cat "$CONFDIR/networks/$1/addresses" | awk '{print $1}' | head -n 1`
	test $vianet == "y" && socketport=`cat "$CONFDIR/networks/$1/addresses" | awk '{print $2}' | head -n 1`
	test $vianet == "n" && test -n "$2" && socketport=$2
	test -n "$socketport" || socketport="6667"
	echo $socketport
	
	exec 3<>/dev/tcp/$socketaddr/$socketport
	test $vianet == "n" && connectionloop `cat $CONFDIR/default/nickname` `cat $CONFDIR/default/username` `cat $CONFDIR/default/realname`
	test $vianet == "y" && connectionloop `cat $CONFDIR/networks/$1/nickname` `cat $CONFDIR/networks/$1/username` `cat $CONFDIR/networks/$1/realname` "$1"
	vianetwork=
	socketport=
	socketaddr=
}
function nick {
	test -n "$1" || ( echo $nickname; return )
	echo "NICK :"$1 >&3
	nickname=$1
}
function networks {
	argument=`echo ${command[1]} | awk '{print tolower($0)}'`
	case $argument in
		reconfigure)
			networks-reconfigure ${command[2]}
			;;
		reconfigure-auto)
			networks-reconfigure-auto ${command[2]}
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
			echo "reconfigure-auto:	Change settings about automatically run commands, automatically joined channels and nickserv password"
			echo "create: 		Create a new network"
			echo "list: 			List all networks available"
			echo "list-auto: 		List all networks automatically connected"
			echo "change-defaults:	Change default settings"
			echo "get-defaults:		Get default settings"
			;;
	esac
	argument=
}
function networks-reconfigure-auto {
	test -n "$1" || ( echo -n "Enter the network to modify: "; read netname; export netname; exit 1 ) && netname=$1
	test -d "$CONFDIR/networks/$netname" || ( echo "That network doesn't exist"; exit 1 ) || return
	usenickserv=`prompt-for "Authenticate with NickServ? [Y] "`
	test $usenickserv == "y" && ( read -s -p "Password? " nickservpass; echo $nickservpass > $CONFDIR/networks/$netname/nickserv; nickservpass=; echo "")
	usenickserv=
	useautojoin=`prompt-for "Join any channels automatically? [Y] "`
	test $useautojoin == "y" && nano $CONFDIR/networks/$netname/autojoin || ( echo "" | tee $CONFDIR/networks/$netname/autojoin ) &>/dev/null
	useautojoin=
	useautocommands=`prompt-for "Run any commands automatically? [Y] "`
	test $useautocommands == "y" && nano $CONFDIR/networks/$netname/autorun || ( echo "" | tee $CONFDIR/networks/$netname/autorun ) &>/dev/null
	useautocommands=
}
function networks-reconfigure {
	test -n "$1" || ( echo -n "Enter the network to modify: "; read netname; export netname; exit 1 ) && netname=$1
	test -d "$CONFDIR/networks/$netname" || ( echo "That network doesn't exist"; exit 1 ) || return
	netaddr=
	echo -n "Either enter the address of the server or enter the address then the port, with a space between: "
	read netaddr
	test -n "`echo $netaddr | awk '{print $2}'`" || ( echo $netaddr 6667 | tee -a $CONFDIR/networks/$netname/addresses ) && ( echo $netaddr | tee -a $CONFDIR/networks/$netname/addresses ) &>/dev/null
	netaddr=
	autoconnect=
	autoconnect=`prompt-for "Auto-connect to this network on startup? [Y] "`
	test $autoconnect == "y" && ( echo $netname | tee -a $CONFDIR/autoconnect ) || ( sed -i 's/$netname//1' <$CONFDIR/autoconnect >$CONFDIR/autoconnect.temp; mv $CONFDIR/autoconnect.temp $CONFDIR/autoconnect )  &>/dev/null
	usedefault=`prompt-for "Use default nickname, etc? [Y] "`
	test $usedefault == "y" && cp $CONFDIR/default/* $CONFDIR/networks/$netname  || ( read -p "What nick do you want to use for this network? " customnick ; echo $customnick | tee $CONFDIR/networks/$netname/nickname &>/dev/null; read -p "What username do you want to use for this network? " customuser; echo $customuser | tee $CONFDIR/networks/$netname/username &>/dev/null; read -p "What realname do you want to use for this network? " customreal; echo $customreal | tee $CONFDIR/networks/$netname/realname &>/dev/null )
	usedefault=
	usenickserv=`prompt-for "Authenticate with NickServ? [Y] "`
	test $usenickserv == "y" && ( read -s -p "Password? " nickservpass; echo $nickservpass > $CONFDIR/networks/$netname/nickserv; nickservpass=; echo "")
	usenickserv=
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
	currentdefnick=`cat $CONFDIR/default/nickname`
	currentdefuser=`cat $CONFDIR/default/username`
	currentdefreal=`cat $CONFDIR/default/realname`
	read -p "Current default nickname is `echo $currentdefnick`. [`echo $currentdefnick`] " newdefnick
	test -n "$newdefnick" || newdefnick=$currentdefnick
	echo $newdefnick | tee $CONFDIR/default/nickname
	read -p "Current default username is `echo $currentdefuser`. [`echo $currentdefuser`] " newdefuser
	test -n "$newdefuser" || newdefuser=$currentdefuser
	echo $newdefuser | tee $CONFDIR/default/username
	read -p "Current default realname is `echo $currentdefreal`. [`echo $currentdefreal`] " newdefreal
	test -n "$newdefreal" || newdefreal=$currentdefreal
	echo $newdefreal | tee $CONFDIR/default/realname
	newdefnick=
	newdefuser=
	newdefreal=
	currentdefnick=
	currentdefuser=
	currentdefreal=
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
		ns) ;&
		nickserv)
			echo "USAGE: 		/ns <message>"
			echo "DESCRIPTION:	Alias for /msg NickServ"
			echo "ALIASES:		/nickserv"
			;;
		cs) ;&
		chanserv)
			echo "USAGE: 		/cs <message>"
			echo "DESCRIPTION:	Alias for /msg ChanServ"
			echo "ALIASES:		/chanserv"
			;;
		bs) ;&
		botserv)
			echo "USAGE: 		/bs <message>"
			echo "DESCRIPTION:	Alias for /msg BotServ"
			echo "ALIASES:		/botserv"
			;;
		hs) ;&
		hostserv)
			echo "USAGE: 		/hs <message>"
			echo "DESCRIPTION:	Alias for /msg HostServ"
			echo "ALIASES:		/hostserv"
			;;
		ms) ;&
		memoserv)
			echo "USAGE: 		/ms <message>"
			echo "DESCRIPTION:	Alias for /msg MemoServ"
			echo "ALIASES:		/memoserv"
			;;
		os) ;&
		operserv)
			echo "USAGE: 		/os <message>"
			echo "DESCRIPTION:	Alias for /msg OperServ"
			echo "ALIASES:		/operserv"
			;;
		hs) ;&
		helpserv)
			echo "USAGE: 		/hs <message>"
			echo "DESCRIPTION:	Alias for /msg HelpServ"
			echo "ALIASES:		/helpserv"
			;;
		me) ;&
		do) ;&
		action)
			echo "USAGE: 		/me <message>"
			echo "DESCRIPTION:	Sends an action"
			echo "ALIASES:		/do, /action"
			;;
		ctcp) ;&
		sendctcp)
			echo "USAGE: 		/ctcp <nick> <message>"
			echo "DESCRIPTION:	Sends an Client-to-Client-Protocol message"
			echo "ALIASES:		/sendctcp"
			;;
		*)
			echo "USAGE: 		${command[0]} [topic]"
			echo "COMMANDS:	quit, q, disconnect, msg, privmsg, tell, join, j, part, p, query, eval, eval-global, connect, server, close, exit, nick, networks, servers, quote, ircquote, help, h, helpop, ns, nickserv, cs, chanserv, bs, botserv, hs, hostserv, ms, memoserv, os, operserv, hs, helpserv, me, action, do, sendctcp, ctcp"
			;;
	esac
}


# Configuration check
CONFDIR=~/.bashclient
soh=`echo $'\001'`
mkdir -p $CONFDIR/networks &>/dev/null
mkdir -p $CONFDIR/default &>/dev/null
test -s $CONFDIR/default/username || ( echo $USER | tee $CONFDIR/default/username ) &>/dev/null
test -s $CONFDIR/default/realname || ( echo $USER | tee $CONFDIR/default/realname ) &>/dev/null
test -f $CONFDIR/default/autojoin || ( touch $CONFDIR/default/autojoin )
test -f $CONFDIR/default/nickserv || ( touch $CONFDIR/default/nickserv )
test -f $CONFDIR/default/autorun || ( touch $CONFDIR/default/autorun; echo "# Enter the commands that will be sent directly to the server." | tee -a $CONFDIR/default/autorun; echo "# " | tee -a $CONFDIR/default/autorun; echo "# Example: PRIVMSG MyCustomBot :LOGIN mypassword" | tee -a $CONFDIR/default/autorun ) &>/dev/null
touch $CONFDIR/autoconnect &>/dev/null
test -s $CONFDIR/default/nickname || ( echo -n "Please choose a nickname: " ; read newnickname; echo $newnickname | tee $CONFDIR/default/nickname &>/dev/null; newnickname= )

test "`ls -A $CONFDIR/networks`" || askfornewnetwork

test -n "`head -n 1 $CONFDIR/autoconnect`" && connect "`head -n 1 $CONFDIR/autoconnect`"

# User input loop
while true; do
	read rawcommand
	test -n "$rawcommand" || continue # If the message is blank, ignore it
	test "${rawcommand:0:1}" == "/" || ( sendmessage; exit 1 ) || continue  # If the first character in the rawcommand is not a /, send it to the channel, otherwise do nothing
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
		ns) ;&
		nickserv)
			echo "PRIVMSG NickServ :`echo $rawcommand | substring-2`" >&3
			;;
		cs) ;&
		chanserv)
			echo "PRIVMSG ChanServ :`echo $rawcommand | substring-2`" >&3
			;;
		bs) ;&
		botserv)
			echo "PRIVMSG BotServ :`echo $rawcommand | substring-2`" >&3
			;;
		hs) ;&
		hostserv)
			echo "PRIVMSG HostServ :`echo $rawcommand | substring-2`" >&3
			;;
		ms) ;&
		memoserv)
			echo "PRIVMSG MemoServ :`echo $rawcommand | substring-2`" >&3
			;;
		os) ;&
		operserv)
			echo "PRIVMSG OperServ :`echo $rawcommand | substring-2`" >&3
			;;
		hs) ;&
		helpserv)
			echo "PRIVMSG NickServ :`echo $rawcommand | substring-2`" >&3
			;;
		me) ;&
		do) ;&
		action)
			echo "PRIVMSG $activewindow :`echo -n $soh`ACTION `echo $rawcommand | substring-2``echo -n $soh`" >&3
			;;
		ctcp) ;&
		sendctcp)
			echo "PRIVMSG ${command[1]} :`echo -n $soh``echo $rawcommand | substring-3``echo -n $soh`" >&3
			;;
		*)
			echo $rawcommand | cut -c 2- >&3
			;;
	
	esac
	rawcommand=
	command=
	basecommand=
done

