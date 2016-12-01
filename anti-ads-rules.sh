#!/usr/bin/env bash

# Autor: 	Carl Jonathan Schubert
# GitHub:	https://github.com/Johnny-Ich/anti-ads-rules/
# E-Mail: 	jonathan-schubert@gcraft.eu
# E-Mail #2: 	jonathan@eseltritt.de
# License: 	GNU GENERAL PUBLIC LICENSE Version 3

### Settings ###
ipver="v4" 		# "v4" OR "v6" OR "both"
chain="FORWARD"		# "FORWARD" for Router/Firwall OR "OUTPUT" for local machine
iface="eth0"		# Interface on wich to Apply these Rules on
action="REJECT"		# "REJECT" OR "DROP" or others...
debug="true"		# just do the loop one time and exit without taking rules active

# Variablen als integer deklarieren, da sonst keine Berechnungen möglich
typeset -i i
typeset -i linestart
typeset -i lineend
typeset -i linedelete
typeset -i linedeleteend
typeset -i linedeletecounter
typeset -i lineinsert
typeset -i linestmpfile
typeset -i count
typeset -i linestartv4
typeset -i linestartv6

if [[ $action == "REJECT" ]]; then action="REJECT --reject-with icmp-host-prohibited"; fi

cp /etc/iptables/rules.v4 /etc/iptables/BACKUP_rules.v4
cp /etc/iptables/rules.v4 .
cp /etc/iptables/rules.v6 /etc/iptables/BACKUP_rules.v6
cp /etc/iptables/rules.v6 .

if [[ $ipver == "both" ]];then count=2; ipver=v4; else count=1;fi

for (( i=0 ; $i<$count ;i=$i+1 ))
do

	linestart=$(sed -n '/adblock-script-start/=' rules.$ipver)
	lineend=$(sed -n '/adblock-script-end/=' rules.$ipver)

	if [[ $linestart == $lineend ]]
	then
		linestart=$(sed -n "/-A $chain/=" rules.$ipver | head -1)
		if [[ $ipver == "v4" ]]; then; linestartv4=$linestart; fi
		if [[ $ipver == "v6" ]]; then; linestartv6=$linestart; fi
		lineinsert=$linestart-1
		sed -i "$(echo "$lineinsert")a$(echo "# adblock-script-start")" rules.$ipver
		sed -i "$(echo "$linestart")a$(echo "# adblock-script-end")" rules.$ipver
		lineend=$(sed -n '/adblock-script-end/=' rules.$ipver)
	else
		linedeleteend=$lineend
		linedelete=$linestart+1
		linedeletecounter=$linedelete

		for (( ; $linedeletecounter<$linedeleteend ; ))
		do
        		sed -i "$(echo "$linedelete")d" rules.$ipver
        		linedeletecounter=$linedeletecounter+1
		done
	fi
	
	if [[ $i == 0 && $count == 2 ]] ;then ipver=v6; fi
	if [[ $i == 1 && $count == 2 ]] ;then ipver=v4; fi
done

wget -q -O tmpfile "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml&showintro=0&mimetype=plaintext"
linestmpfile=$(cat tmpfile | wc -l)

# Counter wieder heruntersetzen
i=1

cat tmpfile | while read line
do
	host $line | while read adblockIP
	do
		if [[ $ipver == "v4" || $count == 2 ]]
		then
			# IPv4 Regeln einfügen
			IP=$(echo $adblockIP | grep 'has address' | cut -d ' ' -f 4 )
			if [[ $IP == "" ]]
			then
				leer=0
			else			
				sed -i "$(echo "$linestartv4")a$(echo "-A $chain -d $IP -o $iface -j $action")" rules.v4
			fi
		fi
		if [[ $ipver == "v6" || $count == 2 ]]
		then
			# IPv6 Regeln einfügen
			IP=$(echo $adblockIP | grep 'has IPv6 address' | cut -d ' ' -f 5 )
			if [[ $IP == "" ]]
			then
				leer=0
			else
				sed -i "$(echo "$linestartv6")a$(echo "-A $chain -d $IP -o $iface -j $action")" rules.v6
			fi
		fi
	done
	i=$i+1
	progress=$(echo "scale=2;$i/$linestmpfile*100" | bc | cut -d . -f 1)
	echo -ne "\rProgress: $progress%"
done

cp rules.v4 /etc/iptables/rules.v4
iptables-restore < /etc/iptables/rules.v4
cp rules.v6 /etc/iptables/rules.v6
ip6tables-restore < /etc/iptables/rules.v6
rm tmpfile
exit
