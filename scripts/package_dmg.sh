#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${1:-0.1.0}
BUILD_NUMBER=${2:-1}
APP_NAME="AgentGarden"
VOLUME_NAME="Agent Garden"
BUILD_ROOT="$ROOT_DIR/build"
APP_PATH="$BUILD_ROOT/${APP_NAME}.app"
DMG_PATH="$BUILD_ROOT/${APP_NAME}.dmg"
STAGING_DIR="$BUILD_ROOT/dmg-staging"

if [ ! -d "$APP_PATH" ]; then
  "$ROOT_DIR/scripts/package_app.sh" release "$VERSION" "$BUILD_NUMBER"
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "Created $DMG_PATH"
