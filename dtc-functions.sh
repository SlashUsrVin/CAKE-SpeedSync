dyntccakestatus () {

                    echo -e "\n[DSCP RULES - Force gaming ports to VOICE Tin"
                    echo "  Default Rule:"
                    echo "                   DSCP       udp  --  *      *       0.0.0.0/0            0.0.0.0/0            udp spts:7000:9000 DSCP set 0x2e"
                    echo "                   DSCP       udp  --  *      *       0.0.0.0/0            0.0.0.0/0            udp dpts:30000:50000 DSCP set 0x2e"
                    echo "                   DSCP       udp  --  *      *       0.0.0.0/0            0.0.0.0/0            udp dpts:30000:50000 DSCP set 0x2e"
                    echo "                   DSCP       udp  --  *      *       0.0.0.0/0            0.0.0.0/0            udp spts:7000:9000 DSCP set 0x2e"

                    echo -e "\n  Active DSCP Rule:"

                    ipt="$(iptables -t mangle -L -v -n | grep DSCP)"

                    checkNULL "$ipt" "WARNING: Rules not setup. If ISP is stripping DSCP tags, all packets will fall under besteffort. Run /jffs/scripts/services-start and check again"

                    echo -e "\n\n[CRON JOB - SCHEDULE - Make sure cake is re-adjusted every n hours]"
                    echo -e "  Default Crontab Entry: (Run every 2 hours from 7 AM to 11 PM"
                    checkNULL "" "0 7-23/2 * * * /jffs/scripts/dyn-tc-cake.sh #dyn-tc-cake#"

                    echo -e "\n  Active Cron Entry: "

                    cronj=$(crontab -l | grep dyn-tc-cake.sh)

                    checkNULL "$cronj" "WARNING: Crontab entry is missing. Run /jffs/scripts/services-start and check again"

                    echo -e "\n\n[CAKE SETTINGS]"
                    echo "  Default Cake Settings:"
                    checkNULL "" "qdisc cake 8010: dev eth0 root refcnt 2 bandwidth \$(DLSpd) diffserv4 dual-srchost nat nowash no-ack-filter split-gso rtt 10ms noatm overhead 54 mpu 88"
                    checkNULL "" "qdisc cake 800f: dev ifb4eth0 root refcnt 2 bandwidth \$(ULSpd) diffserv4 dual-dsthost nat wash ingress no-ack-filter split-gso rtt 10ms noatm overhead 54 mpu 88"

                    echo -e "\n  Active CAKE Setting:"

                    tccake=$(tc qdisc | grep cake)

                    checkNULL "$tccake" "WARNING: CAKE is not currently active. Run services-start or dyn-tc-cake.sh from /jffs/scripts/"

                    echo -e "\n  dyn-tc-cake:"

                    dyntclog=$(cat /jffs/scripts/dyn-tc.log | tail -3)
                    lastrun=$(cat /jffs/scripts/dyn-tc.log | tail -3 | head -1)

                    uploadSpd=$(echo "$dyntclog" | grep -oE 'dev eth0 root .*' | grep -oE '[0-9]+Mbit')
                    downloadSpd=$(echo "$dyntclog" | grep -oE 'dev ifb4eth0 root .*' | grep -oE '[0-9]+Mbit')

                    checkNULL "" "last run: $lastrun upload bandwidth:$uploadSpd download bandwidth:$downloadSpd"
                    echo -e "\n"
                   }


checkNULL () {

              if [ -z "$1" ]; then
                 echo "$2" | sed 's/^/       /'
              else
                 echo "$1" | sed 's/^/       /'
              fi

             }