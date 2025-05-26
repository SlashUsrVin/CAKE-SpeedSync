#!/bin/sh
# CAKE-SpeedSync - Installer
# Author: SlashUsrVin
#
# MIT License
# Copyright (c) 2025 SlashUsrVin
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# See the LICENSE file in the repository root for full text.

CSS_REPO="SlashUsrVin/CAKE-SpeedSync"
BRANCH="main"
JFFS_DIR="/jffs/scripts"
TGT_DIR="/jffs/scripts/cake-speedsync"
BKU_DIR="$TGT_DIR/backup"
TMP_DIR="/tmp/home/root/backup"

#Function to fetch scripts from github
fetch_file() {
    GIT_REPO="$1"
    GIT_FILE_PATH="$2"
    LOC_INSTALL_DIR="$3"

    curl -fsSL "https://raw.githubusercontent.com/$GIT_REPO/$BRANCH/$GIT_FILE_PATH" -o "$LOC_INSTALL_DIR/$(basename $GIT_FILE_PATH)"
}

backup_file() {
    sh_full_path="$1"
    pscript_n=$(basename "$sh_full_path")
    bk_pre_name=$(date +"%Y%m%d%H%M%S")
    if [ -f "$sh_full_path" ]; then
        mv -f "$sh_full_path" "$TMP_DIR/$bk_pre_name-$pscript_n"    
        echo "$pscript_n" >> "$TMP_DIR/backup.list"
    fi
}

#Create backup
mkdir -p "$TMP_DIR"
> "$TMP_DIR/backup.list"
backup_file "$JFFS_DIR/services-start"
backup_file "$JFFS_DIR/nat-start"
backup_file "$TGT_DIR/cake.cfg"

#Remove installation directory and all its contents including backup of services-start
rm -rf "$TGT_DIR"

#Re-create directory
mkdir -p "$TGT_DIR" 
mkdir -p "$TGT_DIR/backup" 

#Fetch scripts from github
fetch_file "$CSS_REPO" "cake-speedsync.sh" "$TGT_DIR"
fetch_file "$CSS_REPO" "cake.cfg" "$TGT_DIR"
fetch_file "$CSS_REPO" "cake-ss-fn.sh" "$TGT_DIR"
fetch_file "$CSS_REPO" "services-start" "$TGT_DIR"
fetch_file "$CSS_REPO" "nat-start" "$TGT_DIR"
fetch_file "SlashUsrVin/ExecLock-Shell" "exec-lock.sh" "$JFFS_DIR" #additional script logs every run in syslog and prevents concurrency

#Make scripts executable
chmod +x $TGT_DIR/cake-speedsync.sh
chmod +x $TGT_DIR/cake-ss-fn.sh
chmod +x $TGT_DIR/services-start
chmod +x $TGT_DIR/nat-start
chmod +x $JFFS_DIR/exec-lock.sh

#Convert line breaks to unix line breaks
dos2unix $TGT_DIR/cake-speedsync.sh
dos2unix $TGT_DIR/cake.cfg
dos2unix $TGT_DIR/cake-ss-fn.sh
dos2unix $TGT_DIR/services-start
dos2unix $TGT_DIR/nat-start
dos2unix $JFFS_DIR/exec-lock.sh

#Move services-start
mv -f $TGT_DIR/services-start $JFFS_DIR/services-start
mv -f $TGT_DIR/nat-start $JFFS_DIR/nat-start

#Finalize installation
#Source cake-ss-fn.sh
[ -f "$TGT_DIR/cake-ss-fn.sh" ] && . "$TGT_DIR/cake-ss-fn.sh"

echo -e "\nInstallation Complete!"

#Run CAKE-SpeedSync and add cron job using cru
cs_init "logging"

#Copy backup to cake-speedsync directory. Temp backup is retained and will be deleted automatically when router reboots.
while read -r line || [ -n "$line" ]; do 
    cp $(ls -r "$TMP_DIR"/*"$line" | sort | tail -1) "$TGT_DIR/backup"
done < "$TMP_DIR/backup.list"