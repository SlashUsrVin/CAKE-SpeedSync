#!/bin/sh

#Source cake-speedsync related functions
. /jffs/scripts/cake-speedsync/css-functions.sh

cd /jffs/scripts/cake-speedsync || exit 1

css_preserv_cake

#Log start date and time
date >> cake-ss.log

#Disable CAKE before speedtest
tccake=$(tc qdisc | grep cake)
if [ -z "$tccake" ]; then
   echo "None"
else
   tc qdisc del dev ifb4eth0 root #Download
   tc qdisc del dev eth0 root     #Upload
fi

#Run Speedtest and generate result in json format
#ookla -c http://www.speedtest.net/api/embed/vz0azjarf5enop8a/config -p no -f json > spd-tst-result.json && chmod 777 spd-tst-result.json
spdtstresjson=$(ookla -c http://www.speedtest.net/api/embed/vz0azjarf5enop8a/config -p no -f json)

#Exit if speedtst fails
if [ -z "$spdtstresjson" ]; then
   echo "Speed test failed!" >> cake-ss.log
   exit 1
fi

#Extract bandwidth from json
#DLSpeedbps=$(grep -oE '\],"bandwidth":[0-9]+' spd-tst-result.json | grep -oE [0-9]+)
#ULSpeedbps=$(grep -oE '"upload":\{"bandwidth":[0-9]+' spd-tst-result.json | grep -oE [0-9]+)
DLSpeedbps=$(echo "$spdtstresjson" | grep -oE '\],"bandwidth":[0-9]+' | grep -oE [0-9]+)
ULSpeedbps=$(echo "$spdtstresjson" | grep -oE '"upload":\{"bandwidth":[0-9]+' | grep -oE [0-9]+)

#Convert bandwidth to Mbits - This formula is based from the speedtest in QoS speedtest tab
DLSpeedMbps=$(((DLSpeedbps * 8) / 1000000))
ULSpeedMbps=$(((ULSpeedbps * 8) / 1000000))

#Re-apply CAKE
awk '{print $0, $2}' /jffs/scripts/cake-speedsync/cake.cmd 2>/dev/null | while read -r line intfc; do
   #retrieve base command and update rtt to 20ms (default cake rtt (from web ui) is 100ms)
   basecmd=$(echo "$line" | grep -oE 'bandwidth.*' | sed -E "s/\brtt\s[0-9]+ms/rtt 20ms/")
   if [[ "$intfc" == "eth0" ]]; then
      #update bandwidth
      cmd=$(echo "$basecmd" | sed -E "s/\bbandwidth\s[0-9]+[a-zA-Z]{3,4}/bandwidth ${ULSpeedMbps}mbit/") #\b whole word boundary)
   else
      #update bandwidth
      cmd=$(echo "$basecmd" | sed -E "s/\bbandwidth\s[0-9]+[a-zA-Z]{3,4}/bandwidth ${DLSpeedMbps}mbit/") #\b whole word boundary)
   fi
   eval $(echo "tc qdisc replace dev $intfc root cake $cmd"); done 

#Log new cake settings
tc qdisc | grep cake >> cake-ss.log

#Store logs for the last 7 updates only (tail -21)
tail -21 cake-ss.log > temp.log && mv temp.log cake-ss.log && chmod 666 cake-ss.log

echo "Download: ${DLSpeedMbps}Mbps Upload: ${ULSpeedMbps}Mbps"
echo $(tc qdisc | grep cake)