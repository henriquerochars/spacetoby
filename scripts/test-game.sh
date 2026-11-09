#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="${ROOT_DIR}/apps/game"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}"
TEST_LOG="$(mktemp)"
trap 'rm -f "${TEST_LOG}"' EXIT

echo "==> Using Godot binary: ${GODOT_BIN}"
"${GODOT_BIN}" --version

echo "==> Step 1: Importing Godot project assets headlessly..."
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --import 2>&1 | tee "${TEST_LOG}"
if grep -Eq 'SCRIPT ERROR:|^ERROR:' "${TEST_LOG}"; then
  echo "ERROR: Godot import reported errors." >&2
  exit 1
fi

echo "==> Step 2: Running SpaceToby Automated Headless Game Test Suite..."
"${GODOT_BIN}" --headless --path "${GAME_DIR}" --quit-after 3600 res://tests/TestRunner.tscn 2>&1 | tee "${TEST_LOG}"
# Godot can exit successfully after a script error; require a completed clean suite.
if grep -Eq 'SCRIPT ERROR:|^ERROR:' "${TEST_LOG}" || ! grep -Eq 'RESULTS: [0-9]+ Passed \| 0 Failed' "${TEST_LOG}"; then
  echo "ERROR: Godot tests did not complete cleanly." >&2
  exit 1
fi
