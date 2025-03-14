#!/bin/sh

GIT_REP_URL="https://raw.githubusercontent.com/mvin321/MERLIN-dyn-tc-cake/main"
TGT_DIR="/jffs/scripts/dyn-tc-cake"

mkdir -p "$TGT_DIR"

curl -fsSL "$GIT_REP_URL/.ashrc" -o "$TGT_DIR/.ashrc"
curl -fsSL "$GIT_REP_URL/.profile" -o "$TGT_DIR/.profile"
curl -fsSL "$GIT_REP_URL/dyn-tc-cake.sh" -o "$TGT_DIR/dyn-tc-cake.sh"
curl -fsSL "$GIT_REP_URL/services-start" -o "$TGT_DIR/services-start"