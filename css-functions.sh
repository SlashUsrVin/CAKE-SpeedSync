css_status () {
   echo -e "\n[DSCP RULES - Force gaming ports to VOICE Tin"
   echo  "  Active DSCP Rule:"

   ipt="$(iptables -t mangle -L -v -n | grep DSCP)"

   css_check_null "$ipt" "WARNING: Rules not setup. If ISP is stripping DSCP tags, all packets will fall under besteffort. Run /jffs/scripts/services-start and check again"

   echo -e "\n\n[CRON JOB - SCHEDULE - Make sure cake is re-adjusted every n hours]"
   echo  "  Active Cron Entry: "

   cronj=$(crontab -l | grep cake-speedsync.sh)

   css_check_null "$cronj" "WARNING: Crontab entry is missing. Run /jffs/scripts/services-start and check again"

   echo -e "\n\n[CAKE SETTINGS]"
   echo  "  Active CAKE Setting:"

   tccake=$(tc qdisc | grep cake)

   css_check_null "$tccake" "WARNING: CAKE is not currently active. Run services-start or cake-speedsync.sh from /jffs/scripts/"

   echo -e "\n  cake-speedsync:"

   dyntclog=$(cat /jffs/scripts/dyn-tc.log | tail -3)
   lastrun=$(cat /jffs/scripts/dyn-tc.log | tail -3 | head -1)

   uploadSpd=$(echo "$dyntclog" | grep -oE 'dev eth0 root .*' | grep -oE '[0-9]+Mbit')
   downloadSpd=$(echo "$dyntclog" | grep -oE 'dev ifb4eth0 root .*' | grep -oE '[0-9]+Mbit')

   css_check_null "" "last run: $lastrun upload bandwidth:$uploadSpd download bandwidth:$downloadSpd"
   echo -e "\n"
}

css_check_null () {
   if [ -z "$1" ]; then
      echo "$2" | sed 's/^/       /'
   else
      echo "$1" | sed 's/^/       /'
   fi
}

css_set_max_qos () {
   pri1="EF" #Highest
   pri2="CS5" #High
   pri3="CS0" #Normal
   pri4="CS1" #Low
   port=$1
   dscptag="$pri1"   
   cmd="iptables -t mangle -%s %s -p udp --%s $port -j DSCP --set-dscp-class $dscptag"
   
   #Remove first if existing then re-apply rule - prevent duplicate entries and cluttering iptables
   for mode in "D" "A"; do
      for chain in "PREROUTING" "POSTROUTING" "OUTPUT"; do
         if [[ "$chain" == "OUTPUT" ]]; then
            match = "sport"
         else
            match = "dport"
         fi

         if [[ "$mode" == "D" ]]; then
            eval $(printf "$cmd 2>/dev/null" "$mode" "$chain" "$match")
         else
            eval $(printf "$cmd" "$mode" "$chain" "$match")
         fi         
      done
   done

   #Record ports for re-applying iptables on reboot
   iptables -t mangle -S | awk '/POSTROUTING/ && /DSCP/ && 0x2e' | grep -oE 'dport [0-9]+(\:[0-9]+)?' | grep -oE '[0-9]+(\:[0-9]+)?' > /jffs/scripts/cake-speedsync/qosports
}