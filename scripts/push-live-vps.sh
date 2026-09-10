#!/bin/sh
set -e
SERVICE="/opt/blazed"
LIVE="$(docker volume ls -q | grep fivem_config | head -1)"
if [ -n "$LIVE" ]; then
  LIVE="/var/lib/docker/volumes/${LIVE}/_data/resources/[sunset]"
else
  LIVE="$SERVICE/resources/[sunset]"
fi
ZIP="/tmp/blazed-main.zip"
EXTRACT="/tmp/blazed-extract"
rm -rf "$EXTRACT" "$ZIP"
wget -q -O "$ZIP" https://github.com/trencito42/blazed/archive/refs/heads/main.zip
unzip -qo "$ZIP" -d /tmp
rm -rf "$EXTRACT"
mv /tmp/blazed-main "$EXTRACT"
cp -rf "$EXTRACT/resources/[sunset]"/* "$SERVICE/resources/[sunset]/"
cp -rf "$SERVICE/resources/[sunset]"/* "$LIVE/"
rm -rf "$ZIP" "$EXTRACT"
echo "[sunsetmp] live resources updated (no restart)"
echo "Reload in server console:"
echo "  ensure sunset_ui"
