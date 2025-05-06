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

#SCRIPT-ALIAS:CAKE-SpeedSync

#Source cake-speedsync related functions
CS_PATH="/jffs/scripts/cake-speedsync"
source "$CS_PATH/cake-ss-fn.sh"

logparm="$1"

function log () {
   #replace % with %% except if % is followed by s (%s) which is a string argument for printf
   msg=$(echo "$1" | sed -e 's/%s/__KEEP_THIS__/g' -e 's/%/%%/g' -e 's/__KEEP_THIS__/%s/g')
   if [ "$logparm" == "logging" ]; then
      shift    #Remove msg (=$1) as 1st argument since msg can also contain multiple arguments (%s). This will avoid the whole string (msg) to be assigned to itself.
      printf -- "$msg\n" "$@"
   fi
}

log "\nRunning CAKE-SpeedSync with logs enabled...."

if [ "$logparm" != "logging" ]; then
   printf "\nRunning CAKE-SpeedSync with logs disabled...."
fi

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
 
#Get current CAKE settings
qdisc=$(tc qdisc show dev eth0 root | grep cake)
log "\nCurrent CAKE settings:"
log "$qdisc"
if [ -n "$qdisc" ]; then
   #Retrieve current CAKE eth0 setting. 
   qd_eSPD=$(cs_get_qdisc "eth0" "bandwidth")
   qd_eSCH=$(cs_get_qdisc "eth0" "scheme")
   qd_eRTT=$(cs_get_qdisc "eth0" "rtt")
   qd_eMPU=$(cs_get_qdisc "eth0" "mpu")
   qd_eOVH=$(cs_get_qdisc "eth0" "overhead")
   eqosenabled="0"
else
   eqosenabled="1"
fi
qdisc=$(tc qdisc show dev ifb4eth0 root | grep cake)
log "$qdisc"
if [ -n "$qdisc" ]; then
   qd_iSPD=$(cs_get_qdisc "ifb4eth0" "bandwidth")
   qd_iSCH=$(cs_get_qdisc "ifb4eth0" "scheme")
   qd_iRTT=$(cs_get_qdisc "ifb4eth0" "rtt")
   qd_iMPU=$(cs_get_qdisc "ifb4eth0" "mpu")
   qd_iOVH=$(cs_get_qdisc "ifb4eth0" "overhead")
   iqosenabled="0"
else
   iqosenabled="1"
fi

#Check if /jffs/scripts/cake-speedsync/cake.cfg exists. If so, use the scheme and rtt in the cfg file (i.e diffserv4, diffserv3, besteffort, etc)
if [ -f "$CS_PATH/cake.cfg" ]; then
   while read -r line; do
      #set -- $(echo "$line" | awk '{print $1, $2, $3, $4}')
      #cf_intfc="$1"
      #cf_sch="$2"
      #cf_rtt="$3 $4"
      cf_intfc=$(echo "$line" | awk '{print $1}')
      cf_sch=$(echo "$line" | grep -oE "(besteffort|diffserv[3-4])")
      cf_rtt=$(echo "$line" | grep -oE "rtt [0-9]+ms")
      cf_bwp=$(echo "$line" | grep -oE "bandwidth ([8-9][0-9]|100)%" | grep -oE "[0-9]+") #minimum allowable is 80% and max is 100%
      if [ "$cf_intfc" == "eth0" ]; then
         cf_eSCH="$cf_sch"
         ertt="$cf_rtt"
         ebw_alloc="$cf_bwp"
      fi

      if [ "$cf_intfc" == "ifb4eth0" ]; then
         cf_iSCH="$cf_sch"
         irtt="$cf_rtt"
         ibw_alloc="$cf_bwp"
      fi; done < "$CS_PATH/cake.cfg"
fi

#Set default value for Scheme, RTT and bandwidth allocation if not set in the configuration file (cake.cfg)
cf_eSCH=$(cs_default_str "$cf_eSCH" "diffserv3")
cf_iSCH=$(cs_default_str "$cf_iSCH" "besteffort")
ertt=$(cs_default_str "$ertt" "rtt 50ms")
irtt=$(cs_default_str "$irtt" "rtt 50ms")
ebw_alloc=$(cs_default_str "$ebw_alloc" "95")
ibw_alloc=$(cs_default_str "$ibw_alloc" "95")

eScheme="$cf_eSCH"
iScheme="$cf_iSCH"

log "\n$CS_PATH/cake.cfg"
log "$(cat $CS_PATH/cake.cfg)"

#Enable CAKE with default settings for speedtest
cs_default_eth0 "diffserv4"      #force to diffserv4 for speedtest
cs_default_ifb4eth0 "diffserv4"  #force to diffserv4 for speedtest

#Use default MPU and Overhead if not yet set in the web UI
if [ "$eqosenabled" -ne 0 ]; then
   qd_eMPU=$(cs_get_qdisc "eth0" "mpu")
   qd_eOVH=$(cs_get_qdisc "eth0" "overhead")
fi
if [ "$iqosenabled" -ne 0 ]; then
   qd_iMPU=$(cs_get_qdisc "ifb4eth0" "mpu")
   qd_iOVH=$(cs_get_qdisc "ifb4eth0" "overhead")
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
rank2iBps=0
rank2eBps=0
while [ "$ctr" -lt "$max_wait_time" ]; do

   dl=$(cs_net_dev_get "ifb4eth0")
   ul=$(cs_net_dev_get "eth0")

   if [ -n "$prevdl" ] && [ -n "$prevul" ]; then
      iBps=$(expr "$dl" - "$prevdl") #Download rate in Bps
      eBps=$(expr "$ul" - "$prevul") #Upload rate in Bps
   
      log "$(date) download: $(cs_to_mbit ${iBps})MBps   upload: $(cs_to_mbit ${eBps})Mbps"

      if [ "$eBps" -gt "$maxeBps" ]; then
         rank2eBps=$maxeBps #2nd highest to try to account for burst speed       
         maxeBps=$eBps
      elif [ "$eBps" -gt "$rank2eBps" ]; then
         rank2eBps=$eBps #2nd highest to try to  account for burst speed       
      fi

      if [ "$iBps" -gt "$maxiBps" ]; then
         rank2iBps=$maxiBps #2nd highest to try to  account for burst speed
         maxiBps=$iBps
      elif [ "$iBps" -gt "$rank2iBps" ]; then
         rank2iBps=$iBps #2nd highest to try to  account for burst speed
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
   
   #If enabled before speedtest, restore previous CAKE settings. Otherwise, set default cake for eth0
   if [ "$eqosenabled" == "0" ]; then
      cs_add_eth0 "$qd_eSCH" "$qd_eSPD" "$qd_eRTT" "$qd_eOVH" "$qd_eMPU"
   else
      cs_default_eth0
   fi
   #If enabled before speedtest, restore previous CAKE settings. Otherwise, set default cake for ifb4eth0
   if [ "$iqosenabled" == "0" ]; then
      cs_add_ifb4eth0 "$qd_iSCH" "$qd_iSPD" "$qd_iRTT" "$qd_iOVH" "$qd_iMPU"
   else
      cs_default_ifb4eth0
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
maxDLMbps=$(cs_to_mbit "$maxiBps")
maxULMbps=$(cs_to_mbit "$maxeBps")

r2DLMbps=$(cs_to_mbit "$rank2iBps")
r2ULMbps=$(cs_to_mbit "$rank2eBps")

#Set bandwidth for CAKE
DLSpeedMbps=$(((r2DLMbps * ibw_alloc) / 100))
ULSpeedMbps=$(((r2ULMbps * ebw_alloc) / 100))

#Extract latency from json (for logging purposes only)
iping=$(echo "$spdtstresjson" | grep -oE '"latency":\s?[0-9]+(\.[0-9]*)?' | grep -oE '[0-9]+(\.[0-9]*)?')

#Re-enable CAKE with updated settings
cs_add_eth0 "$eScheme" "bandwidth ${ULSpeedMbps}mbit" "$ertt" "$qd_eOVH" "$qd_eMPU"
cs_add_ifb4eth0 "$iScheme" "bandwidth ${DLSpeedMbps}mbit" "$irtt" "$qd_iOVH" "$qd_iMPU"

#Save bandwidth and rtt so it can be retrieved by cs_apply_mpu_ovh function
echo "eth0 bandwidth ${ULSpeedMbps}mbit rtt ${ertt}ms" > $CS_PATH/spd.curr
echo "ifb4eth0 bandwidth ${DLSpeedMbps}mbit rtt ${irtt}ms" >> $CS_PATH/spd.curr

#Logs
printf "\n\n"
{
printf "    Network Analysis: --->   Download: %sMbps(Max) %sMbps(rank 2) -> %sMbps(%s%%)    Upload: %sMbps(Max) %sMbps(rank 2) -> %sMbps(%s%%)" "$maxDLMbps" "$r2DLMbps" "$DLSpeedMbps" "$ibw_alloc" "$maxULMbps" "$r2ULMbps" "$ULSpeedMbps" "$ebw_alloc"
printf "\n    SpeedTest Result: --->   Download: %sMbps    Upload: %sMbps    Latency: %sms" "$spdDL" "$spdUL" "$iping" 
printf "\n"
} | tee -a "$CS_PATH/cake-ss.log"
printf "\n\nUpdated CAKE Settings:\n" 
tc qdisc | grep "eth0 root" | grep -oE 'dev.*' | sed 's/^/                      --->   /'
printf "\n\nCake-SpeedSync completed successfully!\n\n\n"

#Store logs for the last 7 runs only (tail -24)
tail -24 "$CS_PATH/cake-ss.log" > "$CS_PATH/temp.log" && mv "$CS_PATH/temp.log" "$CS_PATH/cake-ss.log" && chmod 666 "$CS_PATH/cake-ss.log"
