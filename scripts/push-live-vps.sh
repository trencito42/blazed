#!/bin/sh
# Push [sunset] from Coolify mount into the live FiveM Docker volume.
set -e
SRC="/data/coolify/services/b0n1oc2fcrzbgdco838ezm1i/resources/[sunset]"
DST="/var/lib/docker/volumes/b0n1oc2fcrzbgdco838ezm1i_fivem_config/_data/resources/[sunset]"
cp -rf "$SRC"/* "$DST"/
echo "[sunsetmp] live resources updated"
echo "Run in txAdmin console:"
echo "  restart sunset_hud"
echo "  restart sunset_world"
