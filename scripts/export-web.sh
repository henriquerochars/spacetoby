#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="${ROOT_DIR}/apps/game"
OUT_DIR="${GAME_DIR}/build/web"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}"
REQUIRED_VERSION="4.7.2"

if [[ ! -x "${GODOT_BIN}" ]]; then
  echo "ERROR: Godot executable not found at '${GODOT_BIN}'. Install Godot ${REQUIRED_VERSION} or set GODOT_BIN." >&2
  exit 1
fi

VERSION_OUTPUT="$("${GODOT_BIN}" --version)"
if [[ "${VERSION_OUTPUT}" != "${REQUIRED_VERSION}"* ]]; then
  echo "ERROR: Native release export requires Godot ${REQUIRED_VERSION}; found '${VERSION_OUTPUT}'." >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
rm -f "${OUT_DIR}/index.html" "${OUT_DIR}/index.js" "${OUT_DIR}/index.wasm" "${OUT_DIR}/index.pck"

echo "==> Exporting SpaceToby with Godot ${REQUIRED_VERSION} (native HTML5/WebAssembly)..."
if ! "${GODOT_BIN}" --headless --path "${GAME_DIR}" --export-release "Web" "${OUT_DIR}/index.html"; then
  echo "ERROR: Godot Web export failed. Confirm the Godot ${REQUIRED_VERSION} Web export templates are installed (the CI setup enables include-templates)." >&2
  exit 1
fi

missing=()
for artifact in index.html index.js index.wasm index.pck; do
  [[ -s "${OUT_DIR}/${artifact}" ]] || missing+=("${artifact}")
done
if ((${#missing[@]})); then
  echo "ERROR: Godot export did not produce required native Web artifacts: ${missing[*]}" >&2
  exit 1
fi

echo "==> Native Godot Web export succeeded at ${OUT_DIR}/index.html"
