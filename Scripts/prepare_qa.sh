#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
work="$(/usr/bin/mktemp -d "$root/work/qa.XXXXXXXX")"
app="$work/Does This Work QA.app"
plist="$app/Contents/Info.plist"
/usr/bin/ditto "$root/outputs/Does This Work? v0.3.app" "$app"
/usr/bin/plutil -replace CFBundleIdentifier -string com.doesthiswork.game.qa "$plist"
/usr/bin/plutil -replace CFBundleName -string 'Does This Work QA' "$plist"
/usr/bin/plutil -replace CFBundleDisplayName -string 'Does This Work QA' "$plist"
/usr/bin/plutil -insert IEQAProfile -string "$work/profile" "$plist"
/usr/bin/plutil -insert IEQALog -string "$work/events.log" "$plist"
/usr/bin/plutil -insert IEQAStations -integer "${2:-4}" "$plist"
if [[ "${1:-}" == smoke ]]; then
    /usr/bin/plutil -insert IEQASmoke -bool YES "$plist"
fi
/usr/bin/codesign --force --sign - "$app"
printf '%s\n' "$app"
