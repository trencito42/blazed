#!/bin/sh
set -e
BASE=${BASE:-/data/coolify/services/b0n1oc2fcrzbgdco838ezm1i}
cd "$BASE"

echo "[sunsetmp] applying checked SQL migrations..."
sh scripts/apply-migrations.sh "$BASE"

echo "[sunsetmp] restarting FiveM (merges resources + reloads scripts)..."
docker compose restart fivem

echo "[sunsetmp] waiting for startup..."
sleep 30

echo "[sunsetmp] live file check..."
docker compose logs --tail 40 fivem

echo "[sunsetmp] done — reconnect to server"
