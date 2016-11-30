#!/usr/bin/env bash

# Autor: 	Carl Jonathan Schubert
# E-Mail: 	jonathan-schubert@gcraft.eu
# E-Mail #2: 	jonathan@eseltritt.de

typeset -i i
typeset -i linestart
typeset -i lineend
typeset -i linedelete
typeset -i linedeleteend
typeset -i lineinsert

iptables-save > /etc/iptables/rules.v4
cp /etc/iptables/rules.v4 /etc/iptables/rules.v4_BACKUP
cp /etc/iptables/rules.v4 .

linestart=$(sed -n '/adblock-script-start/=' rules.v4)
lineend=$(sed -n '/adblock-script-end/=' rules.v4)



if [ $linestart == $lineend ]
then
	linestart=$(sed -n '/-A FORWARD/=' rules.v4 | head -1)
	lineinsert=$linestart-1
	sed -i "$(echo "$lineinsert")a$(echo "# adblock-script-start")" rules.v4
	sed -i "$(echo "$linestart")a$(echo "# adblock-script-end")" rules.v4
	lineend=$(sed -n '/adblock-script-end/=' rules.v4)
else
	linedeleteend=$lineend
	linedelete=$linestart+1
	linedeletecounter=$linedelete

	for (( ; $linedeletecounter<$linedeleteend; ))
	do
        	sed -i "$(echo "$linedelete")d" rules.v4
        	linedeletecounter=$linedeletecounter+1
	done
fi

wget -q -O tmpfile "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml&showintro=0&mimetype=plaintext"
touch tmpfile
cat tmpfile | while read line; do
	host $line | grep 'has address' | cut -d ' ' -f 4 | while read adblockIP; do
		sed -i "$(echo "$linestart")a$(echo "-A FORWARD -d $adblockIP -o eth0 -j DROP")" rules.v4
	done
	i=$i+1
	progress=$(echo "scale=2;$i/3000*100" | bc | cut -d . -f 1)
	echo -ne "\rProgress: $progress%"
done
cp rules.v4 /etc/iptables/rules.v4
iptables-restore < /etc/iptables/rules.v4
rm tmpfile
exit
