#!/bin/sh
# Deploy / update SunsetMP pe VPS (rulează din folderul serviciului Coolify)
set -e

REPO="${REPO:-https://github.com/trencito42/blazed.git}"
BRANCH="${BRANCH:-main}"

if [ -d .git ]; then
  GIT_TERMINAL_PROMPT=0 git fetch origin "$BRANCH"
  GIT_TERMINAL_PROMPT=0 git reset --hard "origin/$BRANCH"
else
  GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$BRANCH" "$REPO" .
fi

chmod -R a+rX config docker resources sql
sed -i 's/\r$//' docker/fivem/entrypoint.sh
chmod +x docker/fivem/entrypoint.sh deploy.sh

docker compose build fivem
docker compose up -d --remove-orphans

echo "Done. Connect: F8 -> connect $(curl -s ifconfig.me 2>/dev/null || echo YOUR_IP):30120"
