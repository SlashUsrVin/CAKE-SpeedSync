# MERLIN-cake-speedsync - For ASUS router running MERLIN firmware. 
Updates CAKE QoS bandwidth based of the built in Ookla SpeedTest (CLI) for ASUS router running MERLIN firmware. This will make CAKE adapts to ISP Speed fluctuations. 

DISCLAIMER 
I am not a network expert. The information provided here is based on my own research on how packets are handled. Tested on ASUS GT-AX11000 Pro.

HOW IT WORKS
By default CAKE uses diffserv3 for QoS mode when enabled via the web ui. cake-speedsync will force CAKE to use diffserv4 for traffic prioritization. This will separate Voice and Video to separate tins:
    1.  Voice - VoIP, Gaming - lowest latency (processed first)
    2.  Video - Streaming (Netflix, Disney, Youtube, etc)
    3.  Best Effort - Normal traffic (Web browsing) (default category)
    4.  Bulk - Lowest priority (downloads, torrents, etc) (processed last)

An optional function (css_pkt_qos) is also provided to force packets to VOICE Tin using iptables. This is only necessary if your ISP (like mine) strips DSCP tags which will cause all packets to fall under besteffort (normal priority). If that is the case, this fucntion will allow you to force packets to be tagged accordingly. Rules applied using css_pkt_qos will be auto re-applied on reboot.
    --How to run css_pkt_qos: 
    --css_pkt_qos <IP> <port or port:port> <priority> <protocol> 
    --css_pkt_qos 192.168.1.10 50000:70000 1 udp
    -- OR simply css_pkt_qos 192.168.1.10 50000:70000 --> This is the short version, priority will default to 1 and protocol to udp

Speedtest and dynamic updates will occur every 2 hours from 7:00 AM to 11:00 PM feel free to update the cron entry in /jffs/scripts/services-start after installation. Router config resets to default after reboot wiping crontab, tcqdisc and iptable rules (mangle). By updating services-start the config updated by cake-speedsync are re-applied on reboot (waits 30 seconds after reboot before re-applying)

DEPENDENCIES:
    1.  ASUS Router running on the latest MERLIN firmware with custom script support and CAKE feature

INSTALLATION:
    1.  Login to your ASUS Router Web UI
    2.  Enable JFFS custom scripts and configs (Administration > System)
    3.  Enable SSH (LAN Only)
    4.  Open CMD and connect to your router via SSH (ssh user@GatewayIP)
    5.  Run syntax:
        curl -fsSL "https://raw.githubusercontent.com/mvin321/MERLIN-cake-speedsync/main/install.sh" | sh
    6.  Once complete, reboot router manually.
    
SCRIPTS:
    1.  /jffs/scripts/cake-speedsync/cake-speedsync.sh     -->   Main Script. Disable CAKE, Runs ookla speedtest and re-apply cake with updated bandwidth
    2.  /jffs/scripts/Services-Start                       -->   Script to re-apply iptable rules, re-set cron job, re-apply cake when router reboots 
    3.  /jffs/scripts/cake-speedsync/css-functions.sh      -->   
    4.  /tmp/home/root/.ashrc            -->   Re-activates css-functions.sh on user login (ssh)
    5.  /tmp/home/root/.profile          -->   Auto display status on user login (ssh)