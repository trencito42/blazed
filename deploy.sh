#!/bin/sh
# Deploy / update SunsetMP pe VPS (rulează din folderul serviciului Coolify)
set -e

REPO="${REPO:-https://github.com/trencito42/blazed}"
BRANCH="${BRANCH:-main}"
DIR="$(pwd)"

restore_env() {
  if [ -n "$ENV_BACKUP" ] && [ -f "$ENV_BACKUP" ]; then
    cp "$ENV_BACKUP" .env
    cp "$ENV_BACKUP" .env.persist
    rm -f "$ENV_BACKUP"
  fi
}

sync_tree() {
  src="$1"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.env' --exclude '.env.persist' \
      "${src}/" "${DIR}/"
  else
    rm -rf /tmp/blazed-deploy
    mkdir -p /tmp/blazed-deploy
    cp -a "${src}/." /tmp/blazed-deploy/
    cp -a /tmp/blazed-deploy/. "${DIR}/"
    rm -rf /tmp/blazed-deploy
  fi
}

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
    echo "[deploy] git fetch origin/${BRANCH}..."
    if GIT_TERMINAL_PROMPT=0 git fetch --depth 1 origin "${BRANCH}"; then
      GIT_TERMINAL_PROMPT=0 git reset --hard "origin/${BRANCH}"
      restore_env
      echo "[deploy] git update OK"
      return 0
    fi
    echo "[deploy] git fetch failed — trying clone/ZIP fallback"
  else
    echo "[deploy] no .git in ${DIR} — shallow clone (first deploy or migrated folder)"
    CLONE_DIR="$(mktemp -d /tmp/blazed-clone.XXXXXX)"
    if GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "${BRANCH}" "${REPO}" "${CLONE_DIR}"; then
      echo "[deploy] syncing files (keeps .env)..."
      sync_tree "${CLONE_DIR}"
      rm -rf "${CLONE_DIR}"
      restore_env
      echo "[deploy] clone + sync OK (.git created for next deploy)"
      return 0
    fi
    rm -rf "${CLONE_DIR}"
    echo "[deploy] git clone failed — trying GitHub ZIP fallback"
  fi

  ZIP="/tmp/blazed-${BRANCH}.zip"
  ARCHIVE_DIR="/tmp/blazed-${BRANCH}"
  rm -f "${ZIP}"
  rm -rf "${ARCHIVE_DIR}"

  echo "[deploy] downloading GitHub archive (~30MB, may take 10-60s)..."
  if ! curl -fL --connect-timeout 20 --max-time 300 --progress-bar \
    -o "${ZIP}" "${REPO}/archive/refs/heads/${BRANCH}.zip"; then
    restore_env
    echo "[deploy] ERROR: could not download ${REPO}/archive/refs/heads/${BRANCH}.zip" >&2
    exit 1
  fi

  echo "[deploy] extracting..."
  unzip -qo "${ZIP}" -d /tmp
  if [ ! -d "${ARCHIVE_DIR}" ]; then
    restore_env
    echo "[deploy] ERROR: expected folder ${ARCHIVE_DIR} after unzip" >&2
    exit 1
  fi

  echo "[deploy] syncing files (keeps .env)..."
  sync_tree "${ARCHIVE_DIR}"
  rm -f "${ZIP}"
  rm -rf "${ARCHIVE_DIR}"
  restore_env
  echo "[deploy] ZIP fallback OK (run again after fix to use fast git pull)"
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
    if [ "${DEPLOY_IGNORE_MIGRATION_ERRORS:-0}" = "1" ]; then
      echo "[deploy] warning: $base returned errors (DEPLOY_IGNORE_MIGRATION_ERRORS=1)" >&2
    else
      echo "[deploy] ERROR: migration $base failed. Fix schema or set DEPLOY_IGNORE_MIGRATION_ERRORS=1 only if already applied." >&2
      exit 1
    fi
  fi
done

docker compose up -d --remove-orphans
docker compose up -d --force-recreate fivem

echo "Done. Connect: F8 -> connect $(curl -s ifconfig.me 2>/dev/null || echo YOUR_IP):30120"
