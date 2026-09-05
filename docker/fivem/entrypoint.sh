#!/bin/sh
set -e

MYSQL_CONN="mysql://${MARIADB_USER:-sunset}:${MARIADB_PASSWORD}@mariadb:3306/${MARIADB_DATABASE:-sunsetmp}?charset=utf8mb4"

# MariaDB only executes /docker-entrypoint-initdb.d for a brand-new data
# volume. Re-run every idempotent application migration before FiveM starts
# so an existing production database cannot miss tables added by a release.
# 01 creates the database and is intentionally left to the MariaDB container.
for migration in /migrations/[0-9][0-9]-*.sql; do
  [ -f "${migration}" ] || continue
  [ "$(basename "${migration}")" = "01-sunset.sql" ] && continue
  echo "[sunsetmp] applying $(basename "${migration}")"
  MYSQL_PWD="${MARIADB_PASSWORD}" mariadb \
    --host=mariadb \
    --user="${MARIADB_USER:-sunset}" \
    --database="${MARIADB_DATABASE:-sunsetmp}" \
    < "${migration}"
done
echo "[sunsetmp] database migrations complete"

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
  for bundled_dependency in ox_lib pma-voice bob74_ipl; do
    if [ -d "/opt/cfx-server-data/resources/${bundled_dependency}" ]; then
      rm -rf "/config/resources/${bundled_dependency}"
      cp -r "/opt/cfx-server-data/resources/${bundled_dependency}" "/config/resources/${bundled_dependency}"
    fi
  done
  cp -rn /opt/cfx-server-data/resources/* /config/resources/ 2>/dev/null || true
fi
if [ -d /config/resources-custom ]; then
  # Replace each custom top-level resource group atomically from the image input.
  # A plain recursive copy leaves deleted/renamed files in the persistent volume,
  # which can make production run code that no longer exists in Git.
  for custom_entry in /config/resources-custom/*; do
    [ -e "${custom_entry}" ] || continue
    custom_name="$(basename "${custom_entry}")"
    case "${custom_name}" in
      ''|'.'|'..') continue ;;
    esac
    rm -rf "/config/resources/${custom_name}"
  done
  cp -rf /config/resources-custom/* /config/resources/ 2>/dev/null || true
fi
echo "[sunsetmp] resources merged"

export NO_DEFAULT_CONFIG=1
export NO_LICENSE_KEY=1
exec /sbin/tini -- /usr/bin/entrypoint +set onesync on +set onesync_population false +exec /config/server.cfg
