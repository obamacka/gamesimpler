#!/usr/bin/env bash
# One-command voxel benchmark for Linux and macOS (plan P0.8 b, d, j, k).
# Downloads and verifies Godot 4.7.2 and Voxel Tools 1.7, imports the project, runs
# spikes/voxel/voxel_benchmark.tscn windowed at 1920x1080 and prints a table row for
# _docs/reports/voxel_spike.md.
#
# Usage: ci/run_benchmark.sh --tier min|rec --machine "i7-3770 / GTX 1070" [--duration 60] [--headless-smoke]
#   --tier min  checks 30 fps (min spec), --tier rec checks 60 fps (recommended spec)
#   --headless-smoke  runs without a window (script check only; numbers are not valid results)
set -euo pipefail
TIER="min"; MACHINE="unnamed"; DURATION="60"; HEADLESS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="$2"; shift 2 ;;
    --machine) MACHINE="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    --headless-smoke) HEADLESS=1; shift ;;
    *) echo "unknown argument: $1"; exit 2 ;;
  esac
done
case "$TIER" in min|rec) ;; *) echo "--tier must be min or rec"; exit 2 ;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/.bench"
mkdir -p "$CACHE"
BASE="https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable"
case "$(uname -s)" in
  Linux)
    ZIP="Godot_v4.7.2-stable_linux.x86_64.zip"
    SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
    GODOT="$CACHE/Godot_v4.7.2-stable_linux.x86_64" ;;
  Darwin)
    ZIP="Godot_v4.7.2-stable_macos.universal.zip"
    SHA512="38aa16e5bba2083941fc5b3e54be0089bd4cc35e32415f5b9fd9a8a6a7b9818255d44532ea8ef94b5aef56c4b407c2d634fa4f657e4ebe681ebbf59b7bac69ca"
    GODOT="$CACHE/Godot.app/Contents/MacOS/Godot" ;;
  *) echo "unsupported OS; on Windows use ci/run_benchmark.ps1"; exit 2 ;;
esac

if [ ! -x "$GODOT" ]; then
  echo "Downloading $ZIP"
  curl -sSL -o "$CACHE/$ZIP" "$BASE/$ZIP"
  if command -v sha512sum > /dev/null; then
    (cd "$CACHE" && echo "$SHA512  $ZIP" | sha512sum -c -)
  else
    (cd "$CACHE" && echo "$SHA512  $ZIP" | shasum -a 512 -c -)
  fi
  (cd "$CACHE" && unzip -q -o "$ZIP" && rm "$ZIP")
  chmod +x "$GODOT"
fi
"$GODOT" --version

[ -n "$(ls -A "$ROOT/addons/zylann.voxel/bin" 2>/dev/null)" ] || "$ROOT/ci/fetch_voxel.sh"

echo "Importing project"
"$GODOT" --headless --path "$ROOT" --import > /dev/null 2>&1 || true

LOG="$CACHE/benchmark_$(date +%Y%m%d_%H%M%S).log"
ARGS=(--path "$ROOT")
if [ "$HEADLESS" = 1 ]; then ARGS+=(--headless); else ARGS+=(--resolution 1920x1080); fi
ARGS+=(res://spikes/voxel/voxel_benchmark.tscn -- "--duration=$DURATION" "--tier=$TIER" "--machine=$MACHINE")
echo "Running benchmark for ${DURATION}s (log: $LOG)"
"$GODOT" "${ARGS[@]}" 2>&1 | tee "$LOG"

echo
echo "Paste this row into _docs/reports/voxel_spike.md:"
grep -o '\[voxel_benchmark_row\] .*' "$LOG" | sed 's/^\[voxel_benchmark_row\] //' || { echo "benchmark row not found; see $LOG"; exit 1; }
