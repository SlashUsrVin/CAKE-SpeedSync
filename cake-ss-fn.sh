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
   /jffs/scripts/cake-speedsync/cake-speedsync.sh

   #Delete cron job to avoid duplicate
   cru d cake-speedsync

   #Re-add cron job
   #Run every 3 hours from 7:00 AM to 11:59 PM and 12 AM to 1 AM"
   cru a cake-speedsync "0 7-23/3,0-1 * * * /jffs/scripts/cake-speedsync/cake-speedsync.sh"   
}

cs_enable_default () {
   cs_eScheme="$1"
   cs_iScheme="$2"
   cs_default_eth0 "$cs_eScheme"
   cs_default_ifb4eth0 "$cs_iScheme"
}

cs_default_eth0 () {
   cs_eScheme="$1"
   if [ -z "$cs_eScheme" ]; then
      cs_eScheme="diffserv3"
   fi
   #Enable with default value. Speed and Latency will update once cake-speedsync runs
   cs_disable_eth0
   tc qdisc add dev eth0 root cake bandwidth 100gbit ${cs_eScheme} dual-srchost nat nowash no-ack-filter split-gso rtt 50ms noatm overhead 54 mpu 64
}

cs_default_ifb4eth0 () {
   cs_iScheme="$1"
   if [ -z "$cs_iScheme" ]; then
      cs_iScheme="diffserv3"
   fi
   #Enable with default value. Speed and Latency will update once cake-speedsync runs
   cs_disable_ifb4eth0
   tc qdisc add dev ifb4eth0 root cake bandwidth 100gbit  ${cs_iScheme} dual-dsthost nat wash ingress no-ack-filter split-gso rtt 50ms noatm overhead 54 mpu 64
}

cs_add_eth0 () {
   cs_eScheme="$1"
   cs_Speed="$2"
   cs_RTT="$3"
   cs_Overhead="$4"
   cs_MPU="$5"
   cs_disable_eth0
   tc qdisc add dev eth0 root cake ${cs_Speed} ${cs_eScheme} dual-srchost nat nowash no-ack-filter split-gso ${cs_RTT} noatm ${cs_Overhead} ${cs_MPU}
}

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

function cs_net_dev_get () {
   cs_intfc="$1"
   if [ "$cs_intfc" == "eth0" ]; then
      cs_bytes=$(grep -w "$cs_intfc:" /proc/net/dev | awk '{print $10}') #get TX rate for sent packets (eth0)
   else 
      cs_bytes=$(grep -w "$cs_intfc:" /proc/net/dev | awk '{print $2}')  #get RX rate for received packets (ifb4eth0)
   fi
   echo "${cs_bytes:-0}"
}

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

function cs_to_mbit () {
   cs_bytes="$1"
   cs_mbits=$(((cs_bytes * 8) / 1000000))
   echo "$cs_mbits"
}

cs_upd_qdisc () {
   cs_cake_intf="$1"
   cs_cake_parm="$2"
   tc qdisc change dev ${cs_cake_intf} root cake ${cs_cake_parm}
}

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

cs_chk_ip () {
   cs_pvalue=$1
   cs_ip=$(echo "$cs_pvalue" | grep -oE '^192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
   if [ -z "$cs_ip" ]; then
      echo 0
   else
      echo 1
   fi
}

cs_chk_port () {
   cs_pvalue=$1
   set -- $(echo "$cs_pvalue" | awk -F: '{print $1,$2,$3}'); cs_p1="$1"; cs_p2="$2"; cs_p3="$3"

   if [ -n "$cs_p3" ]; then
      echo 0 #wrong port range format
      return
   fi

   for cs_port in "$cs_p1" "$cs_p2"; do
      cs_pchk=$(echo $cs_port | grep -oE '^[0-9]{1,5}$')
      if [ -z "$cs_pchk" ]; then
         echo 0 #wrong format
         return
      fi

      if [ $cs_pchk -le 0 ] || [ $cs_pchk -ge 65536 ]; then
         echo 0 #wrong port value
         return
      fi
   done
   
   echo 1
}

cs_chk_proto () {
   cs_pvalue=$1

   case "$cs_pvalue" in 
      tcp|TCP|udp|UDP) echo 1;;
      *) echo 0;;
   esac
}

cs_chk_prio () {
   cs_pvalue=$1
   
   case "$cs_pvalue" in
      1|2|3|4) echo 1 ;; 
      *) echo 0 ;;  
   esac      
}

cs_qos_udp () {
   cs_proto="udp"
   cs_port=$1
   cs_prio=$2
   cs_ip=$3

   cs_pkt_qos $cs_ip $cs_port $cs_prio $cs_proto
}

cs_qos_tcp () {
   cs_proto="tcp"
   cs_port=$1
   cs_prio=$2
   cs_ip=$3

   cs_pkt_qos $cs_ip $cs_port $cs_prio $cs_proto   
}

cs_qos_rfr () {
   awk '{print $1, $2, $3, $4}' /jffs/scripts/cake-speedsync/qosports 2>/dev/null | while read -r cs_ip cs_port cs_tag cs_protocol; do
   cs_pkt_qos $cs_ip $cs_port $cs_tag $cs_protocol; done 

}

cs_pkt_qos () {
   cs_ip=$1
   cs_port=$2

   if [ -z "$3" ]; then
      cs_dscptag="EF" #If $2 is blank set highest priority
   else
      case "$3" in
         1) cs_dscptag="EF" ;;  #Highest
         2) cs_dscptag="CS5" ;; #High
         3) cs_dscptag="CS0" ;; #Normal
         4) cs_dscptag="CS1" ;; #Low
         *) cs_dscptag="EF" ;;  
      esac
   fi
   
   if [ -z "$4" ]; then
      cs_proto="udp"
   else
      cs_proto="$4"
   fi

   cs_cmd="iptables -t mangle -%s %s -p $cs_proto -%s $cs_ip --%s $cs_port -j DSCP --set-dscp-class $cs_dscptag"
   
   #Remove first if existing then re-apply rule - prevent duplicate entries and cluttering iptables
   for cs_mode in "D" "A"; do
      for cs_chain in "FORWARD" "POSTROUTING"; do
         case "$cs_chain" in
            FORWARD) 
               cs_pmatch="dport"
               cs_imatch="d"
               ;;
            POSTROUTING)
               cs_pmatch="sport"
               cs_imatch="s"
               ;;
         esac

         if [[ "$cs_mode" == "D" ]]; then
            eval $(printf "$cs_cmd 2>/dev/null" "$cs_mode" "$cs_chain" "$cs_imatch" "$cs_pmatch")
         else
            eval $(printf "$cs_cmd" "$cs_mode" "$cs_chain" "$cs_imatch" "$cs_pmatch")
         fi         
      done
   done

   #Record ports for re-applying iptables on reboot
   rm -f /jffs/scripts/cake-speedsync/qosports
   iptables -t mangle -S | awk '/PREROUTING/ && /DSCP/ {print $4, $10, $NF, $6}' | while read -r cs_xip cs_xport cs_xhextag cs_xproto; do
      case "$cs_xhextag" in
         0x2e) cs_xtag="1";;
         0x28) cs_xtag="2";;
         0x00) cs_xtag="3";;
         0x08) cs_xtag="4";;
         *) cs_xtag="3";;
      esac
      echo "$cs_ip $cs_xport $cs_xtag $cs_xproto" >> /jffs/scripts/cake-speedsync/qosports; done
   
}

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
   printf "$cs_dyntclog"
   printf "\n\n"
}