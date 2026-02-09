#!/bin/bash
# ─────────────────────────────────────────────────────────────
# build.sh — Bitcoin Block Clock
# Builds via Swift Package Manager, assembles .app bundle
#
# Usage:
#   ./build.sh              Build release .app bundle
#   ./build.sh debug        Build debug .app bundle
#   ./build.sh run          Build debug + launch windowed
#   ./build.sh run-full     Build debug + launch fullscreen
#   ./build.sh clean        Clean build artifacts
# ─────────────────────────────────────────────────────────────

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Bitcoin Block Clock"
BUNDLE_ID="com.bitcoinblockclock"
EXECUTABLE="BitcoinBlockClock"
VERSION="2.0.0"

MODE="${1:-release}"

# ── Clean ──

if [[ "$MODE" == "clean" ]]; then
    echo "Cleaning..."
    rm -rf "$PROJECT_DIR/.build"
    rm -rf "$PROJECT_DIR/build"
    echo "Done."
    exit 0
fi

# ── Determine build config ──

case "$MODE" in
    debug|run|run-full)
        CONFIG="debug"
        SWIFT_FLAGS=""
        ;;
    release|*)
        CONFIG="release"
        SWIFT_FLAGS="-c release"
        ;;
esac

# ── Build ──

echo "Building ($CONFIG)..."
cd "$PROJECT_DIR"
swift build $SWIFT_FLAGS 2>&1

BINARY="$PROJECT_DIR/.build/$CONFIG/$EXECUTABLE"

if [[ ! -f "$BINARY" ]]; then
    echo "ERROR: Build failed — binary not found at $BINARY"
    exit 1
fi

echo "Binary: $BINARY"

# ── Assemble .app bundle ──

APP_DIR="$PROJECT_DIR/build/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Assembling ${APP_NAME}.app ..."

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp "$BINARY" "$MACOS/$EXECUTABLE"

# Copy Webview resources
cp -R "$PROJECT_DIR/Webview" "$RESOURCES/Webview"
cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES/AppIcon.icns"

# Generate Info.plist
cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© disuye</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

echo "Built: $APP_DIR"

# ── Run (if requested) ──

case "$MODE" in
    run)
        echo "Launching windowed..."
        "$MACOS/$EXECUTABLE" --windowed --timezone=city
        ;;
    run-full)
        echo "Launching fullscreen..."
        "$MACOS/$EXECUTABLE" --timezone=city
        ;;
    *)
        echo ""
        echo "To run:"
        echo "  open \"$APP_DIR\"                              # fullscreen (screensaver)"
        echo "  \"$MACOS/$EXECUTABLE\" --windowed --timezone=city   # windowed (debug)"
        echo ""
        echo "To install as auto-start screensaver:"
        echo "  cp -R \"$APP_DIR\" /Applications/"
        echo "  Then add to Login Items in System Settings > General > Login Items"
        ;;
esac
