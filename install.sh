#!/bin/sh
# CAKE-SpeedSync - Installer dev branc
# Copyright (C) 2025 https://github.com/mvin321
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

GIT_REPO="mvin321/MERLIN-cake-speedsync"
BRANCH="$1"
JFFS_DIR="/jffs/scripts"
TGT_DIR="/jffs/scripts/cake-speedsync"

#Function to fetch scripts from github
function fetch_file() {
    FILE_PATH="$1"
    curl -fsSL "https://raw.githubusercontent.com/$GIT_REPO/$BRANCH/$FILE_PATH" -o "$TGT_DIR/$(basename $FILE_PATH)"
}

function backup_file() {
    pscript_n="$1"
    [ -f "$JFFS_DIR/$pscript_n" ] && mv -f "$JFFS_DIR/$pscript_n" "$TGT_DIR/$(date +"%Y%m%d%H%M%S")-$pscript_n"    
}

#Remove installation directory and all its contents including backup of services-start
rm -rf "$TGT_DIR"

#Re-create directory
mkdir -p "$TGT_DIR" 

#Fetch scripts from github
fetch_file "cake-speedsync.sh"
fetch_file "cake.cfg"
fetch_file "cake-ss-fn.sh"
fetch_file "services-start"
fetch_file "nat-start"

#Make scripts executable
chmod +x $TGT_DIR/cake-speedsync.sh
chmod +x $TGT_DIR/cake-ss-fn.sh
chmod +x $TGT_DIR/services-start
chmod +x $TGT_DIR/nat-start

#Convert line breaks to unix line breaks
dos2unix $TGT_DIR/cake-speedsync.sh
dos2unix $TGT_DIR/cake.cfg
dos2unix $TGT_DIR/cake-ss-fn.sh
dos2unix $TGT_DIR/services-start
dos2unix $TGT_DIR/nat-start

#Create back up of the original services-start if existing
backup_file "services-start"
backup_file "nat-start"

#Move services-start
mv -f $TGT_DIR/services-start $JFFS_DIR/services-start
mv -f $TGT_DIR/services-start $JFFS_DIR/services-start

#Finalize installation
#Source cake-ss-fn.sh
[ -f /jffs/scripts/cake-speedsync/cake-ss-fn.sh ] && . /jffs/scripts/cake-speedsync/cake-ss-fn.sh

echo -e "\nInstallation Complete!"

#Run CAKE-SpeedSync and add cron job using cru
cs_init "logging"