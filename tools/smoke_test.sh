#!/usr/bin/env bash
# Headless smoke test: imports the project, runs the game with `-- --smoke`
# (game/debug/smoke_run.gd) and fails on any script error, any engine or
# push_error() ERROR line (the known exit-time leak lines aside), or if the run
# never reports, then runs it again and fails unless both runs end the same.
# It flies, cruises, orbits, lands and docks on autopilot.
# Usage: tools/smoke_test.sh            (GODOT=/path/to/godot to override)
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG="${SMOKE_LOG:-smoke.log}"
ERRORS="SCRIPT ERROR|Parse Error|Failed to load script"
# Errors from the engine or push_error(); the leak report at exit is known noise.
errors_in() { grep -E "$ERRORS|^ERROR:" "$1" | grep -vE "leaked at exit|instances were leaked|resources still in use at exit"; }

"$GODOT" --headless --path . --import > import.log 2>&1
if errors_in import.log; then
  echo "FAIL: errors while importing (see import.log)"; exit 1
fi

# A script error that stops the run from quitting fails here after two minutes.
timeout 120 "$GODOT" --headless --fixed-fps 60 --path . -- --smoke --seed 1234 > "$LOG" 2>&1
status=$?
if errors_in "$LOG"; then
  echo "FAIL: errors during the smoke run (see $LOG)"; exit 1
fi
if ! grep -q "^SMOKE: ok" "$LOG"; then
  tail -20 "$LOG"
  echo "FAIL: the smoke run never reported (exit $status, see $LOG)"; exit 1
fi
grep "^SMOKE: ok" "$LOG"

# Seeds are law: a second run on the same seed must fly to exactly the same place.
timeout 120 "$GODOT" --headless --fixed-fps 60 --path . -- --smoke --seed 1234 > "$LOG.again" 2>&1
if errors_in "$LOG.again"; then
  echo "FAIL: errors during the second smoke run (see $LOG.again)"; exit 1
fi
if [ "$(grep "^SMOKE: ok" "$LOG")" != "$(grep "^SMOKE: ok" "$LOG.again")" ]; then
  grep "^SMOKE" "$LOG.again"
  echo "FAIL: a second run on the same seed ended differently (see $LOG.again)"; exit 1
fi
echo "PASS: smoke run with zero errors, the same on a second run"
