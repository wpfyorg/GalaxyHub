#!/bin/zsh
# Builds Buds Hub.app into ./build. No Xcode project needed.
set -euo pipefail
cd "${0:A:h}"

# macOS 26.5 SDK is used only with Command Line Tools: the CLT 27 SDK ships
# SwiftUI as macros without the SwiftUIMacros host plugin. Full Xcode keeps its
# own selected SDK even when the CLT SDK directory exists.
DEVELOPER_DIR_PATH="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVELOPER_DIR_PATH" == *"CommandLineTools"* ]] && [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi

# swiftc forwards the SDK to clang as --sysroot. clang then cannot infer the
# SDK version and ld records the deployment target instead (LC_BUILD_VERSION
# "sdk 14.0"), which puts macOS 26+ into legacy appearance mode. Pass the real
# SDK version explicitly; the minimum stays the package's macOS 14 target.
if [[ -n "${SDKROOT:-}" ]]; then
    SDK_VERSION="$(plutil -extract Version raw "$SDKROOT/SDKSettings.plist" 2>/dev/null || true)"
fi
SDK_VERSION="${SDK_VERSION:-$(xcrun --sdk macosx --show-sdk-version)}"

echo "Building BudsHub (SDK $SDK_VERSION)…"
swift build -c release --product BudsHub \
    -Xlinker -platform_version -Xlinker macos -Xlinker 14.0 -Xlinker "$SDK_VERSION"

APP=build/BudsHub.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/release/BudsHub" "$APP/Contents/MacOS/BudsHub"

# App icon, drawn once by tools/MakeIcon.swift.
if [[ ! -f build/AppIcon.icns ]]; then
    rm -rf build/AppIcon.iconset
    swiftc -O -swift-version 5 tools/MakeIcon.swift -o build/MakeIcon
    build/MakeIcon build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>BudsHub</string>
    <key>CFBundleDisplayName</key><string>Buds Hub</string>
    <key>CFBundleIdentifier</key><string>io.github.budshub</string>
    <key>CFBundleExecutable</key><string>BudsHub</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Buds Hub talks to your Galaxy Buds to read battery, switch noise control and change sound settings.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>Buds Hub talks to your Galaxy Buds over Bluetooth.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Protocol knowledge from GalaxyBudsClient (GPLv3). UI patterns from BudsControl (MIT).</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"
