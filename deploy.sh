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

chmod -R a+rX config docker resources sql
sed -i 's/\r$//' docker/fivem/entrypoint.sh deploy.sh
chmod +x docker/fivem/entrypoint.sh deploy.sh

docker compose build fivem
docker compose up -d --remove-orphans
docker compose up -d --force-recreate fivem

# Run SQL migrations (idempotent where possible)
if [ -f sql/03-foundation.sql ]; then
  docker compose exec -T mariadb mariadb -u"${MARIADB_USER:-sunset}" -p"${MARIADB_PASSWORD}" "${MARIADB_DATABASE:-sunsetmp}" < sql/03-foundation.sql 2>/dev/null || true
fi
if [ -f sql/04-features.sql ]; then
  docker compose exec -T mariadb mariadb -u"${MARIADB_USER:-sunset}" -p"${MARIADB_PASSWORD}" "${MARIADB_DATABASE:-sunsetmp}" < sql/04-features.sql 2>/dev/null || true
fi
if [ -f sql/05-factions-crafting.sql ]; then
  docker compose exec -T mariadb mariadb -u"${MARIADB_USER:-sunset}" -p"${MARIADB_PASSWORD}" "${MARIADB_DATABASE:-sunsetmp}" < sql/05-factions-crafting.sql 2>/dev/null || true
fi
if [ -f sql/06-taxi.sql ]; then
  docker compose exec -T mariadb mariadb -u"${MARIADB_USER:-sunset}" -p"${MARIADB_PASSWORD}" "${MARIADB_DATABASE:-sunsetmp}" < sql/06-taxi.sql 2>/dev/null || true
fi

# Optional deps (ox_lib, pma-voice)
if [ -f scripts/install-deps.sh ]; then
  sh scripts/install-deps.sh 2>/dev/null || true
fi

echo "Done. Connect: F8 -> connect $(curl -s ifconfig.me 2>/dev/null || echo YOUR_IP):30120"
