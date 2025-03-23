# MERLIN-cake-speedsync - For ASUS router running MERLIN firmware. 

Updates CAKE QoS bandwidth and latency based of the built in Ookla SpeedTest (CLI) and ping response time from Google (8.8.8.8). This will allow CAKE to adapt to ISP Speed fluctuations.  

### __DEPENDENCIES:__  
1. ASUS Router running on the latest MERLIN firmware. (https://sourceforge.net/projects/asuswrt-merlin/files/)  
2. Must have custom script support and built in CAKE QoS feature.  

### __WARNING:__  
1. During installation, /jffs/scripts/services-start will be replaced. If you have added any custom commands, you can find a backup of the original file in /jffs/scripts/cake-speedsync/. 
2. MERLIN-CAKE's default Queueing Discpline are diffserv3 for outbound (eth0) and besteffort for inbound (ifb4eth0). This program will default to diffserv4 (eth0) and diffserv3 (ifb4eth0). You can change this via the provided /jffs/scripts/cake-speedsync/cake.cfg

### __INSTALLATION:__  
1. Login to your ASUS Router Web UI 
2. Enable JFFS custom scripts and configs (Administration > System)  
3. Enable SSH (LAN Only)  
4. Open CMD or PowerShell and connect to your router via SSH (ssh user@GatewayIP)  
5. Run syntax:            
___curl -fsSL "https://raw.githubusercontent.com/mvin321/MERLIN-cake-speedsync/main/install.sh" | sh___  
7. Once complete, reboot router manually.  

### __HOW IT WORKS:__  
1. Update CAKE's bandwidth to very high (2gbit) to avoid throtlling while doing the speedtest.  
2. Runs the built in Ookla SpeedTest (CLI) in the background to get the current download and upload speed.  
3. Update bandwidth based from SpeedTest result.  
4. Run a ping test to Google (8.8.8.8). RTT is set based on the median value from the ping test and rounded to the nearset 5ms increments.
5. Other settings are based of what was set in the QoS page (overhead & mpu).   
6. Speedtest and dynamic updates will occur every 2 hours from 7:00 AM to 11:00 PM feel free to update the cron entry in /jffs/scripts/cake-speedsync/css-functions.sh (css_initialize) after installation.  
7. These steps are also performed every after reboot (waits 30 seconds).  
