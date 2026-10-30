#!/bin/bash
# Builds dist/Motherload.app (and dist/Motherload.dmg with --dmg) on macOS.
#
# The app bundles the native Ruffle Flash Player (universal x86_64/arm64 binary)
# with the unmodified game/game.swf and a launcher script.
set -euo pipefail

RUFFLE_VERSION="0.7.1"
RUFFLE_SHA256="7a86a09b0ca1d5756abcbb093108265019d77edad79e91c98689126c940bea4e"
RUFFLE_URL="https://github.com/ruffle-rs/ruffle/releases/download/v${RUFFLE_VERSION}/ruffle-${RUFFLE_VERSION}-macos-universal.tar.gz"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
APP="$DIST/Motherload.app"
ARCHIVE="$BUILD/ruffle-${RUFFLE_VERSION}-macos-universal.tar.gz"

MAKE_DMG=0
for arg in "$@"; do
    case "$arg" in
        --dmg) MAKE_DMG=1 ;;
        *) echo "usage: $0 [--dmg]" >&2; exit 2 ;;
    esac
done

if [ "$(uname -s)" != "Darwin" ]; then
    echo "error: this script must run on macOS" >&2
    exit 1
fi

verify_archive() {
    echo "$RUFFLE_SHA256  $ARCHIVE" | shasum -a 256 -c - >/dev/null 2>&1
}

mkdir -p "$BUILD" "$DIST"
if [ ! -f "$ARCHIVE" ] || ! verify_archive; then
    echo "Downloading Ruffle $RUFFLE_VERSION"
    curl -fL --retry 3 -o "$ARCHIVE.part" "$RUFFLE_URL"
    mv "$ARCHIVE.part" "$ARCHIVE"
    if ! verify_archive; then
        echo "error: checksum mismatch for $ARCHIVE" >&2
        exit 1
    fi
fi

rm -rf "$BUILD/ruffle"
mkdir -p "$BUILD/ruffle"
tar -xzf "$ARCHIVE" -C "$BUILD/ruffle"

echo "Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/macos/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/macos/launcher.sh" "$APP/Contents/MacOS/Motherload"
cp "$BUILD/ruffle/Ruffle.app/Contents/MacOS/ruffle" "$APP/Contents/MacOS/ruffle"
chmod 755 "$APP/Contents/MacOS/Motherload" "$APP/Contents/MacOS/ruffle"
cp "$ROOT/game/game.swf" "$APP/Contents/Resources/game.swf"
cp "$ROOT/macos/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$BUILD/ruffle/LICENSE.md" "$APP/Contents/Resources/Ruffle-LICENSE.md"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# The release binary carries Ruffle.app's App Sandbox entitlements, which would
# confine it to a container and block reading the SWF passed on the command line.
# Re-sign ad hoc without entitlements, then seal the bundle.
codesign --force --sign - "$APP/Contents/MacOS/ruffle"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

if [ "$MAKE_DMG" = 1 ]; then
    echo "Creating $DIST/Motherload.dmg"
    STAGE="$BUILD/dmg"
    rm -rf "$STAGE" "$DIST/Motherload.dmg"
    mkdir -p "$STAGE"
    ditto "$APP" "$STAGE/Motherload.app"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -quiet -volname Motherload -srcfolder "$STAGE" -format UDZO "$DIST/Motherload.dmg"
fi

echo "Done: $APP"
