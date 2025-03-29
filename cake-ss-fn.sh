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
   eScheme="$1"
   iScheme="$2"
   cs_enable_eth0 "$eScheme"
   cs_enable_ifb4eth0 "$iScheme"
}

cs_enable_eth0 () {
   eScheme="$1"
   if [ -z "$eScheme" ]; then
      eScheme="diffserv4"
   fi
   #Enable with default value. Speed and Latency will update once cake-speedsync runs
   cs_disable_eth0
   tc qdisc replace dev eth0 root cake bandwidth 2gbit ${eScheme} dual-srchost nat nowash no-ack-filter split-gso rtt 25ms noatm overhead 44 mpu 84
}

cs_enable_ifb4eth0 () {
   iScheme="$1"
   if [ -z "$iScheme" ]; then
      iScheme="diffserv4"
   fi
   #Enable with default value. Speed and Latency will update once cake-speedsync runs
   cs_disable_ifb4eth0
   tc qdisc replace dev ifb4eth0 root cake bandwidth 2gbit ${iScheme} dual-dsthost nat wash ingress no-ack-filter split-gso rtt 25ms noatm overhead 44 mpu 84
}

cs_disable_eth0 () {
   tc qdisc del dev eth0 root 2>/dev/null
}

cs_disable_ifb4eth0 () {
   tc qdisc del dev ifb4eth0 root 2>/dev/null
}

cs_upd_qdisc () {
   cake_intf="$1"
   cake_parm="$2"
   tc qdisc change dev ${cake_intf} root cake ${cake_parm}
}

cs_get_qdisc () {
   intfc=$1
   if [ -z "$1" ]; then
      echo ""
   else
      tcqparm=$(tc qdisc show dev "$intfc" root)
      tcqparmpart=$(echo "$tcqparm" | grep -oE 'bandwidth\s(unlimited)?([0-9]+[a-zA-Z]{3,4})?\s[a-zA-Z]+([0-9]+)?')
      set -- $(echo "$tcqparmpart" | awk '{print $1, $2, $3}'); spd="$1 $2"; sch="$3"
      rtt=$(echo "$tcqparm" | grep -oE 'rtt\s[0-9]+ms')
      mpu=$(echo "$tcqparm" | grep -oE 'mpu\s[0-9]+')
      ovh=$(echo "$tcqparm" |grep -oE 'overhead\s[0-9]+')

      echo $spd $sch $rtt $mpu $ovh
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
   pvalue=$1
   ip=$(echo "$pvalue" | grep -oE '^192\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
   if [ -z "$ip" ]; then
      echo 0
   else
      echo 1
   fi
}

cs_chk_port () {
   pvalue=$1
   set -- $(echo "$pvalue" | awk -F: '{print $1,$2,$3}'); p1="$1"; p2="$2"; p3="$3"

   if [ -n "$p3" ]; then
      echo 0 #wrong port range format
      return
   fi

   for port in "$p1" "$p2"; do
      pchk=$(echo $port | grep -oE '^[0-9]{1,5}$')
      if [ -z "$pchk" ]; then
         echo 0 #wrong format
         return
      fi

      if [ $pchk -le 0 ] || [ $pchk -ge 65536 ]; then
         echo 0 #wrong port value
         return
      fi
   done
   
   echo 1
}

cs_chk_proto () {
   pvalue=$1

   case "$pvalue" in 
      tcp|TCP|udp|UDP) echo 1;;
      *) echo 0;;
   esac
}

cs_chk_prio () {
   pvalue=$1
   
   case "$pvalue" in
      1|2|3|4) echo 1 ;; 
      *) echo 0 ;;  
   esac      
}

cs_qos_udp () {
   $proto="udp"
   $port=$1
   $prio=$2
   $ip=$3

   cs_pkt_qos $ip $port $prio $proto
}

cs_qos_tcp () {
   $proto="tcp"
   $port=$1
   $prio=$2
   $ip=$3

   cs_pkt_qos $ip $port $prio $proto   
}

cs_qos_rfr () {
   awk '{print $1, $2, $3, $4}' /jffs/scripts/cake-speedsync/qosports 2>/dev/null | while read -r ip port tag protocol; do
   cs_pkt_qos $ip $port $tag $protocol; done 

}

cs_pkt_qos () {
   ip=$1
   port=$2

   if [ -z "$3" ]; then
      dscptag="EF" #If $2 is blank set highest priority
   else
      case "$3" in
         1) dscptag="EF" ;;  #Highest
         2) dscptag="CS5" ;; #High
         3) dscptag="CS0" ;; #Normal
         4) dscptag="CS1" ;; #Low
         *) dscptag="EF" ;;  
      esac
   fi
   
   if [ -z "$4" ]; then
      proto="udp"
   else
      proto="$4"
   fi

   cmd="iptables -t mangle -%s %s -p $proto -%s $ip --%s $port -j DSCP --set-dscp-class $dscptag"
   
   #Remove first if existing then re-apply rule - prevent duplicate entries and cluttering iptables
   for mode in "D" "A"; do
      for chain in "FORWARD" "POSTROUTING"; do
         case "$chain" in
            FORWARD) 
               pmatch="dport"
               imatch="d"
               ;;
            POSTROUTING)
               pmatch="sport"
               imatch="s"
               ;;
         esac

         if [[ "$mode" == "D" ]]; then
            eval $(printf "$cmd 2>/dev/null" "$mode" "$chain" "$imatch" "$pmatch")
         else
            eval $(printf "$cmd" "$mode" "$chain" "$imatch" "$pmatch")
         fi         
      done
   done

   #Record ports for re-applying iptables on reboot
   rm -f /jffs/scripts/cake-speedsync/qosports
   iptables -t mangle -S | awk '/PREROUTING/ && /DSCP/ {print $4, $10, $NF, $6}' | while read -r xip xport xhextag xproto; do
      case "$xhextag" in
         0x2e) xtag="1";;
         0x28) xtag="2";;
         0x00) xtag="3";;
         0x08) xtag="4";;
         *) xtag="3";;
      esac
      echo "$ip $xport $xtag $xproto" >> /jffs/scripts/cake-speedsync/qosports; done
   
}

cs_status () {
   echo -e "\n[DSCP RULES]"
   echo  "    Active DSCP Rule:"

   ipt="$(iptables -t mangle -L --line-numbers | grep -E "Chain|DSCP")"

   cs_pad_text "$ipt" ""

   printf "\n\n[CRON JOB - SCHEDULE - Make sure cake is re-adjusted every n hours]"
   printf  "\n   Active Cron Entry:\n"

   cronj=$(crontab -l | grep cake-speedsync.sh)

   cs_pad_text "$cronj" "WARNING: Crontab entry is missing. Run /jffs/scripts/services-start and check again"

   printf "\n\n[CAKE SETTINGS]"
   printf  "\n Active CAKE Setting:\n"

   allqdisc=$(tc qdisc | grep "eth0 root")

   cs_pad_text "" "$allqdisc" 
   
   cakeqdisc=$(tc qdisc | grep cake)

   if [ -z "$cakeqdisc" ]; then
      cs_pad_text "" "WARNING: CAKE is not currently active. Run /jffs/scripts/services-start or /jffs/scripts/cake-speedsync/cake-speedsync.sh" 
   fi
   
   printf "\n\n      CAKE-SpeedSync: --->   Last Run: "

   dyntclog=$(cat /jffs/scripts/cake-speedsync/cake-ss.log | tail -3)
   printf "$dyntclog"
   printf "\n\n"
}