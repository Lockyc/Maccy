# Maccy — personal fork

A personal fork of [p0deje/Maccy](https://github.com/p0deje/Maccy), the lightweight
clipboard manager for macOS. It carries a few local patches and is built from source for
one machine. **No builds or releases are published here — get Maccy from
[maccy.app](https://maccy.app).**

## Differences from upstream

- **Trailing newlines stripped** when copying or pasting from history (setting, on by default).
- **Preview always shown** beside the popup (setting, on by default).
- **Lighter image history**: a TIFF copied alongside a PNG of the same image isn't stored
  (apps that ask for TIFF on paste still get one), and only the images on screen are loaded.
- **Updates come from this fork's own Sparkle feed** (`fork/appcast.xml`), so upstream releases
  never overwrite a local build.
- A `justfile` for building, signing and installing locally (`just build`, `just install`,
  `just test`).

`master` mirrors upstream; `main` is upstream plus these patches, with upstream merged in
regularly. Upstream's README is at [`README.md`](../README.md).

## License

MIT, as upstream — see [`LICENSE`](../LICENSE).
