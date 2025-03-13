# MERLIN-dyn-tc-cake
Dynamic bandwidth control for CAKE QoS based of Ookla SpeedTest (CLI) - For ASUS router running MERLIN firmware.

Uses diffserv4 for traffic prioritization (Highest to Lowest Priority):
1.  Voice - VoIP, Gaming - lowest latency (processed first)
2.  Video - Streaming (Netflix, Disney, Youtube, etc)
3.  Best Effort - Normal traffic (Web browsing) (default category)
4.  Bulk - Lowest priority (downloads, torrents, etc) (processed last)

Forces gaming ports to VOICE Tin using iptables. Added this since my ISP strips DSCP tags causing all packets to fall under besteffort. This will make sure game packets are prioritized. Feel free to remove iptable rules from /jffs/scripts/Services-Start

Setup:
1.  Login to your ASUS Router Web UI
2.  Enable JFFS custom scripts and configs (Administration > System)
3.  Enable SSH (LAN Only)
4.  Open CMD and connect to your router via SSH (ssh user@GatewayIP)


Scripts:
1.  /jffs/scripts/dyn-tc-cake.sh
2.  /jffs/scripts/Services-Start
3.  /tmp/home/root/.ashrc
4.  /tmp/home/root/.profile

