#!/usr/bin/env bash
# Downloads Voxel Tools 1.7 GDExtension (release tag v1.7x), verifies SHA256,
# and installs the desktop binaries into addons/zylann.voxel/bin/.
# Binaries are not committed (about 77 MB for desktop targets); run this after clone.
set -euo pipefail
URL="https://github.com/Zylann/godot_voxel/releases/download/v1.7x/GodotVoxelExtension.zip"
SHA256="600737572a5e25541ba6f503e842a3717ba19afafa5474510a6ceff995a1d2d8"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -sSL -o "$TMP/voxel.zip" "$URL"
echo "$SHA256  $TMP/voxel.zip" | sha256sum -c -
unzip -q "$TMP/voxel.zip" -d "$TMP/x"
SRC="$TMP/x/addons/zylann.voxel"
DST="$ROOT/addons/zylann.voxel"
mkdir -p "$DST/bin"
cp "$SRC/LICENSE.md" "$SRC/voxel.gdextension" "$SRC/voxel.gdextension.uid" "$DST/"
cp -r "$SRC/editor" "$DST/"
for f in \
  libvoxel.linux.editor.x86_64.so libvoxel.linux.template_release.x86_64.so \
  libvoxel.windows.editor.x86_64.dll libvoxel.windows.template_release.x86_64.dll \
  libvoxel.macos.editor.universal.framework libvoxel.macos.template_release.universal.framework; do
  cp -r "$SRC/bin/$f" "$DST/bin/"
done
echo "Voxel Tools GDExtension installed to $DST"
