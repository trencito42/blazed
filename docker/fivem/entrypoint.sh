#!/bin/sh
set -e

MYSQL_CONN="mysql://${MARIADB_USER:-sunset}:${MARIADB_PASSWORD}@mariadb:3306/${MARIADB_DATABASE:-sunsetmp}?charset=utf8mb4"

# Generează server.cfg
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

# Merge resurse GTA default + resursele noastre (mount-ul e read-only separat)
mkdir -p /config/resources
if [ -d /opt/cfx-server-data/resources ]; then
  cp -rn /opt/cfx-server-data/resources/* /config/resources/ 2>/dev/null || true
fi
if [ -d /config/resources-custom ]; then
  cp -rf /config/resources-custom/* /config/resources/ 2>/dev/null || true
fi
echo "[sunsetmp] resources merged"

export NO_DEFAULT_CONFIG=1
export NO_LICENSE_KEY=1
exec /sbin/tini -- /usr/bin/entrypoint +exec /config/server.cfg
