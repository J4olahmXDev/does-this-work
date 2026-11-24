#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
developer="$(/usr/bin/xcode-select -p)"
swift="$developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="$developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
mkdir -p "$root/work/module-cache" "$root/work/tmp"
export TMPDIR="$root/work/tmp/"
scratch="$(/usr/bin/mktemp -d "$root/work/workshop.XXXXXXXX")"
"$swift" -swift-version 5 -sdk "$sdk" -module-cache-path "$root/work/module-cache" -O \
    "$root/Sources/GameLanguage.swift" "$root/Sources/ThaiCopy.swift" "$root/Sources/Staffing.swift" "$root/Sources/Workshop.swift" \
    "$root/Tests/WorkshopTests.swift" "$root/Tests/FlowPaths.swift" -o "$scratch/test"
"$scratch/test" "$root/Resources/Workshop.json"
