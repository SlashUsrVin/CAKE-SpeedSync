# MERLIN-cake-speedsync - For ASUS router running MERLIN firmware. 

Updates CAKE QoS bandwidth and latency based of the built in Ookla SpeedTest (CLI) and ping response time from Google (8.8.8.8). This will allow CAKE to adapt to ISP Speed fluctuations.  

### __DEPENDENCIES:__  
1. ASUS Router running on the latest MERLIN firmware. (https://sourceforge.net/projects/asuswrt-merlin/files/)  
2. Must have custom script support and built in CAKE QoS feature.  

### __INSTALLATION:__  
1. Login to your ASUS Router Web UI  
2. Enable JFFS custom scripts and configs (Administration > System)  
3. Enable SSH (LAN Only)  
4. Open CMD or PowerShell and connect to your router via SSH (ssh user@GatewayIP)  
5. Run syntax:            
___curl -fsSL "https://raw.githubusercontent.com/mvin321/MERLIN-cake-speedsync/main/install.sh" | sh___  
7. Once complete, reboot router manually.  

### __HOW IT WORKS:__  
1. Disable cake temporarily  
2. Runs the built in Ookla SpeedTest (CLI) in the background to get the current download and upload speed  
3. Re-enable cake settings with the updated bandwidth and RTT  
4. RTT is set based on the median value from ping -c 10 8.8.8.8, ranging from 10ms to 100ms in 10ms increments.  
5. Other settings are based of what you set in the QoS page (i.e overhead, mpu, etc). This program only updates the bandwidth and rtt.  
6. Speedtest and dynamic updates will occur every 2 hours from 7:00 AM to 11:00 PM feel free to update the cron entry in /jffs/scripts/cake-speedsync/css-functions.sh (css_initialize) after installation.  
7. These steps are also performed every after reboot (waits 30 seconds).  
