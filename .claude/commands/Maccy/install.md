You are installing or updating **Maccy (lockyc fork)** — a clipboard manager for the macOS menu bar.

## 1. Check the Mac

```bash
sw_vers -productVersion
```

Maccy needs macOS 14 or later. On an older Mac, say so and stop.

## 2. Upstream Maccy in the way?

```bash
[ -e /Applications/Maccy.app ] && codesign -dv /Applications/Maccy.app 2>&1 | grep TeamIdentifier
```

A `TeamIdentifier` other than `G9V8U6ZU5E` is upstream's Maccy, which the installer won't replace. Ask with AskUserQuestion whether to move it to the Trash; on yes, quit it and `mv /Applications/Maccy.app ~/.Trash/`. On no, stop.

## 3. Install

From a checkout (`[ -f install.sh ] && [ -f Maccy.xcodeproj/project.pbxproj ]`), ask with AskUserQuestion:
- **Latest release** (recommended): `bash install.sh`
- **This checkout's code**: `just install`

Outside a checkout, run `curl -fsSL https://raw.githubusercontent.com/lockyc/Maccy/main/install.sh | bash`.

If the installer needs `sudo`, the user types their password in this session: suggest `! <the command>`.

## 4. Done

Report the version (`/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' /Applications/Maccy.app/Contents/Info.plist`), whether the installer said it brought over history and settings, and that Maccy needs Accessibility to paste: System Settings → Privacy & Security → Accessibility, or `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`.
