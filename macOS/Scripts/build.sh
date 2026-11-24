#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
developer="$(/usr/bin/xcode-select -p)"
swift="$developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="$developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
host_arch="$(/usr/bin/uname -m)"
mkdir -p "$root/work/tmp" "$root/work/module-cache" "$root/outputs"
export TMPDIR="$root/work/tmp/"
export CLANG_MODULE_CACHE_PATH="$root/work/module-cache"
scratch="$(/usr/bin/mktemp -d "$root/work/build.XXXXXXXX")"
name='Does This Work?'
app="$scratch/$name.app"
contents="$app/Contents"
resources="$contents/Resources"
mkdir -p "$contents/MacOS" "$resources/Audio" "$resources/Fonts"
cp "$root/Resources/Puzzles.json" "$root/Resources/Workshop.json" "$resources/"
cp "$root"/Resources/Audio/*.wav "$resources/Audio/"
cp "$root"/Resources/Fonts/*.ttf "$root"/Resources/Fonts/*.txt "$resources/Fonts/"
if [[ -f "$root/Resources/AppIcon.icns" ]]; then cp "$root/Resources/AppIcon.icns" "$resources/"; fi
cat > "$contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key><string>Does This Work?</string>
    <key>CFBundleName</key><string>Does This Work?</string>
    <key>CFBundleExecutable</key><string>DoesThisWork</string>
    <key>CFBundleIdentifier</key><string>com.doesthiswork.game</string>
    <key>CFBundleVersion</key><string>7</string>
    <key>CFBundleShortVersionString</key><string>0.6</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>th</string></array>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
"$swift" -swift-version 5 -parse-as-library -sdk "$sdk" -target "$host_arch-apple-macos14.0" \
    -module-cache-path "$root/work/module-cache" -O \
    "$root"/Sources/*.swift -o "$contents/MacOS/DoesThisWork"
/usr/bin/plutil -lint "$contents/Info.plist"
/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --strict "$app"
destination="$root/outputs/$name.app"
if [[ -e "$destination" ]]; then
    archive="$(/usr/bin/mktemp -d "$root/work/previous.XXXXXXXX")"
    mv "$destination" "$archive/"
fi
mv "$app" "$destination"
printf '%s\n' "$destination"
