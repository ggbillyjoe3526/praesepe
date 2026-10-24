#!/usr/bin/env bash
# Headless smoke test: imports the project, runs the game with `-- --smoke`
# (game/debug/smoke_run.gd) and fails on any script error or if the run never
# reports. Today it boots, ticks and quits; it grows to fly and dock.
# Usage: tools/smoke_test.sh            (GODOT=/path/to/godot to override)
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG="${SMOKE_LOG:-smoke.log}"
ERRORS="SCRIPT ERROR|Parse Error|Failed to load script"

"$GODOT" --headless --path . --import > import.log 2>&1
if grep -E "$ERRORS" import.log; then
  echo "FAIL: script errors while importing (see import.log)"; exit 1
fi

timeout 300 "$GODOT" --headless --path . -- --smoke --seed 1234 > "$LOG" 2>&1
status=$?
if grep -E "$ERRORS" "$LOG"; then
  echo "FAIL: script errors during the smoke run (see $LOG)"; exit 1
fi
if ! grep -q "^SMOKE: ok" "$LOG"; then
  tail -20 "$LOG"
  echo "FAIL: the smoke run never reported (exit $status, see $LOG)"; exit 1
fi
grep "^SMOKE: ok" "$LOG"
echo "PASS: smoke run with zero script errors"
