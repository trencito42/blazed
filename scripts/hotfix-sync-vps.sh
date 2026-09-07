#!/bin/sh
# Copy live edits from resources-custom into the FiveM volume (/config/resources).
# Coolify only merges on container start; SCP updates custom mount only.
set -e
CONTAINER="${SUNSET_CONTAINER:-b0n1oc2fcrzbgdco838ezm1i-fivem-1}"
CUSTOM="/config/resources-custom/[sunset]"
LIVE="/config/resources/[sunset]"

if ! docker exec "$CONTAINER" test -d "$CUSTOM"; then
  echo "Missing $CUSTOM in $CONTAINER"
  exit 1
fi

docker exec "$CONTAINER" sh -c 'cp -rf /config/resources-custom/\[sunset\]/* /config/resources/\[sunset\]/'
