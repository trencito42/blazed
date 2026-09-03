#!/bin/sh
# Install optional third-party resources (ox_lib, ox_target, ox_inventory, pma-voice)
set -e
RES_DIR="$(cd "$(dirname "$0")/../resources" && pwd)"

clone_repo() {
  name="$1"
  url="$2"
  target="$RES_DIR/$name"
  if [ -d "$target" ]; then
    echo "[skip] $name already exists"
    return
  fi
  echo "[clone] $name"
  git clone --depth 1 "$url" "$target"
}

clone_repo ox_lib https://github.com/overextended/ox_lib.git
clone_repo ox_target https://github.com/overextended/ox_target.git
clone_repo ox_inventory https://github.com/overextended/ox_inventory.git
clone_repo pma-voice https://github.com/AvarianKnight/pma-voice.git

echo "Done. Uncomment ensures in config/server.cfg.template"
