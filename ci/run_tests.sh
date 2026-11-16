#!/usr/bin/env bash
# Runs the full gdUnit4 suite headless. Requires GODOT_BIN (Godot 4.7.x).
# Uses --remote-debug tcp://127.0.0.1:0 so a GDScript parse error exits with
# code 105 instead of hanging at the local "debug>" prompt (verified in P0.3).
# Exit codes (gdUnit4 v6.2.3): 0 pass, 100 failures, 101 warnings,
# 103 headless not allowed, 105 script errors.
# The two "remote port"/"Unable to connect" ERROR lines this flag prints are expected.
set -u
: "${GODOT_BIN:?Set GODOT_BIN to a Godot 4.7.x binary}"
cd "$(dirname "$0")/.."
"$GODOT_BIN" --headless --path . --import > /dev/null 2>&1
"$GODOT_BIN" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://test "$@"
exit $?
