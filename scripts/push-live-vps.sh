#!/bin/sh
set -e
SERVICE="/data/coolify/services/b0n1oc2fcrzbgdco838ezm1i"
LIVE="/var/lib/docker/volumes/b0n1oc2fcrzbgdco838ezm1i_fivem_config/_data/resources/[sunset]"
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
echo "txAdmin console:"
echo "  refresh"
echo "  ensure sunset_ui"
