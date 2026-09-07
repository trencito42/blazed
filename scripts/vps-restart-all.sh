#!/bin/sh
set -e
BASE=/data/coolify/services/b0n1oc2fcrzbgdco838ezm1i
DB_PASS='SunsetDb_VPS_2026!'

echo "[sunsetmp] applying SQL migrations..."
for f in "$BASE/sql"/[0-9][0-9]-*.sql; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "01-sunset.sql" ] && continue
  echo "  -> $base"
  if docker exec -i b0n1oc2fcrzbgdco838ezm1i-mariadb-1 mariadb -usunset -p"$DB_PASS" sunsetmp < "$f"; then
    echo "     OK"
  else
    echo "     WARN (check if already applied)"
  fi
done

echo "[sunsetmp] verifying clan schema..."
docker exec b0n1oc2fcrzbgdco838ezm1i-mariadb-1 mariadb -usunset -p"$DB_PASS" sunsetmp -e \
  "SHOW COLUMNS FROM clans LIKE 'rank_labels'; SHOW COLUMNS FROM clan_members LIKE 'warns';"

echo "[sunsetmp] restarting FiveM (merges resources + reloads scripts)..."
docker restart b0n1oc2fcrzbgdco838ezm1i-fivem-1

echo "[sunsetmp] waiting for startup..."
sleep 30

echo "[sunsetmp] live file check..."
docker exec b0n1oc2fcrzbgdco838ezm1i-fivem-1 grep -n canUseFactionLift \
  /config/resources/\[sunset\]/sunset_world/client/elevators.lua | head -1 || true

docker logs b0n1oc2fcrzbgdco838ezm1i-fivem-1 2>&1 | tail -20

echo "[sunsetmp] done — reconnect to server"
