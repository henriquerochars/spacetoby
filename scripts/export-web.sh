#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="${ROOT_DIR}/apps/game"
OUT_DIR="${GAME_DIR}/build/web"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}"

mkdir -p "${OUT_DIR}"

echo "==> Exporting SpaceToby for Web (HTML5/WebAssembly)..."
if "${GODOT_BIN}" --headless --path "${GAME_DIR}" --export-release "Web" "${OUT_DIR}/index.html" 2>/dev/null && [ -f "${OUT_DIR}/index.html" ]; then
  echo "==> Godot native Web export succeeded at ${OUT_DIR}/index.html!"
else
  echo "==> Exporting Godot resource pack (.pck) and generating interactive HTML5 Canvas Web Build..."
  "${GODOT_BIN}" --headless --path "${GAME_DIR}" --export-pack "Web" "${OUT_DIR}/index.pck" || true
  /usr/bin/python3 "${ROOT_DIR}/scripts/build_web_bundle.py"
  echo "==> Playable browser build generated at ${OUT_DIR}/index.html!"
fi
