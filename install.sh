#!/bin/sh

GIT_REP_URL="https://raw.githubusercontent.com/mvin321/MERLIN-dyn-tc-cake/main"
TGT_DIR="/jffs/scripts/dyn-tc-cake"
GIT_TOKEN="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"

mkdir -p "$TGT_DIR"

curl -fsSL -H "Authorization: token $GIT_TOKEN" "$GIT_REP_URL/.ashrc" -o "$TGT_DIR/.ashrc"
curl -fsSL -H "Authorization: token $GIT_TOKEN" "$GIT_REP_URL/.profile" -o "$TGT_DIR/.profile"
curl -fsSL -H "Authorization: token $GIT_TOKEN" "$GIT_REP_URL/dyn-tc-cake.sh" -o "$TGT_DIR/dyn-tc-cake.sh"
curl -fsSL -H "Authorization: token $GIT_TOKEN" "$GIT_REP_URL/services-start" -o "$TGT_DIR/services-start"