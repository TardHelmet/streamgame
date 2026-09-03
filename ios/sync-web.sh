#!/bin/sh
# Copy the web game into the iOS bundle folder. Run after editing index.html.
set -e
cd "$(dirname "$0")"
mkdir -p Starflappy64/web
cp ../index.html Starflappy64/web/index.html
echo "synced ../index.html -> ios/Starflappy64/web/index.html"
