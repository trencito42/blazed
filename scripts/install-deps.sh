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

install_ox_lib() {
  target="$RES_DIR/ox_lib"
  if [ -f "$target/web/build/index.html" ]; then
    echo "[skip] ox_lib already installed (release build present)"
    return
  fi

  echo "[install] ox_lib from official release zip"
  rm -rf "$target"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  curl -fsSL -o "$tmpdir/ox_lib.zip" \
    https://github.com/overextended/ox_lib/releases/latest/download/ox_lib.zip
  unzip -qo "$tmpdir/ox_lib.zip" -d "$tmpdir"

  if [ -d "$tmpdir/ox_lib" ]; then
    mv "$tmpdir/ox_lib" "$target"
  else
    mkdir -p "$target"
    mv "$tmpdir"/* "$target/"
  fi

  if [ ! -f "$target/web/build/index.html" ]; then
    echo "[error] ox_lib install failed — web/build missing" >&2
    exit 1
  fi
}

install_ox_lib
clone_repo ox_target https://github.com/overextended/ox_target.git
clone_repo ox_inventory https://github.com/overextended/ox_inventory.git
clone_repo pma-voice https://github.com/AvarianKnight/pma-voice.git
clone_repo bob74_ipl https://github.com/Bob74/bob74_ipl.git

echo "Done. ox_lib uses release zip; other deps use git clone."
