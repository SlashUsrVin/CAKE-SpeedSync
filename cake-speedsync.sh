#!/bin/sh

#Log start date and time
date >> cake-ss.log

#Source cake-speedsync related functions
. /jffs/scripts/cake-speedsync/css-functions.sh

cd /jffs/scripts/cake-speedsync || exit 1
   
#Retrieve current CAKE setting
cake_eth0=$(css_retrieve_cake_qdisc "eth0")
cake_ifb4eth0=$(css_retrieve_cake_qdisc "ifb4eth0")

qd_eSPD=$(echo "$cake_eth0" | awk '{print $1, $2}')
qd_eSCH=$(echo "$cake_eth0" | awk '{print $3}')
qd_eRTT=$(echo "$cake_eth0" | awk '{print $4, $5}')
qd_eMPU=$(echo "$cake_eth0" | awk '{print $6, $7}')
qd_eOVH=$(echo "$cake_eth0" | awk '{print $8, $9}')

qd_iSPD=$(echo "$cake_ifb4eth0" | awk '{print $1, $2}')
qd_iSCH=$(echo "$cake_ifb4eth0" | awk '{print $3}')
qd_iRTT=$(echo "$cake_ifb4eth0" | awk '{print $4, $5}')
qd_iMPU=$(echo "$cake_ifb4eth0" | awk '{print $6, $7}')
qd_iOVH=$(echo "$cake_ifb4eth0" | awk '{print $8, $9}')   

#Check if /jffs/scripts/cake-speedsync/cake.cfg exists. If so, use the scheme in the cfg file (i.e diffserv4, diffserv3,etc)
if [ -f "cake.cfg" ]; then
   while read -r line; do
      intf=$(echo "$line" | awk '{pring $1}')
      cfg=$(echo "$line" | awk '{pring $2}')

      if [[ "$intfc" == "eth0" ]]; then
         cf_eSCH=$cfg
      fi

      if [[ "$intfc" == "ifb4eth0" ]]; then
         cf_iSCH=$cfg
      fi; done < cake.cfg
else
   cf_eSCH="diffserv4" #default eth0 to diffserv4
   cf_iSCH="diffserv3" #default ifb4eth0 to diffserv3
fi

eRep="0"
if [ "$qd_eSCH" != "$cf_eSCH" ]; then
   eRep="1"
   eScheme="$cf_eSCH"
else
   eScheme="$qd_eSCH"
fi

iRep="0"
if [ "$qd_iSCH" != "$cf_iSCH" ]; then
   iRep="1"
   iScheme="$cf_iSCH"
else
   iScheme="$qd_iSCH"   
fi

#Check if CAKE is active
tccake=$(tc qdisc | grep cake)
if [ -z "$tccake" ]; then
   #Enable CAKE with default settings
   css_enable_default_cake "$eScheme" "$iScheme"
fi

#Increase bandwidth temporarily to avoid throttling
#Default settings is already set to unlimited but if cake is already active this will ensure the bandwidth is updated to unlimited before the speed test
tc qdisc change dev ifb4eth0 root cake bandwidth unlimited #Download
tc qdisc change dev eth0 root cake bandwidth unlimited     #Upload

#Run Speedtest and generate result in json format
spdtstresjson=$(ookla -c http://www.speedtest.net/api/embed/vz0azjarf5enop8a/config -p no -f json)

#Restore previous CAKE settings and Exit if speedtest fails
if [ -z "$spdtstresjson" ]; then
   echo "Speed test failed!" >> cake-ss.log
   
   if [ -n "$tccake" ]; then
      #Restore previous CAKE settings
      css_update_cake $eScheme $qd_eSPD
      css_update_cake $eScheme $qd_eRTT
      css_update_cake $eScheme $qd_eOVH
      css_update_cake $eScheme $qd_eMPU
      css_update_cake $iScheme $qd_iSPD
      css_update_cake $iScheme $qd_iRTT
      css_update_cake $iScheme $qd_iOVH
      css_update_cake $iScheme $qd_iMPU      
   fi

   exit 1
fi

#Extract bandwidth from json
DLSpeedbps=$(echo "$spdtstresjson" | grep -oE '\],"bandwidth":[0-9]+' | grep -oE [0-9]+)
ULSpeedbps=$(echo "$spdtstresjson" | grep -oE '"upload":\{"bandwidth":[0-9]+' | grep -oE [0-9]+)

#Convert bandwidth to Mbits - This formula is based from the speedtest in QoS speedtest tab
DLSpeedMbps=$(((DLSpeedbps * 8) / 1000000))
ULSpeedMbps=$(((ULSpeedbps * 8) / 1000000))

#Update bandwidth base from speedtest. This is need before the latency check.
css_update_cake $eScheme "bandwidth ${ULSpeedMbps}mbit"
css_update_cake $iScheme "bandwidth ${DLSpeedMbps}mbit"

#RTT - Base rtt from dns latency
dlatency=$(ping -c 10 8.8.8.8 | grep -oE 'time\=[0-9]+(.[0-9]*)?\sms' | grep -oE '[0-9]+(.[0-9]*)?')
rttmedian=$(echo "$dlatency" | awk 'NR==6')
rttwhole=$(echo "$rttmedian" | sed -E 's/\.[0-9]+//')
case $(( $rttwhole / 10 )) in
   0) rtt=10;;
   1) rtt=20;;
   2) rtt=30;;
   3) rtt=40;;
   4) rtt=50;;
   *) rtt=100;;
esac

#Update rtt base from ping response time from Google (8.8.8.8)
css_update_cake $eScheme "rtt ${rtt}ms"
css_update_cake $iScheme "rtt ${rtt}ms"

#Log new cake settings
tc qdisc | grep cake >> cake-ss.log

#Store logs for the last 7 updates only (tail -21)
tail -21 cake-ss.log > temp.log && mv temp.log cake-ss.log && chmod 666 cake-ss.log

echo -e "Download Speed: ${DLSpeedMbps}Mbps\nUpload: ${ULSpeedMbps}Mbps\nGoogle Ping Time: ${rtt}"