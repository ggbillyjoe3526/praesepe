#!/usr/bin/env bash
# Unit tests (Gut, addons/gut): runs every test_*.gd under test/unit headless
# and fails if any test fails. Settings live in .gutconfig.json.
# Usage: tools/unit_tests.sh            (GODOT=/path/to/godot to override)
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG="${UNIT_LOG:-unit.log}"

if [ ! -d .godot ]; then
  "$GODOT" --headless --path . --import > import.log 2>&1
fi

timeout 300 "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd > "$LOG" 2>&1
status=$?
if grep -qE "SCRIPT ERROR|Parse Error" "$LOG"; then
  echo "FAIL: script errors during the unit tests (see $LOG)"; exit 1
fi
if [ "$status" -ne 0 ]; then
  grep -E "\[Failed\]|FAILED|Failed" "$LOG" | head -40
  echo "FAIL: unit tests failed (exit $status, see $LOG)"; exit 1
fi
grep -E "^(Tests|Passing Tests|Asserts)" "$LOG" || true
echo "PASS: unit tests"
