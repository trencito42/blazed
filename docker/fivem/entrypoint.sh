#!/bin/sh
set -e

MYSQL_CONN="mysql://${MARIADB_USER:-sunset}:${MARIADB_PASSWORD}@mariadb:3306/${MARIADB_DATABASE:-sunsetmp}?charset=utf8mb4"

if [ -f /config-mount/server.cfg.template ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *__MYSQL_CONNECTION_STRING__*)
        line="set mysql_connection_string \"${MYSQL_CONN}\""
        ;;
      *__LICENSE_KEY__*)
        line="sv_licenseKey \"${LICENSE_KEY}\""
        ;;
    esac
    printf '%s\n' "$line"
  done < /config-mount/server.cfg.template > /config/server.cfg
  echo "[sunsetmp] server.cfg generated"
fi

export NO_DEFAULT_CONFIG=1
export NO_LICENSE_KEY=1
exec /sbin/tini -- /usr/bin/entrypoint +exec /config/server.cfg
