#!/bin/sh

GIT_REPO="mvin321/MERLIN-dyn-tc-cake"
BRANCH="main"
JFFS_DIR "/jffs/scripts/"
TGT_DIR="/jffs/scripts/dyn-tc-cake"
GIT_TOKEN="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"

mkdir -p "$TGT_DIR"

fetch_file() {
    FILE_PATH="$1"
    curl -fsSL -H "Authorization: token $GIT_TOKEN" \
         -H "Accept: application/vnd.github.v3.raw" \
         "https://api.github.com/repos/$GIT_REPO/contents/$FILE_PATH?ref=$BRANCH" \
         -o "$TGT_DIR/$(basename $FILE_PATH)"
}

fetch_file ".ashrc"
fetch_file ".profile"
fetch_file "dyn-tc-cake.sh"
fetch_file "services-start"
fetch_file "dtc-functions.sh

mv $TGT_DIR/dyn-tc-cake.sh $JFFS_DIR/dyn-tc-cake.sh
mv $JFFS_DIR/services-start $TGT_DIR/$(date)-services-start
cp $TGT_DIR/.ashrc /tmp/home/root/
cp $TGT_DIR/.profile /tmp/home/root/