#!/usr/bin/env bash
#
# Package the receiver plugin for upload.
#
#   ./build.sh            -> highlandsites.zip beside this script
#
# WordPress refuses remote installation of arbitrary plugin zips - the REST
# endpoint accepts only a wordpress.org slug - so this is uploaded once through
# wp-admin per site. Listing the plugin on wordpress.org removes that step.

set -euo pipefail
cd "$(dirname "$0")"
NAME=highlandsites
rm -rf "/tmp/$NAME" "$NAME.zip"
mkdir -p "/tmp/$NAME/includes"
cp highlandsites.php "/tmp/$NAME/"
cp includes/*.php "/tmp/$NAME/includes/"
( cd /tmp && zip -qr "$OLDPWD/$NAME.zip" "$NAME" )
rm -rf "/tmp/$NAME"
echo "Built $NAME.zip"
