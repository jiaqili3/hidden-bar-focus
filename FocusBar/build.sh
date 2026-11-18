#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
destination="${1:?Usage: FocusBar/build.sh /path/to/output-directory}"
mkdir -p "$destination"
destination="$(cd "$destination" && pwd)"
app="$destination/Hidden Bar Focus.app"
intermediates="$(mktemp -d)"
trap 'rm -rf "$intermediates"' EXIT
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
resources="$app/Contents/Resources"
cp "$root/FocusBar/Info.plist" "$app/Contents/Info.plist"
cp "$root/LICENSE" "$resources/LICENSE.txt"

# Use the exact HotKey revision from the upstream Xcode project's Package.resolved.
revision=c13662730cb5bc28de4a799854bbb018a90649bf
hotkey="${FOCUSBAR_HOTKEY_SOURCE:-$intermediates/HotKey}"
if [ ! -d "$hotkey" ]; then
    git clone --quiet https://github.com/soffes/HotKey.git "$hotkey"
    git -C "$hotkey" checkout --quiet "$revision"
fi
test "$(git -C "$hotkey" rev-parse HEAD)" = "$revision"
cp "$hotkey/LICENSE" "$resources/HotKey-LICENSE.txt"
sdk="$(xcrun --show-sdk-path)"
arch="$(uname -m)"
target="$arch-apple-macosx27.0"
native="$root/hidden/Features/StatusBar/Engine/Native"
xcrun swiftc -swift-version 5 -O -sdk "$sdk" -target "$target" -emit-library -static \
    -emit-module -emit-module-path "$intermediates/HotKey.swiftmodule" -module-name HotKey \
    "$hotkey"/Sources/HotKey/*.swift -o "$intermediates/libHotKey.a"
xcrun clang -isysroot "$sdk" -arch "$arch" -mmacosx-version-min=27.0 -fobjc-arc \
    -DHIDDENBAR_NATIVE_VISIBILITY=1 -c "$native/HBNativeVisibilityShim.m" -o "$intermediates/visibility.o"
sources=()
while IFS= read -r -d '' source; do sources+=("$source"); done < <(find "$root/hidden" -name '*.swift' -print0)
xcrun swiftc -swift-version 5 -O -whole-module-optimization -sdk "$sdk" -target "$target" \
    -D HIDDENBAR_NATIVE_VISIBILITY -D HIDDENBAR_FOCUS -I "$intermediates" -L "$intermediates" -lHotKey \
    -import-objc-header "$native/HBNativeVisibilityShim.h" "${sources[@]}" "$root"/FocusBar/*.swift \
    "$intermediates/visibility.o" -o "$app/Contents/MacOS/HiddenBarFocus"
mkdir "$intermediates/AppIcon.iconset"
for size in 16 32 128 256 512; do
    for scale in 1 2; do
        suffix=""
        if [[ "$scale" == 2 ]]; then suffix="@2x"; fi
        cp "$root/hidden/Assets.xcassets/AppIcon.appiconset/icon_${size}@${scale}x.png" \
            "$intermediates/AppIcon.iconset/icon_${size}x${size}${suffix}.png"
    done
done
iconutil -c icns "$intermediates/AppIcon.iconset" -o "$resources/AppIcon.icns"
for localization in "$root"/hidden/*.lproj; do
    if [ -f "$localization/Localizable.strings" ]; then cp -R "$localization" "$resources/"; fi
done
for asset in "$root"/hidden/Assets.xcassets/*.imageset; do
    name="$(basename "$asset" .imageset)"
    for file in "$asset"/*.png "$asset"/*.pdf; do
        if [ -f "$file" ]; then cp "$file" "$resources/$name.${file##*.}"; break; fi
    done
done
codesign --force --sign "${FOCUSBAR_SIGNING_IDENTITY:--}" "$app"
codesign --verify --deep --strict "$app"
printf '%s\n' "$app"
