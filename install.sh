#!/bin/sh

GIT_REPO="mvin321/MERLIN-cake-speedsync"
BRANCH="main"
JFFS_DIR="/jffs/scripts"
TGT_DIR="/jffs/scripts/cake-speedsync"
GIT_TOKEN="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"

#Function to fetch scripts from github - Repo on private temporarily
fetch_file() {
    FILE_PATH="$1"
    curl -fsSL -H "Authorization: token $GIT_TOKEN" \
         -H "Accept: application/vnd.github.v3.raw" \
         "https://api.github.com/repos/$GIT_REPO/contents/$FILE_PATH?ref=$BRANCH" \
         -o "$TGT_DIR/$(basename $FILE_PATH)"
}

#Remove cake-speedsync directory - this will ensure all files are fresh and avoid having multiple backup of services-start
rm -rf "$TGT_DIR"

#Re-create directory
mkdir -p "$TGT_DIR" 

#Fetch scripts from github
fetch_file ".ashrc"
fetch_file ".profile"
fetch_file "cake-speedsync.sh"
fetch_file "services-start"
fetch_file "css-functions.sh"

#Make scripts executable
chmod +x $TGT_DIR/cake-speedsync.sh
chmod +x $TGT_DIR/services-start
chmod +x $TGT_DIR/css-functions.sh
chmod +x $TGT_DIR/.ashrc
chmod +x $TGT_DIR/.profile

#Convert line breaks to unix line breaks
dos2unix $TGT_DIR/cake-speedsync.sh
dos2unix $TGT_DIR/services-start
dos2unix $TGT_DIR/css-functions.sh
dos2unix $TGT_DIR/.ashrc
dos2unix $TGT_DIR/.profile

#Finalize installation
mv -f $TGT_DIR/cake-speedsync.sh $JFFS_DIR/cake-speedsync.sh
[ -f $JFFS_DIR/services-start ] && mv -f $JFFS_DIR/services-start $TGT_DIR/$(date +"%Y%m%d%H%M%S")-services-start
mv -f $TGT_DIR/services-start $JFFS_DIR/services-start
cp -f $TGT_DIR/.ashrc /tmp/home/root/
cp -f $TGT_DIR/.profile /tmp/home/root/

[ -f /jffs/scripts/cake-speedsync/css-functions.sh ] && . /jffs/scripts/cake-speedsync/css-functions.sh

echo -e "\nInstallation Complete!\n\nManually reboot your router.\n\nEvery time you log back in (ssh) you should see the status of what was changed or you can run css_status manually"
echo -e "\n\n"
