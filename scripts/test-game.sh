#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="${ROOT_DIR}/apps/game"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}"

echo "==> Using Godot binary: ${GODOT_BIN}"
"${GODOT_BIN}" --version

echo "==> Step 1: Importing Godot project assets headlessly..."
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --import

echo "==> Step 2: Running SpaceToby Automated Headless Game Test Suite..."
"${GODOT_BIN}" --headless --path "${GAME_DIR}" res://tests/TestRunner.tscn
