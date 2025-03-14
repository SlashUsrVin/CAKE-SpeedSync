# MERLIN-dyn-tc-cake - For ASUS router running MERLIN firmware. 

Dynamic bandwidth control for CAKE QoS based of Ookla SpeedTest (CLI). This will make CAKE adapts to ISP Speed fluctuations and minimizes bufferbloat. 

By default, speedtest and dynamic updates will occur every 2 hours from 7:00 AM to 11:00 PM feel free to update the cron entry in /jffs/scripts/services-start after installation.

Forces gaming ports to VOICE Tin using iptables. This is needed since some ISPs (like mine) strips DSCP tags causing all packets to fall under besteffort. This rules ensures game packets are prioritized. Feel free to remove iptable rules from /jffs/scripts/Services-Start if your packets are being tagged correctly.

Uses diffserv4 for traffic prioritization (Highest to Lowest Priority):
1.  Voice - VoIP, Gaming - lowest latency (processed first)
2.  Video - Streaming (Netflix, Disney, Youtube, etc)
3.  Best Effort - Normal traffic (Web browsing) (default category)
4.  Bulk - Lowest priority (downloads, torrents, etc) (processed last)

Tested on ASUS GT-AX11000 Pro

Dependencies:
1.  ASUS Router running on the latest MERLIN firmware with custom script support and CAKE feature

Installation:
1.  Login to your ASUS Router Web UI
2.  Enable JFFS custom scripts and configs (Administration > System)
3.  Enable SSH (LAN Only)
4.  Open CMD and connect to your router via SSH (ssh user@GatewayIP)
5.  Run syntax:
    curl -fsSL "https://raw.githubusercontent.com/mvin321/MERLIN-dyn-tc-cake/main/install.sh" | sh
6.  Once complete, reboot router manually.
    
Scripts:
1.  /jffs/scripts/dyn-tc-cake.sh     -->   Main Script. Disable CAKE, Runs ookla speedtest and re-apply cake with updated bandwidth
2.  /jffs/scripts/Services-Start     -->   Script to re-apply iptable rules, re-set cron job, re-apply cake when router reboots 
3.  /jffs/scripts/dtc-functions.sh   -->   Not required, function to display status: iptable rules for DSCP, active and expected cake settings, active and expected crontab entry for dyn-tc-cake
4.  /tmp/home/root/.ashrc            -->   Re-activates dtc-functions.sh on user login (ssh)
5.  /tmp/home/root/.profile          -->   Auto display status on user login (ssh)
