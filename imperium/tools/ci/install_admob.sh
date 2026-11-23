#!/usr/bin/env bash
# Installs the Poing Studios AdMob plugin into addons/admob and enables it, for CI / release builds.
# Usage: tools/ci/install_admob.sh <plugin-git-tag> [godot-version]
# The plugin is MIT licensed and is deliberately NOT vendored into this repository.
# The Android native library (.aar) is a separate release asset of the plugin; this script downloads it
# from the same release exactly like the plugin's own editor menu does (handlers/android_handler.gd).
set -euo pipefail
TAG="${1:?plugin tag, e.g. v5.1.0}"
GODOT_VERSION="${2:-4.7.2}"
WORK="$(mktemp -d)"
git clone --quiet --depth 1 --branch "$TAG" https://github.com/poingstudios/godot-admob-plugin.git "$WORK/plugin"
rm -rf addons/admob
mkdir -p addons
cp -r "$WORK/plugin/platforms/godot_editor/addons/admob" addons/admob
# native Android library for this Godot version (asset name taken from the plugin's android_handler.gd)
ZIP="android-template-v${GODOT_VERSION}.zip"
URL="https://github.com/poingstudios/godot-admob-plugin/releases/download/${TAG}/${ZIP}"
mkdir -p addons/admob/android/bin
curl -fL --retry 3 -o "$WORK/$ZIP" "$URL" || { echo "::error::could not download $URL (plugin $TAG may not ship binaries for Godot $GODOT_VERSION)"; exit 1; }
unzip -q -o "$WORK/$ZIP" -d addons/admob/android/bin
# enable the editor plugin (its EditorExportPlugin injects the AdMob library + manifest entries on export)
if ! grep -q "res://addons/admob/plugin.cfg" project.godot; then
  printf '\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/admob/plugin.cfg")\n' >> project.godot
fi
# AdMob *application* id (not the banner unit id). Falls back to the plugin default = Google's public TEST app id.
if [ -n "${ADMOB_ANDROID_APP_ID:-}" ]; then
  printf '\n[admob]\n\ngeneral/android/app_id="%s"\n' "$ADMOB_ANDROID_APP_ID" >> project.godot
fi
echo "AdMob plugin $TAG installed."
