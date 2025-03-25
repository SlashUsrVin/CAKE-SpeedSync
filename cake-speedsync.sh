#!/bin/sh

CS_PATH="/jffs/scripts/cake-speedsync"

#Log start date and time
date >> "$CS_PATH/cake-ss.log"

#Source cake-speedsync related functions
. "$CS_PATH/cake-ss-fn.sh"
   
#If CAKE is disabled, enable it.
qdisc=$(tc qdisc show dev eth0 root)
if [ -n "$qdisc" ]; then
   cs_enable_eth0
fi
qdisc=$(tc qdisc show dev ifb4eth0 root)
if [ -n "$qdisc" ]; then
   cs_enable_ifb4eth0
fi

#Retrieve current CAKE setting. 
cake_eth0=$(cs_get_qdisc "eth0")
cake_ifb4eth0=$(cs_get_qdisc "ifb4eth0")

set -- $(echo "$cake_eth0" | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9}')
qd_eSPD="$1 $2"
qd_eSCH="$3"
qd_eRTT="$4 $5"
qd_eMPU="$6 $7"
qd_eOVH="$8 $9"

set -- $(echo "$cake_ifb4eth0" | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9}')
qd_iSPD="$1 $2"
qd_iSCH="$3"
qd_iRTT="$4 $5"
qd_iMPU="$6 $7"
qd_iOVH="$8 $9"

#Check if /jffs/scripts/cake-speedsync/cake.cfg exists. If so, use the scheme in the cfg file (i.e diffserv4, diffserv3, besteffort, etc)
if [ -f "$CS_PATH/cake.cfg" ]; then
   while read -r line; do
      set -- $(echo "$line" | awk '{print $1, $2}'); intfc=$1; cfg=$2;

      if [ "$intfc" == "eth0" ]; then
         cf_eSCH="$cfg"
      fi

      if [ "$intfc" == "ifb4eth0" ]; then
         cf_iSCH="$cfg"
      fi; done < "$CS_PATH/cake.cfg"
else
   cf_eSCH="diffserv4" #default eth0 to diffserv4
   cf_iSCH="diffserv3" #default ifb4eth0 to diffserv3
fi

eRep="0"
if [ "$qd_eSCH" != "$cf_eSCH" ] && [ -n "$cf_eSCH" ]; then
   eRep="1"
   eScheme="$cf_eSCH"
else
   eScheme="$qd_eSCH"
fi

iRep="0"
if [ "$qd_iSCH" != "$cf_iSCH" ] && [ -n "$cf_iSCH" ]; then
   iRep="1"
   iScheme="$cf_iSCH"
else
   iScheme="$qd_iSCH"   
fi

#Increase bandwidth temporarily to avoid throttling
#Default settings is already set to 2gbit but if cake is already active this will ensure the bandwidth is set very high before the speed test
tc qdisc change dev ifb4eth0 root cake bandwidth 2gbit #Download
tc qdisc change dev eth0 root cake bandwidth 2gbit     #Upload
#Increase rtt temporarily to avoid throttling
tc qdisc change dev ifb4eth0 root cake rtt 100ms #Download
tc qdisc change dev eth0 root cake rtt 100ms     #Upload

#Run Speedtest and generate result in json format
spdtstresjson=$(ookla -c http://www.speedtest.net/api/embed/vz0azjarf5enop8a/config -p no -f json)

#Restore previous CAKE settings and exit if speedtest fails
if [ $? -ne 0 ] || [ -z "$spdtstresjson" ]; then
   echo "Speed test failed!" >> cake-ss.log
   
   #Restore previous CAKE settings
   cs_upd_qdisc "eth0" "$qd_eSPD"
   cs_upd_qdisc "eth0" "$qd_eRTT"

   cs_upd_qdisc "ifb4eth0" "$qd_iSPD"
   cs_upd_qdisc "ifb4eth0" "$qd_iRTT"

   exit 1
fi

#Check if Queueing Discipline changed (current qdisc != qdisc in cake.cfg)
if [ $eRep -eq 1 ]; then
   cs_enable_eth0 "$eScheme"   #Replace with the new selected Queueing Discipline
   cs_upd_qdisc "eth0" "$qd_eOVH" #Retain overhead from webui
   cs_upd_qdisc "eth0" "$qd_eMPU" #Retain mpu from webui
fi

if [ $iRep -eq 1 ]; then
   cs_enable_ifb4eth0 "$iScheme"   #Replace with the new selected Queueing Discipline
   cs_upd_qdisc "ifb4eth0" "$qd_iOVH" #Retain overhead from webui
   cs_upd_qdisc "ifb4eth0" "$qd_iMPU" #Retain mpu from webui
fi

#Extract bandwidth from json
DLSpeedbps=$(echo "$spdtstresjson" | grep -oE '\],"bandwidth":[0-9]+' | grep -oE [0-9]+)
ULSpeedbps=$(echo "$spdtstresjson" | grep -oE '"upload":\{"bandwidth":[0-9]+' | grep -oE [0-9]+)

#Convert bandwidth to Mbits - This formula is based from the speedtest in QoS speedtest tab
DLSpeedMbps=$(((DLSpeedbps * 8) / 1000000))
ULSpeedMbps=$(((ULSpeedbps * 8) / 1000000))

#Update bandwidth base from speedtest. Applied before the latency check.
cs_upd_qdisc "eth0" "bandwidth ${ULSpeedMbps}mbit"
cs_upd_qdisc "ifb4eth0" "bandwidth ${DLSpeedMbps}mbit"

#RTT multiple - basis for both eth0 and ifb4eth0
rttm=5 

#Extract latency from json
#The RTT value for ifb4eth0 is determined based on the speedtest latency 
iping=$(echo "$spdtstresjson" | grep -oE '"latency":\s?[0-9]+(\.[0-9]*)?' | grep -oE '[0-9]+(\.[0-9]*)?')
ipingwhole=$(echo "$iping" | sed -E 's/\.[0-9]+//')

#The RTT value for eth0 is determined based on the ping response from Google. 
eping=$(ping -c 10 8.8.8.8 | grep -oE 'time\=[0-9]+(.[0-9]*)?\sms' | grep -oE '[0-9]+(.[0-9]*)?')
epingmedian=$(echo "$eping" | awk 'NR==6')
epingwhole=$(echo "$epingmedian" | sed -E 's/\.[0-9]+//')

#The selected RTT for eth0 and ifb4eth0 will be rounded to the nearest multiple of (rttm value) for consistency.
ertt=$(( (epingwhole + rttm - 1) / rttm * rttm )) #eth0
irtt=$(( (ipingwhole + rttm - 1) / rttm * rttm )) #ifb4eth0

if [ $ertt -ge 95 ]; then
   ertt=100 #default cake rtt
fi

if [ $irtt -ge 95 ]; then
   irtt=100 #default cake rtt
fi

#Apply rtt
cs_upd_qdisc "eth0" "rtt ${ertt}ms"
cs_upd_qdisc "ifb4eth0" "rtt ${irtt}ms"

#Log new cake settings
tc qdisc | grep cake >> "$CS_PATH/cake-ss.log"

#Store logs for the last 7 updates only (tail -21)
tail -21 "$CS_PATH/cake-ss.log" > "$CS_PATH/temp.log" && mv "$CS_PATH/temp.log" "$CS_PATH/cake-ss.log" && chmod 666 "$CS_PATH/cake-ss.log"

#Show run details
clear
echo -e "\n\n    SpeedTest Result: --->   Download: ${DLSpeedMbps}Mbps    Upload: ${ULSpeedMbps}Mbps    Latency: ${iping}ms" 
echo -e "    Google Ping Test: --->   Median: ${epingmedian}ms"
echo -e "\nActive CAKE Settings:"
tc qdisc | grep cake
echo -e "\n\nCake-SpeedSync completed successfully!\n\n\n"