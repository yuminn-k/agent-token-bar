#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
CONFIGURATION=${1:-release}
VERSION=${2:-0.1.0}
BUILD_NUMBER=${3:-1}
APP_NAME="AgentGarden"
APP_DISPLAY_NAME="Agent Garden"
EXECUTABLE_NAME="TokenGarden"
BUILD_ROOT="$ROOT_DIR/build"
APP_DIR="$BUILD_ROOT/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$BUILD_ROOT/${APP_NAME}.app.zip"
RESOURCE_BUNDLE_PATH=$(find "$ROOT_DIR/.build/spm" -type d -path "*/${CONFIGURATION}/AgentGarden_TokenGarden.bundle" | head -n 1)
ICONSET_DIR="$BUILD_ROOT/${APP_NAME}.iconset"

mkdir -p "$BUILD_ROOT"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

BINARY_PATH=$(find "$ROOT_DIR/.build/spm" -type f -path "*/${CONFIGURATION}/${EXECUTABLE_NAME}" | head -n 1)
if [ -z "$BINARY_PATH" ]; then
  echo "Built binary not found for configuration: $CONFIGURATION" >&2
  exit 1
fi

cp "$BINARY_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ROOT_DIR/TokenGarden/Info.plist" "$CONTENTS_DIR/Info.plist"
if [ -n "$RESOURCE_BUNDLE_PATH" ]; then
  cp -R "$RESOURCE_BUNDLE_PATH" "$RESOURCES_DIR/"
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_16.png" "$ICONSET_DIR/icon_16x16.png"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_32.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_32.png" "$ICONSET_DIR/icon_32x32.png"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_64.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_128.png" "$ICONSET_DIR/icon_128x128.png"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_256.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_256.png" "$ICONSET_DIR/icon_256x256.png"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_512.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_512.png" "$ICONSET_DIR/icon_512x512.png"
cp "$ROOT_DIR/TokenGarden/Assets.xcassets/AppIcon.appiconset/icon_1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns -o "$RESOURCES_DIR/${APP_NAME}.icns" "$ICONSET_DIR"
rm -rf "$ICONSET_DIR"

/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $EXECUTABLE_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXECUTABLE_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_DISPLAY_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_DISPLAY_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_DISPLAY_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_DISPLAY_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$CONTENTS_DIR/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundlePackageType APPL" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string ${APP_NAME}" "$CONTENTS_DIR/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile ${APP_NAME}" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$CONTENTS_DIR/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Created $ZIP_PATH"
