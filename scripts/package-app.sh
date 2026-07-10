#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=${VERSION:-0.2.0}
BUILD_NUMBER=${BUILD_NUMBER:-1}
SIGN_IDENTITY=${SIGN_IDENTITY:--}
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/Speak11.app"

rm -rf "$APP_DIR" "$DIST_DIR/Speak11.zip"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

swift build --package-path "$ROOT_DIR" -c release --arch arm64
BIN_DIR=$(swift build --package-path "$ROOT_DIR" -c release --arch arm64 --show-bin-path)
install -m 755 "$BIN_DIR/Speak11" "$APP_DIR/Contents/MacOS/Speak11"

sed \
    -e "s/__VERSION__/$VERSION/g" \
    -e "s/__BUILD_NUMBER__/$BUILD_NUMBER/g" \
    "$ROOT_DIR/Resources/Info.plist" > "$APP_DIR/Contents/Info.plist"

generate_icon() {
    local temp_dir iconset rendered size
    temp_dir=$(mktemp -d)
    iconset="$temp_dir/AppIcon.iconset"
    mkdir -p "$iconset"

    qlmanage -t -s 1024 -o "$temp_dir" "$ROOT_DIR/icon.svg" >/dev/null 2>&1
    rendered=$(find "$temp_dir" -maxdepth 1 -name '*.png' -print -quit)
    [ -n "$rendered" ] || return 1

    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$rendered" \
            --out "$iconset/icon_${size}x${size}.png" >/dev/null
        sips -z "$((size * 2))" "$((size * 2))" "$rendered" \
            --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -rf "$temp_dir"
}

if ! generate_icon; then
    echo "warning: app icon generation failed; packaging without a custom icon" >&2
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP_DIR"
else
    codesign --force --options runtime --timestamp \
        --entitlements "$ROOT_DIR/Resources/Speak11.entitlements" \
        --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

codesign --verify --strict "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$DIST_DIR/Speak11.zip"

echo "$APP_DIR"
echo "$DIST_DIR/Speak11.zip"
