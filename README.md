# CAKE-SpeedSync - For ASUS router running MERLIN firmware. 

Adjusts CAKE QoS bandwidth periodically based on network throughput. This allows CAKE to better adapt to network congestion and ISP speed fluctuations.  

### __DEPENDENCIES:__  
1. ASUS Router running on the latest MERLIN firmware. (https://sourceforge.net/projects/asuswrt-merlin/files/)  
2. Must have custom script support and built in CAKE QoS feature.  

### __WARNING:__  
1. During installation, /jffs/scripts/services-start will be replaced. If you have added any custom commands, you can find a backup of the original file in the following directories:    
    - /jffs/scripts/cake-speedsync/backup  --> Kept until next install
    - /tmp/home/root/                      --> Kept until router is restarted

### __INSTALLATION:__  
1. Ensure router is running on MERLIN firmware (check DEPENDENCIES section above)
2. Login to your ASUS Router Web UI 
3. Enable JFFS custom scripts and configs (Administration > System)  
4. Enable SSH (LAN Only)  
5. Open CMD or PowerShell and connect to your router via SSH (example: ssh admin@192.168.1.1)  
6. Run syntax to install:            
```markdown
curl -fsSL "https://raw.githubusercontent.com/mvin321/CAKE-SpeedSync/main/install.sh" | sh -s -- main
```
7. Script runs immediately after installation.  

### __HOW IT WORKS:__  
1. When the script runs, CAKE bandwidth will be udpated to 100gbit to avoid throttling while the test is running.  
2. Ookla SpeedTest (built-in) will execute in the background to generate load in the network. The script will then monitor the TX and RX rates via /proc/net/dev to get the maximum TX and RX rate. This process takes about 20 seconds and will only wait a maximum of 1 minute before quiting.  
3. Once the maximum TX (upload) and RX (download) speed have been identified. 95% of this rate will be set as CAKE's bandwidth. You can update the % in /jffs/scripts/cake-speedsync/cake.cfg after installation. The new % will apply on the next run of the script.  
4. Data from SpeedTest (ookla) result are not used. Speedtest is only needed to generate network load during analysis.
5. MERLIN-CAKE's default Queueing Discpline are diffserv3 for outbound (eth0) and besteffort for inbound (ifb4eth0) traffic. This program will use the value configured in the config file provided (cake.cfg). Currently configured to diffserv4 for both. You can change this via the provided /jffs/scripts/cake-speedsync/cake.cfg if you only want the speed sync functionality.
6. MERLIN-CAKE's default rtt is 100ms for both outbound (eth0) and inbound (ifb4eth0) traffic. This program will use the value configured in the config file provided (cake.cfg). Currently configured to 50ms. You can change this via the provided /jffs/scripts/cake-speedsync/cake.cfg. i.e eth0 diffserv4 rtt 20ms
7. MERLIN-CAKE's internal memory limit is 4MB for both outbound (eth0) and inbound (ifb4eth0) interfaces. This program will update it to 8MB (eth0) and 16MB (ifb4eth0). You can change this via the provided /jffs/scripts/cake-speedsync/cake.cfg. 
8. Value for overhead and mpu will be retained if set via the router's web ui (Go to Adaptive QoS > QoS > Cake). Otherwise, the default value will be 22 for overhead and 84 for MPU.  
9. Speedtest and dynamic updates will occur every 3 hours from 7:00 AM to 1:00 AM (next day) feel free to update the cron schedule after installation (cru). 
