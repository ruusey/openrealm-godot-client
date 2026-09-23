#!/usr/bin/env bash
# Validates the real game content: every sprite sheet the tables refer to has
# to resolve, through whichever source the client would use.
#
#   ./check-content.sh                       # the data repo on disk
#   ./check-content.sh --http=http://host:8080   # the data service
#
# The unit suite deliberately runs against a fixture directory that contains a
# broken sheet, so it cannot check this. Exits non-zero on any problem.
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot_mono_v4.7.2.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")"

"$GODOT" --headless --path . --script tests/tools/validate_content.gd -- "$@"
