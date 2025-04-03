#!/bin/sh
# CAKE-SpeedSync - Automatic QoS Configuration Script
# Copyright (C) 2025 https://github.com/mvin321
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
logparm="$1"

function log () {
   msg="$1" #Assign 1st ($1) argument to msg"
   if [ "$logparm" == "logging" ]; then
      shift    #Remove msg (=$1) as 1st argument since msg can also contain multiple arguments (%s). This will avoid the whole string (msg) to be assigned to itself.
      printf -- "$msg\n" "$@"
   fi
}

log "\nRunning CAKE-SpeedSync with logs enabled...."

if [ "$logparm" != "logging" ]; then
   printf "\nRunning CAKE-SpeedSync with logs disabled...."
fi

CS_PATH="/jffs/scripts/cake-speedsync"

#On reboot, wait a few seconds to make sure tc is already active
ctr=0
max_wait_time=10 

while [ "$ctr" -lt "$max_wait_time" ]; do
   if tc qdisc show | grep -q "cake"; then
      break #If tc is active, stop waiting and continue
   fi

   if [ "$ctr" -eq 0 ]; then
      log "Waiting for qdisc..."
   fi
   sleep 1
   ctr=$((ctr + 1))
done

#Log start date and time
date >> "$CS_PATH/cake-ss.log"

#Source cake-speedsync related functions
. "$CS_PATH/cake-ss-fn.sh"
   
#Get current CAKE settings
qdisc=$(tc qdisc show dev eth0 root | grep cake)
log "\nCurrent CAKE settings:"
log "$qdisc"
if [ -n "$qdisc" ]; then
   #Retrieve current CAKE eth0 setting. 
   cake_eth0=$(cs_get_qdisc "eth0")
   set -- $(echo "$cake_eth0" | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9}')
   qd_eSPD="$1 $2"
   qd_eSCH="$3"
   qd_eRTT="$4 $5"
   qd_eMPU="$6 $7"
   qd_eOVH="$8 $9"
   eqosenabled="1"
else
   eqosenabled="0"
fi
qdisc=$(tc qdisc show dev ifb4eth0 root | grep cake)
log "$qdisc"
if [ -n "$qdisc" ]; then
   cake_ifb4eth0=$(cs_get_qdisc "ifb4eth0")
   set -- $(echo "$cake_ifb4eth0" | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9}')
   qd_iSPD="$1 $2"
   qd_iSCH="$3"
   qd_iRTT="$4 $5"
   qd_iMPU="$6 $7"
   qd_iOVH="$8 $9"
   iqosenabled="1"
else
   iqosenabled="0"
fi

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
   cf_eSCH="diffserv3" #default cake merlin setting
   cf_iSCH="besteffort" #default cake merlin setting
fi

eScheme="$cf_eSCH"
iScheme="$cf_iSCH"

log "\n$CS_PATH/cake.cfg"
log "$(cat $CS_PATH/cake.cfg)"

#Enable CAKE with default settings for speedtest
cs_default_eth0 "diffserv3"      #force to diffserv3 for speedtest
cs_default_ifb4eth0 "diffserv3"  #force to diffserv3 for speedtest

#Use default MPU and Overhead if not yet set in the web UI
if [ "$eqosenabled" -eq 0 ]; then
   cake_eth0=$(cs_get_qdisc "eth0")
   set -- $(echo "$cake_eth0" | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9}')
   qd_eMPU="$6 $7"
   qd_eOVH="$8 $9"
fi
if [ "$iqosenabled" -eq 0 ]; then
   cake_ifb4eth0=$(cs_get_qdisc "ifb4eth0")
   set -- $(echo "$cake_ifb4eth0" | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9}')
   qd_iMPU="$6 $7"
   qd_iOVH="$8 $9"
fi

log "\nUsing the following Queueing Discipline for ookla speedtest...."
qdisc=$(tc qdisc show dev eth0 root | grep cake)
log "$qdisc"
qdisc=$(tc qdisc show dev ifb4eth0 root | grep cake)
log "$qdisc"

#Run Speedtest and generate result in json format
json="$CS_PATH/spdtstresjson.json"
> "$json"
log "\nRunning ookla speedtest to generate network load..."
((ookla -c http://www.speedtest.net/api/embed/vz0azjarf5enop8a/config -p no -f json > "$json") &)

log "\nCapturing network throughput while speedtest runs in the background..."

ctr=0
max_wait_time=60 #max wait time before quitting
maxeBps=0
maxiBps=0

while [ "$ctr" -lt "$max_wait_time" ]; do

    dl=$(cs_net_dev_get "ifb4eth0")
    ul=$(cs_net_dev_get "eth0")

    if [ -n "$prevdl" ] || [ -n "$prevul" ]; then
       eBps=$(expr "$dl" - "$prevdl") #Download rate in Bps
       iBps=$(expr "$ul" - "$prevul") #Upload rate in Bps
   
       log "$(date) download: $(cs_to_mbit ${eBps})MBps   upload: $(cs_to_mbit ${iBps})Mbps"

       if [ "$eBps" -gt "$maxeBps" ]; then
          maxeBps=$eBps
       fi

       if [ "$iBps" -gt "$maxiBps" ]; then
          maxiBps=$iBps
       fi
    fi

    if [  -s "$json" ]; then
        break #SpeedTest is done
    fi
    prevdl=$dl
    prevul=$ul
    sleep 1
    ctr=$((ctr + 1))
done

spdtstresjson=$(cat "$json")

#Restore previous CAKE settings and exit if speedtest fails
if [ ! -s "$json" ]; then
   echo "Speed test failed!" >> cake-ss.log
   
   #If enabled before speedtest, restore previous CAKE settings. Otherwise, delete qdisc for eth0
   if [ "$eqosenabled" == "1" ]; then
      cs_add_eth0 "$qd_eSCH" "$qd_eSPD" "$qd_eRTT" "$qd_eOVH" "$qd_eMPU"
   else
      cs_disable_eth0
   fi
   #If enabled before speedtest, restore previous CAKE settings. Otherwise, delete qdisc for ifb4eth0
   if [ "$iqosenabled" == "1" ]; then
      cs_add_ifb4eth0 "$qd_iSCH" "$qd_iSPD" "$qd_iRTT" "$qd_iOVH" "$qd_iMPU"
   else
      cs_disable_ifb4eth0
   fi

   exit 1
fi

log "\nCalculating bandwidth...."

#Get speedtest DL and UL speed for reference only (data not used)
spdDL=$(echo "$spdtstresjson" | grep -oE '\],"bandwidth":[0-9]+' | grep -oE [0-9]+)
spdUL=$(echo "$spdtstresjson" | grep -oE '"upload":\{"bandwidth":[0-9]+' | grep -oE [0-9]+)
spdDL=$(cs_to_mbit "$spdDL")
spdUL=$(cs_to_mbit "$spdUL")

#Convert max tx rate from net/dev to Mbps
maxDLMbps=$(cs_to_mbit "$maxeBps")
maxULMbps=$(cs_to_mbit "$maxiBps")

#Set 95% of max speed for CAKE QoS
DLSpeedMbps=$(((maxDLMbps * 95) / 100))
ULSpeedMbps=$(((maxULMbps * 95) / 100))

#RTT multiple - basis for both eth0 and ifb4eth0
rttm=5 

#Extract latency from json
#The RTT value for ifb4eth0 is determined based on the speedtest latency 
iping=$(echo "$spdtstresjson" | grep -oE '"latency":\s?[0-9]+(\.[0-9]*)?' | grep -oE '[0-9]+(\.[0-9]*)?')
ipingwhole=$(echo "$iping" | sed -E 's/\.[0-9]+//')

log "\nGoogle ping test in progress...."
#The RTT value for eth0 is determined based on the ping response from Google. 
eping=$(ping -c 10 8.8.8.8 | grep -oE 'time\=[0-9]+(.[0-9]*)?\sms' | grep -oE '[0-9]+(.[0-9]*)?')
epingmedian=$(echo "$eping" | awk 'NR==6')
epingwhole=$(echo "$epingmedian" | sed -E 's/\.[0-9]+//')

log "\nCalculating rtt...."
#The selected RTT for eth0 and ifb4eth0 will be rounded to the nearest multiple of (rttm value) for consistency.
ertt=$(( (epingwhole + rttm - 1) / rttm * rttm )) #eth0
irtt=$(( (ipingwhole + rttm - 1) / rttm * rttm )) #ifb4eth0

if [ $ertt -ge 95 ]; then
   ertt=100 #default cake rtt
fi

if [ $irtt -ge 95 ]; then
   irtt=100 #default cake rtt
fi

#Re-enable CAKE with updated settings
cs_add_eth0 "$eScheme" "bandwidth ${ULSpeedMbps}mbit" "rtt ${ertt}ms" "$qd_eOVH" "$qd_eMPU"
cs_add_ifb4eth0 "$iScheme" "bandwidth ${DLSpeedMbps}mbit" "rtt ${irtt}ms" "$qd_iOVH" "$qd_iMPU"

#Logs
printf "\n\n"
{
printf "    Network Analysis: --->   Download: %sMbps(Max) -> %sMbps(95%%)    Upload: %sMbps(Max) -> %sMbps(95%%)" "$maxDLMbps" "$DLSpeedMbps" "$maxULMbps" "$ULSpeedMbps"
printf "\n    SpeedTest Result: --->   Download: %sMbps    Upload: %sMbps    Latency: %sms" "$spdDL" "$spdUL" "$iping" 
printf "\n    Google Ping Test: --->   Median: %sms" "$epingmedian" 
printf "\n"
} | tee -a "$CS_PATH/cake-ss.log"
printf "\n\nUpdated CAKE Settings:\n" 
tc qdisc | grep "eth0 root" | grep -oE 'dev.*' | sed 's/^/                      --->   /'
printf "\n\nCake-SpeedSync completed successfully!\n\n\n"

#Store logs for the last 7 runs only (tail -24)
tail -24 "$CS_PATH/cake-ss.log" > "$CS_PATH/temp.log" && mv "$CS_PATH/temp.log" "$CS_PATH/cake-ss.log" && chmod 666 "$CS_PATH/cake-ss.log"