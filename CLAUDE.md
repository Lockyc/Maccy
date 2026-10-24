# Maccy — lockyc fork

Personal fork of [p0deje/Maccy](https://github.com/p0deje/Maccy), built locally and
installed over the upstream app (same bundle ID `org.p0deje.Maccy`, so the sandbox
container's history and settings carry across).

## Branches

- `dev` — the trunk: upstream plus our patches. All work and upstream merges land here.
- `main` — the release branch and GitHub's default; `lockstep.sh release Maccy` fast-forwards
  it to `dev`. Never commit code to it.
- `upstream/master` (the remote-tracking ref) is the untouched upstream; `just upstream` lists
  what `dev` hasn't merged, `just sync` merges it into `dev` (merge, never rebase — `dev` is
  pushed and never force-pushed). The `upstream` remote fetches no tags: fork tags are `v*`,
  upstream's are bare, and only `v*` belong on origin.

Keep the diff against upstream small: fork-only files (`justfile`, `fork/`, this file)
are additions upstream never touches, and build config goes in `justfile` overrides
rather than `Maccy.xcodeproj`.

## Build & install

`just build` · `just install` (replaces `/Applications/Maccy.app` and relaunches) ·
`just test`

Signing is the Developer ID identity named by `team` in `justfile`. Changing the
signing identity invalidates the Accessibility grant, which Maccy needs to paste
(System Settings → Privacy & Security → Device Control and Data Access; opens
directly with `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`).

## Footguns

- **Sparkle feed.** `SUFeedURL` in `Maccy/Info.plist` points at `fork/appcast.xml`
  (an empty channel). An upstream merge that touches that key must keep the fork's
  value — upstream's feed would offer p0deje's release and overwrite the fork.
- **Homebrew.** The `maccy` cask must stay uninstalled; `brew upgrade` would replace
  the fork build.
