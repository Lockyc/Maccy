# Maccy — lockyc fork

[![Release](https://img.shields.io/github/v/release/lockyc/Maccy?sort=semver&label=release)](https://github.com/lockyc/Maccy/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-555)
![Swift](https://img.shields.io/badge/swift-F05138?logo=swift&logoColor=white)
[![License](https://img.shields.io/github/license/lockyc/Maccy)](../LICENSE)

[Maccy](https://github.com/p0deje/Maccy), the lightweight clipboard manager for macOS, with a few
changes: trailing newlines stripped, the preview always open, lighter image history and faster
search on long histories. Pick this fork if those suit you. You give up installing with Homebrew
and upstream's own update channel, and an upstream change reaches you once it's merged here and
released. For upstream Maccy, go to [maccy.app](https://maccy.app).

## Differences from upstream

- **Trailing newlines stripped** when copying or pasting from history (a setting, on by default).
- **Preview always shown** beside the popup (a setting, on by default).
- **Lighter image history**: a TIFF copied alongside a PNG of the same image isn't stored (apps
  that ask for TIFF on paste still get one), and only the images on screen are loaded.
- **Faster search** on long histories, and the list and popup don't animate as you type.
- **Search can skip images**: turn off *Search text in images* to leave images out of results.
- **Its own app**: bundle ID `com.lockyc.maccy`, its own version line, and releases signed,
  notarized and delivered in-app by Sparkle from this repo. Neither it nor upstream ever updates
  the other.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/lockyc/Maccy/main/install.sh | bash
```

Needs macOS 14 or later. The installer downloads the latest release, checks that it is signed by
this fork's developer and notarized by Apple, installs `/Applications/Maccy.app` and launches it.
Both this fork and upstream install as `/Applications/Maccy.app`, so a Mac has one or the other:
the installer won't replace an upstream Maccy — move that to the Trash first. A first install
brings over the history and settings kept under upstream's bundle ID. Grant Maccy Accessibility
(System Settings → Privacy & Security → Accessibility) so it can paste. After that Maccy updates
itself.

## Using Maccy

Upstream's README, at [`README.md`](../README.md), covers using Maccy. Two things in it don't apply
here: its Install section installs upstream Maccy, not this fork, and where it says
`org.p0deje.Maccy` (in `defaults write` commands), this fork is `com.lockyc.maccy`.

## Development

Upstream is merged in as it lands, and a release follows when a fork change or a merged upstream
change is worth shipping. `just upstream` lists the upstream commits not yet merged. Conventions
and the release process: [CLAUDE.md](../CLAUDE.md).

## License

MIT, as upstream — see [LICENSE](../LICENSE).
