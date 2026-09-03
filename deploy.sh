#!/bin/sh
# Deploy / update SunsetMP pe VPS (rulează din folderul serviciului Coolify)
set -e

REPO="${REPO:-https://github.com/trencito42/blazed}"
BRANCH="${BRANCH:-main}"
DIR="$(pwd)"

pull_repo() {
  if [ -d .git ]; then
    if GIT_TERMINAL_PROMPT=0 git fetch origin "$BRANCH" 2>/dev/null; then
      GIT_TERMINAL_PROMPT=0 git reset --hard "origin/$BRANCH"
      return 0
    fi
  fi

  echo "[deploy] git failed — using GitHub ZIP (repo public)"
  curl -fsSL -o /tmp/blazed.zip "${REPO}/archive/refs/heads/${BRANCH}.zip?$(date +%s)"
  rm -rf /tmp/blazed-main
  unzip -qo /tmp/blazed.zip -d /tmp
  rsync -a --delete /tmp/blazed-main/ "$DIR/"
}

pull_repo

chmod -R a+rX config docker resources sql
sed -i 's/\r$//' docker/fivem/entrypoint.sh deploy.sh
chmod +x docker/fivem/entrypoint.sh deploy.sh

docker compose build fivem
docker compose up -d --remove-orphans
docker compose up -d --force-recreate fivem

echo "Done. Connect: F8 -> connect $(curl -s ifconfig.me 2>/dev/null || echo YOUR_IP):30120"
