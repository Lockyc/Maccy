#!/usr/bin/env bash
# install.sh — install the lockyc fork of Maccy from its latest GitHub release.
#   curl -fsSL https://raw.githubusercontent.com/lockyc/Maccy/main/install.sh | bash
# Installs /Applications/Maccy.app (bundle ID com.lockyc.maccy) and launches it; it updates
# itself from then on. On the first install it brings over the clipboard history and settings
# kept under upstream's bundle ID, org.p0deje.Maccy (where earlier fork builds kept them too).
# MACCY_ZIP_URL and MACCY_APP_DIR override the download and the install folder;
# MACCY_OLD_DATA and MACCY_NEW_DATA the two containers' Data/Library folders.
set -euo pipefail

zip_url=${MACCY_ZIP_URL:-https://github.com/lockyc/Maccy/releases/latest/download/Maccy.zip}
app_dir=${MACCY_APP_DIR:-/Applications}
old_data=${MACCY_OLD_DATA:-$HOME/Library/Containers/org.p0deje.Maccy/Data/Library}
new_data=${MACCY_NEW_DATA:-$HOME/Library/Containers/com.lockyc.maccy/Data/Library}
team=G9V8U6ZU5E
target="$app_dir/Maccy.app"
# Left in the new container while an import runs, so one that stops partway is retried.
import_marker=.lockyc-import-pending

fail() {
    echo "Maccy: $*" >&2
    exit 1
}

# Runs a command as the user, or with sudo when $1 (a directory) isn't writable.
in_dir() {
    local dir=$1
    shift
    if [ -w "$dir" ]; then "$@"; else sudo "$@"; fi
}

# Quits this fork's running Maccy, under either bundle ID, and waits for it to go.
quit_maccy() {
    pgrep -U "$(id -u)" -x Maccy >/dev/null || return 0
    pkill -U "$(id -u)" -x Maccy || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -U "$(id -u)" -x Maccy >/dev/null || return 0; sleep 0.5; done
    fail "Maccy didn't quit; quit it from its menu and re-run."
}

# Whether to import: there is old history, and the new container is either not made yet (a
# first install) or holds an import that didn't finish. Never over the new app's own data.
needs_import() {
    [ -d "$old_data/Application Support/Maccy" ] || return 1
    [ ! -d "$new_data" ] || [ -e "$new_data/$import_marker" ]
}

# Brings the clipboard history and settings of the org.p0deje.Maccy container into the new one.
# A sandboxed app can't read another app's container, so this runs here, unsandboxed: one hidden
# launch makes macOS create the new container, then the store is copied in and the settings go
# through `defaults import`, which writes via cfprefsd rather than behind its cache.
import_old_data() {
    echo "→ bringing over your history and settings"
    if [ ! -d "$new_data/Application Support" ]; then
        open -g -j "$target" || fail "$target didn't launch to create its data folder."
        for _ in $(seq 40); do [ -d "$new_data/Application Support" ] && break; sleep 0.25; done
        [ -d "$new_data/Application Support" ] || fail "Maccy's data folder never appeared at $new_data."
    fi
    touch "$new_data/$import_marker" || fail "couldn't write to $new_data."
    quit_maccy
    rm -rf "$new_data/Application Support/Maccy" || fail "couldn't clear $new_data/Application Support/Maccy."
    ditto "$old_data/Application Support/Maccy" "$new_data/Application Support/Maccy" ||
        fail "couldn't copy your history into $new_data. Re-run to try again."
    if [ -f "$old_data/Preferences/org.p0deje.Maccy.plist" ]; then
        defaults import "$new_data/Preferences/com.lockyc.maccy" "$old_data/Preferences/org.p0deje.Maccy.plist" ||
            fail "couldn't bring over your settings. Re-run to try again."
    fi
    rm -f "$new_data/$import_marker"
    echo "  imported from $old_data (left in place)"
}

main() {
    [ "$(uname)" = Darwin ] || fail "Maccy runs on macOS only."
    major=$(sw_vers -productVersion | cut -d. -f1)
    [ "$major" -ge 14 ] || fail "Maccy needs macOS 14 or later; this Mac runs $(sw_vers -productVersion)."

    # Only ever replace a Maccy this developer signed; an upstream install is someone else's app.
    if [ -e "$target" ] && ! codesign -dv "$target" 2>&1 | grep -qx "TeamIdentifier=$team"; then
        fail "$target is upstream's Maccy, not this fork. Quit it and move it to the Trash, then re-run."
    fi

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    echo "→ downloading Maccy"
    curl -fsSL "$zip_url" -o "$work/Maccy.zip" || fail "couldn't download $zip_url"
    ditto -x -k "$work/Maccy.zip" "$work/unzipped" || fail "the download isn't a zip."
    new="$work/unzipped/Maccy.app"
    [ -d "$new" ] || fail "the download holds no Maccy.app."
    [ -z "$(find "$work/unzipped" -maxdepth 1 -type l)" ] && [ ! -L "$new" ] ||
        fail "the download's Maccy.app is a link."
    codesign --verify --strict --deep "$new" 2>/dev/null || fail "the download's signature doesn't verify."
    info=$(codesign -dv "$new" 2>&1) || fail "the download's signature can't be read."
    printf '%s\n' "$info" | grep -qx "TeamIdentifier=$team" ||
        fail "the download isn't signed by this fork's developer."
    spctl --assess --type execute "$new" 2>/dev/null || fail "macOS won't open the download: it isn't notarized."
    version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$new/Contents/Info.plist")

    echo "→ quitting any running Maccy"
    quit_maccy

    echo "→ installing Maccy $version to $target"
    [ -d "$app_dir" ] || in_dir "$(dirname "$app_dir")" mkdir -p "$app_dir"
    staged="$app_dir/.Maccy.app.new"
    in_dir "$app_dir" rm -rf "$staged"
    in_dir "$app_dir" ditto "$new" "$staged" || fail "couldn't copy Maccy into $app_dir."
    old="$app_dir/.Maccy.app.old"
    in_dir "$app_dir" rm -rf "$old"
    if [ -e "$target" ]; then
        in_dir "$app_dir" mv "$target" "$old" ||
            fail "couldn't move the old $target aside. Allow your terminal in System Settings > Privacy & Security > App Management, or drag the old app to the Trash, then re-run."
    fi
    if ! in_dir "$app_dir" mv "$staged" "$target"; then
        [ ! -e "$old" ] || in_dir "$app_dir" mv "$old" "$target" || true
        fail "couldn't move Maccy into place at $target."
    fi
    in_dir "$app_dir" rm -rf "$old"

    if needs_import; then
        import_old_data
    fi

    open "$target" || fail "$target didn't launch."
    echo "✓ Maccy $version is in $target and running in the menu bar."
    echo "  Grant it Accessibility (System Settings > Privacy & Security > Accessibility) so it can paste."
}

# Sourced by fork/install.bats for needs_import; run (or piped to bash), it installs.
if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    main "$@"
fi
