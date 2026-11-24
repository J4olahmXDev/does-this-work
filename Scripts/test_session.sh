#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
developer="$(/usr/bin/xcode-select -p)"
swift="$developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="$developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
mkdir -p "$root/work/tmp" "$root/work/module-cache"
export TMPDIR="$root/work/tmp/"
export CLANG_MODULE_CACHE_PATH="$root/work/module-cache"
scratch="$(/usr/bin/mktemp -d "$root/work/session.XXXXXXXX")"
"$swift" -swift-version 5 -sdk "$sdk" -target "$(/usr/bin/uname -m)-apple-macos14.0" -module-cache-path "$root/work/module-cache" -O \
    "$root/Sources/Staffing.swift" "$root/Sources/Workshop.swift" "$root/Sources/GameSession.swift" "$root/Sources/Smoke.swift" \
    "$root/Tests/SessionTests.swift" "$root/Tests/FlowPaths.swift" -o "$scratch/test"
"$scratch/test" "$root/Resources" "$scratch"
