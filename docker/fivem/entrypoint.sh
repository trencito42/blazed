#!/bin/sh
set -e

MYSQL_CONN="mysql://${MARIADB_USER:-sunset}:${MARIADB_PASSWORD}@mariadb:3306/${MARIADB_DATABASE:-sunsetmp}?charset=utf8mb4"

if [ -f /config-mount/server.cfg.template ]; then
  sed \
    -e "s|__MYSQL_CONNECTION_STRING__|${MYSQL_CONN}|g" \
    /config-mount/server.cfg.template > /config/server.cfg
  echo "[sunsetmp] server.cfg generated"
else
  echo "[sunsetmp] WARN: missing /config-mount/server.cfg.template"
fi

exec /docker-entrypoint.sh "$@"
