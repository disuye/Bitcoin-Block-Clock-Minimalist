#!/bin/bash
# ─────────────────────────────────────────────────────────────
# build.sh — Bitcoin Block Clock
# Builds the .app (Swift/WKWebView) and .saver shim (Obj-C)
#
# Usage:
#   ./build.sh              Build release .app + .saver
#   ./build.sh debug        Build debug .app + .saver
#   ./build.sh run          Build debug + launch windowed
#   ./build.sh run-full     Build debug + launch fullscreen
#   ./build.sh install      Build release + install to ~/Library/Screen Savers
#   ./build.sh uninstall    Remove from ~/Library/Screen Savers
#   ./build.sh clean        Clean build artifacts
# ─────────────────────────────────────────────────────────────

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Bitcoin Block Clock"
BUNDLE_ID="com.bitcoinblockclock"
EXECUTABLE="BitcoinBlockClock"
SAVER_NAME="BitcoinBlockClock"
VERSION="2.0.0"

MODE="${1:-release}"
INSTALL_DIR="$HOME/Library/Screen Savers"

# ── Clean ──

if [[ "$MODE" == "clean" ]]; then
    echo "Cleaning..."
    rm -rf "$PROJECT_DIR/.build"
    rm -rf "$PROJECT_DIR/build"
    echo "Done."
    exit 0
fi

# ── Uninstall ──

if [[ "$MODE" == "uninstall" ]]; then
    echo "Uninstalling..."
    rm -rf "$INSTALL_DIR/${SAVER_NAME}.saver"
    rm -rf "$INSTALL_DIR/${APP_NAME}.app"
    echo "Removed from: $INSTALL_DIR"
    echo "You may need to restart System Settings to see the change."
    exit 0
fi

# ── Determine build config ──

case "$MODE" in
    debug|run|run-full)
        CONFIG="debug"
        SWIFT_FLAGS=""
        ;;
    install|release|*)
        CONFIG="release"
        SWIFT_FLAGS="-c release"
        ;;
esac

# ══════════════════════════════════════════════════════════════
# 1. Build the Swift .app via SPM
# ══════════════════════════════════════════════════════════════

echo "Building .app ($CONFIG)..."
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

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BINARY" "$MACOS/$EXECUTABLE"
cp -R "$PROJECT_DIR/Webview" "$RESOURCES/Webview"
cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES/AppIcon.icns"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

# ══════════════════════════════════════════════════════════════
# 2. Build the .saver shim (Objective-C, compiled with clang)
# ══════════════════════════════════════════════════════════════

echo "Building .saver shim..."

SAVER_DIR="$PROJECT_DIR/build/${SAVER_NAME}.saver"
SAVER_CONTENTS="$SAVER_DIR/Contents"
SAVER_MACOS="$SAVER_CONTENTS/MacOS"
SAVER_RESOURCES="$SAVER_CONTENTS/Resources"
SHIM_SRC="$PROJECT_DIR/ScreenSaverShim/BitcoinBlockClockShim.m"

rm -rf "$SAVER_DIR"
mkdir -p "$SAVER_MACOS" "$SAVER_RESOURCES"

# Compile the shim as a bundle (.saver is just a .bundle)
clang -fobjc-arc \
    -framework ScreenSaver \
    -framework Cocoa \
    -bundle \
    -mmacosx-version-min=12.0 \
    -o "$SAVER_MACOS/$SAVER_NAME" \
    "$SHIM_SRC"

# Generate .saver Info.plist
cat > "$SAVER_CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${SAVER_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}.saver</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSHumanReadableCopyright</key>
    <string>© disuye</string>
    <key>NSPrincipalClass</key>
    <string>BitcoinBlockClockShim</string>
</dict>
</plist>
PLIST

echo "Built: $SAVER_DIR"

# ══════════════════════════════════════════════════════════════
# 3. Run / Install
# ══════════════════════════════════════════════════════════════

case "$MODE" in
    run)
        echo ""
        echo "Launching windowed..."
        "$MACOS/$EXECUTABLE" --windowed --timezone=city
        ;;
    run-full)
        echo ""
        echo "Launching fullscreen..."
        "$MACOS/$EXECUTABLE" --timezone=city
        ;;
    install)
        echo ""
        echo "Installing to: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"

        # Remove old versions
        rm -rf "$INSTALL_DIR/${SAVER_NAME}.saver"
        rm -rf "$INSTALL_DIR/${APP_NAME}.app"

        # Copy both
        cp -R "$SAVER_DIR" "$INSTALL_DIR/"
        cp -R "$APP_DIR"   "$INSTALL_DIR/"

        echo "Installed:"
        echo "  $INSTALL_DIR/${SAVER_NAME}.saver  (shows in System Settings)"
        echo "  $INSTALL_DIR/${APP_NAME}.app       (launched by the .saver)"
        echo ""
        echo "Open System Settings > Screen Saver to select '${APP_NAME}'."
        echo "You may need to restart System Settings if it was already open."
        ;;
    *)
        echo ""
        echo "To install as a system screensaver:"
        echo "  ./build.sh install"
        echo ""
        echo "To test:"
        echo "  ./build.sh run           # windowed"
        echo "  ./build.sh run-full      # fullscreen"
        echo ""
        echo "To uninstall:"
        echo "  ./build.sh uninstall"
        ;;
esac
