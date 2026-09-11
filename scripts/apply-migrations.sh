#!/bin/sh
# Canonical, fail-fast SunsetMP migration runner. Safe to run repeatedly.
set -eu

ROOT="${1:-$(pwd)}"
cd "$ROOT"
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi
: "${MARIADB_PASSWORD:?MARIADB_PASSWORD must be provided by the deployment secret store}"

db_exec() {
  docker compose exec -T -e MYSQL_PWD="${MARIADB_PASSWORD}" mariadb \
    mariadb -N -B -u"${MARIADB_USER:-sunset}" "${MARIADB_DATABASE:-sunsetmp}" "$@"
}

db_exec -e "CREATE TABLE IF NOT EXISTS schema_migrations (name VARCHAR(191) PRIMARY KEY, checksum CHAR(64) NOT NULL, applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB"

# A production database predating the registry is baselined only through v35.
if [ "$(db_exec -e "SELECT COUNT(*) FROM schema_migrations" | tr -d '\r')" = "0" ] \
  && [ "$(db_exec -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='characters'" | tr -d '\r')" = "1" ]; then
  for migration in sql/[0-9][0-9]-*.sql; do
    [ -f "$migration" ] || continue
    base="$(basename "$migration")"
    [ "$base" = "01-sunset.sql" ] && continue
    prefix="${base%%-*}"
    [ "$prefix" -le 35 ] || continue
    checksum="$(sha256sum "$migration" | awk '{print $1}')"
    db_exec -e "INSERT IGNORE INTO schema_migrations (name, checksum) VALUES ('${base}', '${checksum}')"
  done
fi

for migration in sql/[0-9][0-9]-*.sql; do
  [ -f "$migration" ] || continue
  base="$(basename "$migration")"
  [ "$base" = "01-sunset.sql" ] && continue
  checksum="$(sha256sum "$migration" | awk '{print $1}')"
  applied="$(db_exec -e "SELECT checksum FROM schema_migrations WHERE name='${base}' LIMIT 1" | tr -d '\r')"
  if [ -n "$applied" ]; then
    [ "$applied" = "$checksum" ] || { echo "[migrations] ERROR: applied migration $base was edited" >&2; exit 1; }
    echo "[migrations] $base already applied"
    continue
  fi
  echo "[migrations] applying $base"
  docker compose exec -T -e MYSQL_PWD="${MARIADB_PASSWORD}" mariadb \
    mariadb -u"${MARIADB_USER:-sunset}" "${MARIADB_DATABASE:-sunsetmp}" < "$migration"
  db_exec -e "INSERT INTO schema_migrations (name, checksum) VALUES ('${base}', '${checksum}')"
done
