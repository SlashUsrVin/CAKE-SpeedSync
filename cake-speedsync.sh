#!/bin/sh

cd /jffs/scripts || exit 1

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
#Download (ifb4eth0)
#tc qdisc replace dev ifb4eth0 root cake bandwidth "${DLSpeedMbps}mbit" besteffort dual-dsthost nat wash ingress no-ack-filter split-gso rtt 25ms noatm overhead 54 mpu 84
tc qdisc replace dev ifb4eth0 root cake bandwidth "${DLSpeedMbps}mbit" diffserv4 dual-dsthost nat wash ingress no-ack-filter split-gso rtt 10ms noatm overhead 54 mpu 88
#Upload (eth0)
#tc qdisc replace dev eth0 root cake bandwidth "${ULSpeedMbps}mbit" besteffort dual-srchost nat nowash no-ack-filter split-gso rtt 25ms noatm overhead 54 mpu 84
tc qdisc replace dev eth0 root cake bandwidth "${ULSpeedMbps}mbit" diffserv4 dual-srchost nat no-ack-filter split-gso rtt 10ms noatm overhead 54 mpu 88

#Log new cake settings
tc qdisc | grep cake >> cake-ss.log

#Store logs for the last 7 updates only (tail -21)
tail -21 cake-ss.log > temp.log && mv temp.log cake-ss.log && chmod 666 cake-ss.log

echo "Download: ${DLSpeedMbps}Mbps Upload: ${ULSpeedMbps}Mbps"
echo $(tc qdisc | grep cake)