#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
developer="$(/usr/bin/xcode-select -p)"
swift="$developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="$developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
mkdir -p "$root/work/tmp" "$root/work/module-cache"
export TMPDIR="$root/work/tmp/"
export CLANG_MODULE_CACHE_PATH="$root/work/module-cache"
scratch="$(/usr/bin/mktemp -d "$root/work/test.XXXXXXXX")"
"$swift" -swift-version 5 -sdk "$sdk" -module-cache-path "$root/work/module-cache" -O \
    "$root/Sources/Staffing.swift" "$root/Tests/StaffingTests.swift" -o "$scratch/test"
"$scratch/test" "$root/Resources/Puzzles.json" "$scratch/profile" | tee "$scratch/results.log"
