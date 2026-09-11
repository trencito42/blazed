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

git_with_timeout() {
  secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" env GIT_TERMINAL_PROMPT=0 GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=20 "$@"
  else
    env GIT_TERMINAL_PROMPT=0 GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=20 "$@"
  fi
}

pull_from_zip() {
  ZIP="/tmp/blazed-${BRANCH}.zip"
  ARCHIVE_DIR="/tmp/blazed-${BRANCH}"
  rm -f "${ZIP}"
  rm -rf "${ARCHIVE_DIR}"

  echo "[deploy] downloading GitHub archive (curl, ~30MB, 10-60s)..."
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
  echo "[deploy] ZIP update OK"
}

bootstrap_git() {
  if [ -d .git ] || ! command -v git >/dev/null 2>&1; then
    return 0
  fi
  echo "[deploy] creating .git for faster future deploys..."
  git init -q
  git remote add origin "${REPO}" 2>/dev/null || git remote set-url origin "${REPO}"
  if git_with_timeout 90 git fetch --depth 1 origin "${BRANCH}"; then
    git checkout -B "${BRANCH}" FETCH_HEAD -q 2>/dev/null || git reset --hard FETCH_HEAD
    echo "[deploy] .git ready — next deploy will use git fetch"
  else
    rm -rf .git
    echo "[deploy] git bootstrap skipped (ZIP deploy OK; will use ZIP again next time)"
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
    if git_with_timeout 90 git fetch --depth 1 origin "${BRANCH}"; then
      GIT_TERMINAL_PROMPT=0 git reset --hard "origin/${BRANCH}"
      restore_env
      echo "[deploy] git update OK"
      return 0
    fi
    echo "[deploy] git fetch failed — trying GitHub ZIP"
  else
    echo "[deploy] no .git in ${DIR} (Coolify copy / manual folder — normal)"
    echo "[deploy] skipping git clone (often hangs on VPS); using GitHub ZIP instead"
    pull_from_zip
    bootstrap_git
    return 0
  fi

  pull_from_zip
  bootstrap_git
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
sed -i 's/\r$//' docker/fivem/entrypoint.sh deploy.sh scripts/install-deps.sh scripts/apply-migrations.sh scripts/vps-restart-all.sh
chmod +x docker/fivem/entrypoint.sh deploy.sh scripts/install-deps.sh scripts/apply-migrations.sh scripts/vps-restart-all.sh

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

echo "[deploy] applying SQL migrations..."
sh scripts/apply-migrations.sh "$DIR"

docker compose up -d --remove-orphans
docker compose up -d --force-recreate fivem

echo "Done. Connect: F8 -> connect $(curl -s ifconfig.me 2>/dev/null || echo YOUR_IP):30120"
