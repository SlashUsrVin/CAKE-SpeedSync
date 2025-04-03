#!/bin/sh
# CAKE-SpeedSync - Related functions
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

cs_init () {
   #Run speedtest and apply cake settings
   /jffs/scripts/cake-speedsync/cake-speedsync.sh "$1"

   #Delete cron job to avoid duplicate
   cru d cake-speedsync

   #Re-add cron job
   #Run every 3 hours from 7:00 AM to 11:59 PM and 12 AM to 1 AM"
   cru a cake-speedsync "0 7-23/3,0-1 * * * /jffs/scripts/cake-speedsync/cake-speedsync.sh"   
}

#Enable CAKE for all outgoing (upload) traffic with default value. 
#Temporarily set bandwidt to 100gbit to avoid throttling while speedtest runs. 
#Speed and Latency will update after cake-speedsync runs.
cs_default_eth0 () {
   cs_eScheme="$1"
   if [ -z "$cs_eScheme" ]; then
      cs_eScheme="diffserv3"
   fi
   cs_disable_eth0 #Delete first then re-add
   tc qdisc add dev eth0 root cake bandwidth 100gbit ${cs_eScheme} dual-srchost nat nowash no-ack-filter split-gso rtt 100ms noatm overhead 22 mpu 84
}

#Enable CAKE for all incoming (download) traffic with default value. 
#Temporarily set bandwidt to 100gbit to avoid throttling while speedtest runs. 
#Speed and Latency will update after cake-speedsync runs.
cs_default_ifb4eth0 () {
   cs_iScheme="$1"
   if [ -z "$cs_iScheme" ]; then
      cs_iScheme="diffserv3"
   fi
   #Enable CAKE with default value. Temporarily set bandwidt to 100gbit to avoid throttling while speedtest runs. Speed and Latency will update after cake-speedsync runs.
   cs_disable_ifb4eth0
   tc qdisc add dev ifb4eth0 root cake bandwidth 100gbit  ${cs_iScheme} dual-dsthost nat wash ingress no-ack-filter split-gso rtt 100ms noatm overhead 22 mpu 84
}

#This function is used to re-enable CAKE for outgoing traffic with updated settings for the following:
#Prioritization Scheme (i.e diffserv3, diffserv4, besteffort, etc)
#Bandwidth (speed) will be based from network throughput during speedtest but not from the actual speedtest result.
#RTT for upload will be based from google ping test. 
#MPU and Overhead will be retained. This can be changed from the WebUI or by running cs_upd_qdisc function below
cs_add_eth0 () {
   cs_eScheme="$1"
   cs_Speed="$2"
   cs_RTT="$3"
   cs_Overhead="$4"
   cs_MPU="$5"
   cs_disable_eth0
   tc qdisc add dev eth0 root cake ${cs_Speed} ${cs_eScheme} dual-srchost nat nowash no-ack-filter split-gso ${cs_RTT} noatm ${cs_Overhead} ${cs_MPU}
}

#This function is used to re-enable CAKE for outgoing traffic with updated settings for the following:
#Prioritization Scheme (i.e diffserv3, diffserv4, besteffort, etc)
#Bandwidth (speed) will be based from network throughput during speedtest but not from the actual speedtest result.
#RTT for upload will be based from the latency of SpeedTest (ookla)
#MPU and Overhead will be retained. This can be changed from the WebUI or by running cs_upd_qdisc function below
cs_add_ifb4eth0 () {
   cs_iScheme="$1"
   cs_Speed="$2"
   cs_RTT="$3"
   cs_Overhead="$4"
   cs_MPU="$5"
   cs_disable_ifb4eth0
   tc qdisc add dev ifb4eth0 root cake ${cs_Speed} ${cs_iScheme} dual-dsthost nat wash ingress no-ack-filter split-gso ${cs_RTT} noatm ${cs_Overhead} ${cs_MPU}
}

cs_disable_eth0 () {
   tc qdisc del dev eth0 root 2>/dev/null
}

cs_disable_ifb4eth0 () {
   tc qdisc del dev ifb4eth0 root 2>/dev/null
}

function cs_trim () {
    cs_str="$1"
    cs_trimmed=$(echo "$cs_str" | awk '{$0=$0;print}')
    echo "$cs_trimmed"
}

#This function will check current total TX and RX in bytes
#This is only useful when computing TX/RX speed 
function cs_net_dev_get () {
   cs_intfc="$1"
   if [ "$cs_intfc" == "eth0" ]; then
      cs_bytes=$(grep -w "$cs_intfc:" /proc/net/dev | awk '{print $10}') #get TX rate for sent packets (eth0)
   else 
      cs_bytes=$(grep -w "$cs_intfc:" /proc/net/dev | awk '{print $2}')  #get RX rate for received packets (ifb4eth0)
   fi
   echo "${cs_bytes:-0}"
}

#Show current TX/RX speed in Mbps for 30 seconds
function cs_net_dev_show () {
   cs_ctr=0
   cs_maxwait=30

   while [ "$cs_ctr" -lt "$cs_maxwait" ]; do
      cs_rx=$(cs_net_dev_get "ifb4eth0")
      cs_tx=$(cs_net_dev_get "eth0")

      if [ -n "$cs_prevrx" ] || [ -n "$cs_prevtx" ]; then
         cs_rxBps=$(expr "$cs_rx" - "$cs_prevrx")
         cs_txBps=$(expr "$cs_tx" - "$cs_prevtx")

         echo "$(date)  -->  Download: $(cs_to_mbit ${cs_rxBps})Mbps    Upload: $(cs_to_mbit ${cs_txBps})Mbps"
      fi

      cs_prevrx=$cs_rx
      cs_prevtx=$cs_tx
      sleep 1
      cs_ctr=$((cs_ctr + 1))
   done
}

#Convert bytes to Mbps
#bytes is the main unit of measure
function cs_to_mbit () {
   cs_bytes="$1"
   cs_mbits=$(((cs_bytes * 8) / 1000000))
   echo "$cs_mbits"
}

#Update CAKE parameters. This can only update parameters that can be changed in place. (i.e bandwidth, mpu, overhead, rtt)
#example: cs_upd_qdisc "eth0" "overhead 19"
#example: cs_upd_qdisc "eth0" "rtt 10ms"
#example: cs_upd_qdisc "eth0" "bandwidth 200mbit"
cs_upd_qdisc () {
   cs_cake_intf="$1"
   cs_cake_parm="$2"
   tc qdisc change dev ${cs_cake_intf} root cake ${cs_cake_parm}
}

#Get current qdisc
cs_get_qdisc () {
   cs_intfc=$1
   if [ -z "$cs_intfc" ]; then
      echo ""
   else
      cs_tcqparm=$(tc qdisc show dev "$cs_intfc" root)
      cs_tcqparmpart=$(echo "$cs_tcqparm" | grep -oE 'bandwidth\s(unlimited)?([0-9]+[a-zA-Z]{3,4})?\s[a-zA-Z]+([0-9]+)?')
      set -- $(echo "$cs_tcqparmpart" | awk '{print $1, $2, $3}'); cs_spd="$1 $2"; cs_sch="$3"
      cs_rtt=$(echo "$cs_tcqparm" | grep -oE 'rtt\s[0-9]+ms')
      cs_mpu=$(echo "$cs_tcqparm" | grep -oE 'mpu\s[0-9]+')
      cs_ovh=$(echo "$cs_tcqparm" | grep -oE 'overhead\s[0-9]+')

      echo $cs_spd $cs_sch $cs_rtt $cs_mpu $cs_ovh
   fi
}

cs_pad_text () {
   if [ -z "$1" ]; then
      echo "$2" | sed 's/^/                      --->   /'
   else
      echo "$1" | sed 's/^/                      --->   /'
   fi
}

#This function can be used to check the following with a single command (cs_status)
#Check active iptables using DSCP tagging
#Check if cronjob for recurring task for CAKE-SpeedSync
#Check last run of CAKE-SpeedSync showing the network througput analysis, Speedtest and Google Ping test
#Check if CAKE is active and current settings
cs_status () {
   echo -e "\n[DSCP RULES]"
   echo  "    Active DSCP Rule:"

   cs_ipt="$(iptables -t mangle -L --line-numbers | grep -E "Chain|DSCP")"

   cs_pad_text "$cs_ipt" ""

   printf "\n\n[CRON JOB - SCHEDULE - Make sure cake is re-adjusted every n hours]"
   printf  "\n   Active Cron Entry:\n"

   cs_cronj=$(crontab -l | grep cake-speedsync.sh)

   cs_pad_text "$cs_cronj" "WARNING: Crontab entry is missing. Run /jffs/scripts/services-start and check again"

   printf "\n\n[CAKE SETTINGS]"
   printf  "\n Active CAKE Setting:\n"

   cs_allqdisc=$(tc qdisc | grep "eth0 root")

   cs_pad_text "" "$cs_allqdisc" 
   
   cs_cakeqdisc=$(tc qdisc | grep cake)

   if [ -z "$cs_cakeqdisc" ]; then
      cs_pad_text "" "WARNING: CAKE is not currently active. Run /jffs/scripts/services-start or /jffs/scripts/cake-speedsync/cake-speedsync.sh" 
   fi
   
   printf "\n\n      CAKE-SpeedSync: --->   Last Run: "

   cs_dyntclog=$(cat /jffs/scripts/cake-speedsync/cake-ss.log | tail -4)
   echo "$cs_dyntclog"
   printf "\n\n"
}