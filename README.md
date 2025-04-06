# MERLIN-cake-speedsync - For ASUS router running MERLIN firmware. 

Adjusts CAKE QoS bandwidth and latency periodically based on network throughput and ping tests. This allows CAKE to better adapt to network congestion and ISP speed fluctuations.  

### __DEPENDENCIES:__  
1. ASUS Router running on the latest MERLIN firmware. (https://sourceforge.net/projects/asuswrt-merlin/files/)  
2. Must have custom script support and built in CAKE QoS feature.  

### __WARNING:__  
1. During installation, /jffs/scripts/services-start will be replaced. If you have added any custom commands, you can find a backup of the original file in /jffs/scripts/cake-speedsync/. 
2. MERLIN-CAKE's default Queueing Discpline are diffserv3 for outbound (eth0) and besteffort for inbound (ifb4eth0) traffic. This program will default to diffserv4 for both. You can change this via the provided /jffs/scripts/cake-speedsync/cake.cfg if you only want the speed sync functionality.

### __INSTALLATION:__  
1. Ensure router is running on MERLIN firmware (check DEPENDENCIES section above)
2. Login to your ASUS Router Web UI 
3. Enable JFFS custom scripts and configs (Administration > System)  
4. Enable SSH (LAN Only)  
5. Open CMD or PowerShell and connect to your router via SSH (example: ssh admin@192.168.1.1)  
6. Run syntax:            
___```curl -fsSL "https://raw.githubusercontent.com/mvin321/MERLIN-cake-speedsync/main/install.sh" | sh -s -- main```___  
7. Once complete, reboot router manually.  

### __HOW IT WORKS:__  
1. When the script runs, CAKE bandwidth will be udpated to 100gbit to avoid throttling while the test is running.  
2. Ookla SpeedTest (CLI) will execute in the background to generate load in the network. The script will then monitor the TX and RX rates via /proc/net/dev to get the maximum TX and RX rate. This process takes about 20 seconds and will only wait a maximum of 1 minute before quiting.  
3. Once the maximum TX (upload) and RX (download) speed have been identified. 95% of this rate will be set as CAKE's bandwidth.  
4. Bandwidth from the SpeedTest result are not used, only the latency will be used as basis for rtt for CAKE ifb4eth0 (inbound)  
5. A ping test to Google (8.8.8.8) will also be executed which will be used as basis for rtt for CAKE eth0 (outbound).  
6. For eth0, rtt is set based on the median value from the google ping test and rounded to the nearest 5ms increments (min 5ms max 100ms)  
7. For ifb4eth0, rtt is set based on the speedtest latency and rounded to the nearest 5ms increments. (min 5ms max 100ms)  
8. Value for overhead and mpu will be retained if set via the web ui. This can also be changed using the provided function (cs_upd_qdisc)  
9. Speedtest and dynamic updates will occur every 3 hours from 7:00 AM to 1:00 AM feel free to update the cron entry in /jffs/scripts/cake-speedsync/cake-ss-fn.sh (cs_init) after installation. Note that these steps are also performed every time the router reboots.  
