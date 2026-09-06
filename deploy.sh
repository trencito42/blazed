#!/bin/sh
# Deploy / update SunsetMP pe VPS (rulează din folderul serviciului Coolify)
set -e

REPO="${REPO:-https://github.com/trencito42/blazed}"
BRANCH="${BRANCH:-main}"
DIR="$(pwd)"

pull_repo() {
  ENV_BACKUP=""
  if [ -f .env ]; then
    ENV_BACKUP="$(mktemp)"
    cp .env "$ENV_BACKUP"
    cp .env .env.persist
  elif [ -f .env.persist ]; then
    cp .env.persist .env
    ENV_BACKUP="$(mktemp)"
    cp .env "$ENV_BACKUP"
  fi

  if [ -d .git ]; then
    if GIT_TERMINAL_PROMPT=0 git fetch origin "$BRANCH" 2>/dev/null; then
      GIT_TERMINAL_PROMPT=0 git reset --hard "origin/$BRANCH"
      if [ -n "$ENV_BACKUP" ] && [ -f "$ENV_BACKUP" ]; then
        cp "$ENV_BACKUP" .env
        cp "$ENV_BACKUP" .env.persist
        rm -f "$ENV_BACKUP"
      fi
      return 0
    fi
  fi

  echo "[deploy] git failed — using GitHub ZIP (repo public)"
  curl -fsSL -o /tmp/blazed.zip "${REPO}/archive/refs/heads/${BRANCH}.zip?$(date +%s)"
  rm -rf /tmp/blazed-main
  unzip -qo /tmp/blazed.zip -d /tmp
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete /tmp/blazed-main/ "$DIR/"
  else
    rm -rf /tmp/blazed-deploy
    mkdir -p /tmp/blazed-deploy
    cp -a /tmp/blazed-main/. /tmp/blazed-deploy/
    cp -a /tmp/blazed-deploy/. "$DIR/"
  fi

  if [ -n "$ENV_BACKUP" ] && [ -f "$ENV_BACKUP" ]; then
    cp "$ENV_BACKUP" .env
    cp "$ENV_BACKUP" .env.persist
    rm -f "$ENV_BACKUP"
  fi
}

pull_repo

# Docker Compose reads .env for interpolation, but those values are not exported
# to this shell. The migration commands below also need the same credentials;
# without this, `mariadb-admin -p"${MARIADB_PASSWORD}"` becomes bare `-p` and
# waits forever for an interactive password prompt during unattended deploys.
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi
: "${MARIADB_PASSWORD:?MARIADB_PASSWORD must be set in .env before deployment}"

chmod -R a+rX config docker resources sql
sed -i 's/\r$//' docker/fivem/entrypoint.sh deploy.sh scripts/install-deps.sh
chmod +x docker/fivem/entrypoint.sh deploy.sh scripts/install-deps.sh

# ox_lib must exist (with web/build) before the FiveM container copies resources
if [ -f scripts/install-deps.sh ]; then
  sh scripts/install-deps.sh
fi

docker compose build fivem
docker compose up -d mariadb

# Apply schema changes before the gameplay resource starts, so a newly added
# resource never boots against missing tables.
attempt=0
mariadb_container="$(docker compose ps -q mariadb)"
until [ -n "$mariadb_container" ] && [ "$(docker inspect -f '{{.State.Health.Status}}' "$mariadb_container" 2>/dev/null)" = "healthy" ]; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo "[deploy] MariaDB did not become ready in time" >&2
    exit 1
  fi
  sleep 2
done

# Run SQL migrations (idempotent where possible)
echo "[deploy] applying SQL migrations..."
for migration in sql/[0-9][0-9]-*.sql; do
  [ -f "$migration" ] || continue
  base="$(basename "$migration")"
  case "$base" in
    01-sunset.sql) continue ;;
  esac
  echo "[deploy] -> $base"
  if ! docker compose exec -T -e MYSQL_PWD="${MARIADB_PASSWORD}" mariadb mariadb -u"${MARIADB_USER:-sunset}" "${MARIADB_DATABASE:-sunsetmp}" < "$migration"; then
    echo "[deploy] warning: $base returned errors (may be ok if already applied)" >&2
  fi
done

docker compose up -d --remove-orphans
docker compose up -d --force-recreate fivem

echo "Done. Connect: F8 -> connect $(curl -s ifconfig.me 2>/dev/null || echo YOUR_IP):30120"
