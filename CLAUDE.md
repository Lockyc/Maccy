# Maccy — lockyc fork

Personal fork of [p0deje/Maccy](https://github.com/p0deje/Maccy), released from here as
its own app: bundle ID `com.lockyc.maccy` and the version in `VERSION`, both applied by
`justfile` overrides (`identity`) over the project's upstream values.

## Branches

- `dev` — the trunk: upstream plus our patches. All work and upstream merges land here.
- `main` — the release branch and GitHub's default; `lockstep.sh release Maccy` fast-forwards
  it to `dev`. Never commit code to it.
- `upstream/master` (the remote-tracking ref) is the untouched upstream; `just upstream` lists
  what `dev` hasn't merged, `just sync` merges it into `dev` (merge, never rebase — `dev` is
  pushed and never force-pushed). The `upstream` remote fetches no tags: fork tags are `v*`,
  upstream's are bare, and only `v*` belong on origin.

Keep the diff against upstream small: fork-only files (`justfile`, `VERSION`, `install.sh`,
`.claude/commands/Maccy/`, `.github/README.md`, this file) are additions upstream never
touches, and build config goes in `justfile` overrides rather than `Maccy.xcodeproj`. A
fork test goes in an existing test file: a new file means a pbxproj edit.

## Build, install, release

`just build` · `just install` (replaces `/Applications/Maccy.app` and relaunches) ·
`just test`. `install.sh` installs the latest release (and on a first install imports the
history and settings of the old `org.p0deje.Maccy` container). A release is
`lockstep.sh release Maccy` from the fleet repo, through the interface `just gate`, `VERSION`,
`just bundle`, `info_plist` and `just sparkle-bin`; it publishes `Maccy.zip` and the
`appcast.xml` the app's `SUFeedURL` reads.

Signing is the Developer ID identity named by `team` in `justfile`. Changing the
signing identity invalidates the Accessibility grant, which Maccy needs to paste
(System Settings → Privacy & Security → Device Control and Data Access; opens
directly with `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`).

## Footguns

- **Sparkle feed and key.** `SUFeedURL` and `SUPublicEDKey` in `Maccy/Info.plist` are the
  fork's (this repo's releases, this fork's key). An upstream merge that touches either must
  keep the fork's values — upstream's would offer p0deje's builds, or reject every fork update.
