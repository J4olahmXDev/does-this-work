# Does This Work? · beta-v0.6 for Windows

Extract the entire Windows ZIP and open **Does This Work.exe**. The game runs offline on Windows x64 (Intel/AMD). Choose Settings → Language → ไทย for Thai. This beta uses the same settings and progress location as the first v0.6 Windows release.

This release uses **Does This Work?** as the title, and the filename omits the question mark to work on Windows. For the release notes, see the README in the combined beta-v0.6 package.

## Source

Run `node qa/test.mjs` to check the 360 reference solutions. With Python 3.11 or later, rebuild against the official runtime:

```sh
python3 package_windows.py electron-v45.4.1-win32-x64.zip "Does This Work - Windows.zip"
```

[Electron runtime and checksums](https://github.com/electron/electron/releases/tag/v45.4.1)
