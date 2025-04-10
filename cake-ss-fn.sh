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
export CS_PATH="/jffs/scripts/cake-speedsync"

function cs_init () {
   #Run speedtest and apply cake settings
   $CS_PATH/cake-speedsync.sh "$1"

   #Delete cron job to avoid duplicate
   cru d cake-speedsync

   #Re-add cron job
   #Run every 3 hours from 7:00 AM to 11:59 PM and 12 AM to 1 AM"
   cru a cake-speedsync "0 7-23/3,0-1 * * * $CS_PATH/cake-speedsync.sh"   
}

#Enable CAKE for all outgoing (upload) traffic with default value. 
#Temporarily set bandwidt to 100gbit to avoid throttling while speedtest runs. 
#Speed and Latency will update after cake-speedsync runs.
function cs_default_eth0 () {
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
function cs_default_ifb4eth0 () {
   cs_iScheme="$1"
   if [ -z "$cs_iScheme" ]; then
      cs_iScheme="diffserv3"
   fi
   #Enable CAKE with default value. Temporarily set bandwidt to 100gbit to avoid throttling while speedtest runs. Speed and Latency will update after cake-speedsync runs.
   cs_disable_ifb4eth0
   tc qdisc add dev ifb4eth0 root cake bandwidth 100gbit  ${cs_iScheme} dual-dsthost nat nowash ingress no-ack-filter split-gso rtt 100ms noatm overhead 22 mpu 84
}

#This function is used to re-enable CAKE for outgoing traffic with updated settings for the following:
#Prioritization Scheme (i.e diffserv3, diffserv4, besteffort, etc)
#Bandwidth (speed) will be based from network throughput during speedtest but not from the actual speedtest result.
#RTT for upload will be based from google ping test. 
#MPU and Overhead will be retained. This can be changed from the WebUI or by running cs_upd_qdisc function below
function cs_add_eth0 () {
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
function cs_add_ifb4eth0 () {
   cs_iScheme="$1"
   cs_Speed="$2"
   cs_RTT="$3"
   cs_Overhead="$4"
   cs_MPU="$5"
   cs_disable_ifb4eth0
   tc qdisc add dev ifb4eth0 root cake ${cs_Speed} ${cs_iScheme} dual-dsthost nat nowash ingress no-ack-filter split-gso ${cs_RTT} noatm ${cs_Overhead} ${cs_MPU}
}

function cs_disable_eth0 () {
   tc qdisc del dev eth0 root 2>/dev/null
}

function cs_disable_ifb4eth0 () {
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
function cs_upd_qdisc () {
   cs_cake_intf="$1"
   cs_cake_parm="$2"
   tc qdisc change dev ${cs_cake_intf} root cake ${cs_cake_parm}
}

#When bandwidth is set to Automatic in web ui, set bandwidth to 100gbit instead of unlimited for format consistency
function cs_reset_bandwidth () {
   cs_intfc="$1"
   qdisc=$(tc qdisc show dev "$cs_intfc" root | grep -oE "unlimited")
   if [ $(cs_check_null "$qdisc") -ne 0 ]; then
      cs_upd_qdisc "$cs_intfc" "bandwidth 100gbit"   
   fi
}

#Get qdisc parameter
#Initial code allows checking of scheme, bandwidth, rtt, mpu and overhead.
function cs_get_qdisc () {
   cs_intfc="$1"
   cs_q_parm="$2"
   cs_ret_str=""

   case "$cs_q_parm" in 
      scheme) 
         cs_ret_str=$(tc qdisc show dev "$cs_intfc" root | grep cake | grep -oE "diffserv([3,4,8])?|besteffort")
         ;;
      bandwidth) 
         cs_ret_str=$(tc qdisc show dev "$cs_intfc" root | grep cake | grep -oE "bandwidth\s[0-9]+[a-zA-Z]{3,4}|unlimited")
         if [ "$cs_ret_str" == "unlimited" ]; then
            cs_reset_bandwidth "$cs_intfc"
            cs_ret_str=$(tc qdisc show dev "$cs_intfc" root | grep cake | grep -oE "bandwidth\s[0-9]+[a-zA-Z]{3,4}|unlimited") #rerun
         fi
         ;;
      rtt)
         cs_ret_str=$(tc qdisc show dev "$cs_intfc" root | grep cake | grep -oE "rtt\s[0-9]+ms")
         ;;      
      mpu)
         cs_ret_str=$(tc qdisc show dev "$cs_intfc" root | grep cake | grep -oE "mpu\s[0-9]+")
         ;;
      overhead)
         cs_ret_str=$(tc qdisc show dev "$cs_intfc" root | grep cake | grep -oE "overhead\s[0-9]+")
         ;;
      *) 
         logger "Please check cs_get_qdisc function. Unable to retrieve ${cs_q_parm}."
         exit 1
         ;;
   esac

   echo $cs_ret_str
}

#Re-apply settings - This will be called every time nat restarts to apply the new mpu and overhead only
function cs_apply_mpu_ovh () {
   logger "Re-applying CAKE with new mpu and overhead from web ui"
   #Get Scheme, bandwidth and rtt before mpu and overhead were changed in router's web ui
   cs_cf_eScheme=$(cat $CS_PATH/cake.cfg | grep -oE "^eth0.*" | awk '{print $2}')
   cs_cf_iScheme=$(cat $CS_PATH/cake.cfg | grep -oE "^ifb4eth0.*" | awk '{print $2}')
   
   set -- $(cat $CS_PATH/spd.curr | grep -oE "^eth0.*" | awk '{print $1, $2, $3, $4, $5}');
   cs_cr_eSpd="$2 $3"
   cs_cr_eRtt="$4 $5"
   
   set -- $(cat $CS_PATH/spd.curr | grep -oE "^ifb4eth0.*" | awk '{print $1, $2, $3, $4, $5}')
   cs_cr_iSpd="$2 $3"
   cs_cr_iRtt="$4 $5"

   #Get new mpu and overhead
   cs_q_empu=$(cs_get_qdisc "eth0" "mpu")
   cs_q_eovh=$(cs_get_qdisc "eth0" "overhead")
   
   cs_q_impu=$(cs_get_qdisc "ifb4eth0" "mpu")
   cs_q_iovh=$(cs_get_qdisc "ifb4eth0" "overhead")
   
   #Validate parameters
   cs_ret_cd="0"
   cs_tparm="scheme"
   if [ $(cs_validate_tc_parm "$cs_tparm" "$cs_cf_eScheme") -ne 0 ]; then 
      logger "eth0 - Invalid ${cs_tparm}: ${cs_cf_eScheme}"
      cs_ret_cd="1"
   elif [ $(cs_validate_tc_parm "$cs_tparm" "$cs_cf_iScheme") -ne 0 ]; then 
      logger "ifb4eth0 - Invalid ${cs_tparm}: ${cs_cf_iScheme}"
      cs_ret_cd="1"
   fi 
   cs_tparm="bandwidth"
   if [ $(cs_validate_tc_parm "$cs_tparm" "$cs_cr_eSpd") -eq 1 ]; then 
      logger "eth0 - Invalid ${cs_tparm}: ${cs_cr_eSpd}"
      cs_ret_cd="1"
   elif [ $(cs_validate_tc_parm "$cs_tparm" "$cs_cr_iSpd") -eq 1 ]; then 
      logger "ifb4eth0 - Invalid ${cs_tparm}: ${cs_cr_iSpd}"
      cs_ret_cd="1"
   fi 
   cs_tparm="rtt"
   if [ $(cs_validate_tc_parm "$cs_tparm" "$cs_cr_eRtt") -eq 1 ]; then 
      logger "eth0 - Invalid ${cs_tparm}: ${cs_cr_eRtt}"
      cs_ret_cd="1"
   elif [ $(cs_validate_tc_parm "$cs_tparm" "$cs_cr_iRtt") -eq 1 ]; then 
      logger "ifb4eth0 - Invalid ${cs_tparm}: ${cs_cr_iRtt}"
      cs_ret_cd="1"
   fi 
   cs_tparm="overhead"
   if [ $(cs_validate_tc_parm "$cs_tparm" "$cs_q_eovh") -eq 1 ]; then 
      logger "eth0 - Invalid ${cs_tparm}: ${cs_q_eovh}"
      cs_ret_cd="1"
   elif [ $(cs_validate_tc_parm "$cs_tparm" "$cs_q_iovh") -eq 1 ]; then 
      logger "ifb4eth0 - Invalid ${cs_tparm}: ${cs_q_iovh}"
      cs_ret_cd="1"
   fi 
   cs_tparm="mpu"
   if [ $(cs_validate_tc_parm "$cs_tparm" "$cs_q_empu") -eq 1 ]; then 
      logger "eth0 - Invalid ${cs_tparm}: ${cs_q_empu}"
      cs_ret_cd="1"
   elif [ $(cs_validate_tc_parm "$cs_tparm" "$cs_q_impu") -eq 1 ]; then 
      logger "ifb4eth0 - Invalid ${cs_tparm}: ${cs_q_impu}"
      cs_ret_cd="1"
   fi 

   if [ "$cs_ret_cd" -eq 1 ]; then
      exit 1
   fi

   #Re-apply settings
   cs_add_eth0 "$cs_cf_eScheme" "$cs_cr_eSpd" "$cs_cr_eRtt" "$cs_q_eovh" "$cs_q_empu"
   cs_add_ifb4eth0 "$cs_cf_iScheme" "$cs_cr_iSpd" "$cs_cr_iRtt" "$cs_q_iovh" "$cs_q_impu"
}

#Validates tc qdisc parameter
#Initial code allows checking of scheme, bandwidth, rtt, mpu and overhead.
function cs_validate_tc_parm () {
   cs_tc_parm="$1"
   cs_tc_val="$2"
   
   case "$cs_tc_parm" in 
      scheme) 
         case "$cs_tc_val" in
            diffserv|diffserv3|diffserv4|diffserv8|besteffort)
               echo "0"
               ;;
            *) 
               echo "1"
               ;;
         esac
         ;;
      bandwidth) 
         cs_chk=$(echo "$cs_tc_val" | grep -oE "^bandwidth\s[0-9]+[a-zA-Z]{3,4}")
         echo "$(cs_check_null "$cs_chk")"
         ;;
      rtt)
         cs_chk=$(echo "$cs_tc_val" | grep -oE "^rtt\s[0-9]+ms")
            echo "$(cs_check_null "$cs_chk")"
         ;;      
      mpu)
         if [ cs_check_null "$cs_tc_val" -eq 0 ]; then
            cs_chk=$(echo "$cs_tc_val" | grep -oE "^mpu\s[0-9]+")
            echo "$(cs_check_null "$cs_chk")"      
         else 
            echo "0"
         fi         
         ;;
      overhead)
         if [ cs_check_null "$cs_tc_val" -eq 0 ]; then
            cs_chk=$(echo "$cs_tc_val" | grep -oE "^overhead\s[0-9]+")
            echo "$(cs_check_null "$cs_chk")"
         else 
            echo "0"
         fi
         ;;
      *) 
         echo 1
         ;;
   esac

}

#Checks passed string if null. 
#Passed string will be trimmed first before checking
function cs_check_null () {
   cs_str_chk=$(cs_trim "$1") 
   if [ -n "$cs_str_chk" ]; then
      echo "0"
   else
      echo "1"
   fi
}

function cs_pad_text () {
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
function cs_status () {
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

   cs_dyntclog=$(cat $CS_PATH/cake-ss.log | tail -4)
   echo "$cs_dyntclog"
   printf "\n\n"
}