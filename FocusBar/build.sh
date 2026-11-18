#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
destination="${1:?Usage: FocusBar/build.sh /path/to/output-directory}"
mkdir -p "$destination"
destination="$(cd "$destination" && pwd)"
app="$destination/Hidden Bar Focus.app"
intermediates="$(mktemp -d)"
trap 'rm -rf "$intermediates"' EXIT

status="$root/hidden/Features/StatusBar"
native="$status/Engine/Native"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$root/FocusBar/Info.plist" "$app/Contents/Info.plist"
cp "$root/LICENSE" "$app/Contents/Resources/LICENSE.txt"

sdk="$(xcrun --show-sdk-path)"
arch="$(uname -m)"
xcrun clang -isysroot "$sdk" -arch "$arch" -mmacosx-version-min=27.0 -fobjc-arc     -DHIDDENBAR_NATIVE_VISIBILITY=1 -c "$native/HBNativeVisibilityShim.m" -o "$intermediates/visibility.o"

xcrun swiftc -swift-version 5 -O -sdk "$sdk" -target "$arch-apple-macosx27.0"     -import-objc-header "$native/HBNativeVisibilityShim.h"     "$root/FocusBar/FocusBar.swift" "$root/FocusBar/SectionVisibility.swift"     "$root/hidden/Common/AppDefaults.swift" "$status/Layout/MenuBarLayout.swift"     "$status/Layout/AccessibilityMenuBarInventory.swift" "$native/NativeVisibilityBridge.swift"     "$intermediates/visibility.o" -o "$app/Contents/MacOS/HiddenBarFocus"

codesign --force --sign "${FOCUSBAR_SIGNING_IDENTITY:--}" "$app"
codesign --verify --deep --strict "$app"
printf '%s\n' "$app"
