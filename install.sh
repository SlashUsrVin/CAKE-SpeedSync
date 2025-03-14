#!/bin/sh

GIT_REPO="mvin321/MERLIN-dyn-tc-cake"
BRANCH="main"
JFFS_DIR="/jffs/scripts"
TGT_DIR="/jffs/scripts/dyn-tc-cake"
GIT_TOKEN="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"

#Function to fetch scripts from github - Repo on private temporarily
fetch_file() {
    FILE_PATH="$1"
    curl -fsSL -H "Authorization: token $GIT_TOKEN" \
         -H "Accept: application/vnd.github.v3.raw" \
         "https://api.github.com/repos/$GIT_REPO/contents/$FILE_PATH?ref=$BRANCH" \
         -o "$TGT_DIR/$(basename $FILE_PATH)"
}

#Remove dyn-tc-cake directory - this will ensure all files are fresh and avoid having multiple backup of services-start
rm -rf "$TGT_DIR"

#Re-create directory
mkdir -p "$TGT_DIR" 

#Fetch scripts from github
fetch_file ".ashrc"
fetch_file ".profile"
fetch_file "dyn-tc-cake.sh"
fetch_file "services-start"
fetch_file "dtc-functions.sh"

#Make scripts executable
chmod +x $TGT_DIR/dyn-tc-cake.sh
chmod +x $TGT_DIR/services-start

#Finalize installation
mv -f $TGT_DIR/dyn-tc-cake.sh $JFFS_DIR/dyn-tc-cake.sh
mv -f $JFFS_DIR/services-start $TGT_DIR/$(date +"%Y%m%d%H%M%S")-services-start
cp -f $TGT_DIR/.ashrc /tmp/home/root/
cp -f $TGT_DIR/.profile /tmp/home/root/