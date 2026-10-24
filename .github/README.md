# Maccy — lockyc fork

A fork of [p0deje/Maccy](https://github.com/p0deje/Maccy), the lightweight clipboard manager
for macOS, carrying a few patches of its own. It is its own app — bundle ID `com.lockyc.maccy`,
its own version line and its own releases — so it installs beside upstream Maccy and neither
updates the other. For upstream Maccy, go to [maccy.app](https://maccy.app).

## Differences from upstream

- **Trailing newlines stripped** when copying or pasting from history (setting, on by default).
- **Preview always shown** beside the popup (setting, on by default).
- **Lighter image history**: a TIFF copied alongside a PNG of the same image isn't stored
  (apps that ask for TIFF on paste still get one), and only the images on screen are loaded.
- **Its own releases and updates**: signed and notarized here, updated in-app by Sparkle from
  this repo's releases.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/lockyc/Maccy/main/install.sh | bash
```

Needs macOS 14 or later. The installer downloads the latest release, checks that it is signed by
this fork's developer and notarized by Apple, installs `/Applications/Maccy.app` and launches it.
It won't replace an upstream Maccy already in `/Applications` — move that to the Trash first. A
first install brings over the history and settings of an earlier fork build that ran under
upstream's bundle ID. Grant Maccy Accessibility (System Settings → Privacy & Security →
Accessibility) so it can paste. After that Maccy updates itself. From a clone of this repo,
Claude Code's `/Maccy:install` runs the same install.

## Upstream

Upstream is merged into this fork as it lands; a release follows when a fork change or a merged
upstream change is worth shipping. `just upstream` lists the upstream commits not yet merged.
Upstream's own README is at [`README.md`](../README.md).

## License

MIT, as upstream — see [`LICENSE`](../LICENSE).
