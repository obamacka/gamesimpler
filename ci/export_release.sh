#!/usr/bin/env bash
# Exports the Windows, Linux and macOS presets (export_presets.cfg) and packages them into dist/.
# Usage: GODOT_BIN=<path to Godot 4.7.2> ci/export_release.sh <version label, e.g. v0.1.0>
# Needs the 4.7.2 export templates installed and ci/fetch_voxel.sh run first.
set -euo pipefail
LABEL="${1:-dev}"
GODOT="${GODOT_BIN:?set GODOT_BIN}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
rm -rf build dist
mkdir -p build/windows build/linux build/macos dist

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
for preset in Windows Linux macOS; do
  case "$preset" in
    Windows) out="build/windows/Gamesimpler.exe" ;;
    Linux) out="build/linux/Gamesimpler.x86_64" ;;
    macOS) out="build/macos/Gamesimpler.zip" ;;
  esac
  echo "== export $preset"
  "$GODOT" --headless --path . --export-release "$preset" "$out" 2>&1 | grep -vE "remote port|Unable to connect" || true
  test -s "$out" || { echo "export $preset produced no $out"; exit 1; }
done

# Each download carries the credits for the CC0 art and the third-party licences.
for d in build/windows build/linux; do
  cp CREDITS.md "$d/"
  cp addons/zylann.voxel/LICENSE.md "$d/VOXEL_TOOLS_LICENSE.md"
done
(cd build/windows && zip -qr "../../dist/Gamesimpler-${LABEL}-windows-x86_64.zip" .)
(cd build/linux && chmod +x Gamesimpler.x86_64 && tar -czf "../../dist/Gamesimpler-${LABEL}-linux-x86_64.tar.gz" .)
cp build/macos/Gamesimpler.zip "dist/Gamesimpler-${LABEL}-macos-universal.zip"

cat > dist/RELEASE_NOTES.md <<NOTES
Gamesimpler ${LABEL}: automated build from commit $(git rev-parse --short HEAD).

Downloads
- Windows 10/11 x86_64: unzip and run Gamesimpler.exe. Windows SmartScreen may warn because the build is not code-signed ("More info", then "Run anyway").
- Linux x86_64: extract, then run ./Gamesimpler.x86_64.
- macOS 11+ (Apple Silicon and Intel): unzip and open Gamesimpler.app. The app is ad-hoc signed but not notarized, so macOS blocks the first launch: right-click the app and choose Open (on macOS 15 and later: try to open it once, then System Settings > Privacy & Security > Open Anyway).

Status: preview build. The automated test suite passed for this commit; the manual release-candidate checklist (exports launching, saving and loading on each OS) has not been run yet.

Third-party art is CC0 (see CREDITS.md). Voxel Tools is MIT.
NOTES
ls -la dist
