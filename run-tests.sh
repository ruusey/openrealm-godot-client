#!/usr/bin/env bash
# Runs the GUT suite. Pass -c / --coverage to also measure line coverage.
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot_mono_v4.7.2.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot not found at $GODOT -- set GODOT=/path/to/godot" >&2
	exit 1
fi

echo "== instrumenter self-test =="
python3 tools/test_instrumenter.py 2>&1 | tail -3

echo
echo "== GUT suite =="
"$GODOT" --headless --path . --import >/dev/null 2>&1
LOG="$(mktemp)"
# Script errors go to stderr, so both streams are kept.
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json 2>&1 | tee "$LOG"

# GUT counts a test that errored as passed, and a script that fails to parse
# as absent. Every SCRIPT ERROR is a test that never reached its assertions,
# and an unloaded script is a whole file of them. Neither is a green run, and
# none is exempt -- GUT's loader used to trip one on Godot 4.7, and it was
# patched rather than waved through (addons/gut/gut_loader.gd).
errors=$(grep -c "SCRIPT ERROR" "$LOG" || true)
unloaded=$(grep -c "Failed to load script" "$LOG" || true)
rm -f "$LOG"
if [[ "$errors" != "0" || "$unloaded" != "0" ]]; then
	echo "FAIL: $errors SCRIPT ERROR(s), $unloaded script(s) that failed to load -- see above" >&2
	exit 1
fi

if [[ "${1:-}" == "-c" || "${1:-}" == "--coverage" ]]; then
	echo
	echo "== coverage =="
	python3 tools/coverage.py --godot "$GODOT" --fail-under 95
fi
