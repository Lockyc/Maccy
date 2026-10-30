# Fork tooling. Upstream has no justfile; keep fork-only build logic here, not in
# Maccy.xcodeproj, so upstream merges stay conflict-free.

# Developer ID team that signs local builds. A stable signature keeps the
# Accessibility grant (needed for paste) across rebuilds.
team := "G9V8U6ZU5E"
app := "build/Build/Products/Release/Maccy.app"
info_plist := "Maccy/Info.plist"
version := `cat VERSION`

# The fork's identity, applied over the project's upstream values at build time: its own
# bundle ID (so it installs beside upstream Maccy and never takes its updates) and its own
# version line (VERSION; upstream's MARKETING_VERSION and build number don't apply).
identity := "PRODUCT_BUNDLE_IDENTIFIER=com.lockyc.maccy MARKETING_VERSION=" + version + " CURRENT_PROJECT_VERSION=" + version

# `default` pipes `just --list` through a small stock-perl filter that clips long recipe
# docs to your terminal width (…) instead of wrapping. Self-contained — no external files;
# falls back to plain `just --list` where perl is absent. Edit the recipes below, not this.
# List available recipes
default:
    @if command -v perl >/dev/null 2>&1; then just --color always --list | perl -CS -Mutf8 -lpe 'BEGIN{($w)=`stty size 2>/dev/null </dev/tty`=~/ (\d+)/; $w||=100; $col=(-t STDOUT && !exists $ENV{NO_COLOR})} s/\e\[[0-9;]*m//g unless $col; (my $v=$_)=~s/\e\[[0-9;]*m//g; if(length($v)>$w){my($o,$n)=("",0); while(length && $n<$w-1){ if($col && s/^(\e\[[0-9;]*m)//){$o.=$1}else{s/^(.)//;$o.=$1;$n++} } $_=$o."…".($col?"\e[0m":"")}'; else just --list; fi

# Build a signed Release Maccy.app into build/
build:
    #!/usr/bin/env bash
    set -euo pipefail
    xcodebuild -project Maccy.xcodeproj -scheme Maccy -configuration Release \
      -derivedDataPath build -quiet \
      DEVELOPMENT_TEAM={{team}} CODE_SIGN_STYLE=Manual \
      CODE_SIGN_IDENTITY="Developer ID Application" PROVISIONING_PROFILE_SPECIFIER= \
      OTHER_CODE_SIGN_FLAGS=--timestamp CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO {{identity}} \
      build
    # (A plain `build` otherwise injects get-task-allow, which the notary rejects.)
    # Xcode re-signs Sparkle.framework but not the helpers inside it, which keep Sparkle's
    # ad-hoc signature and fail notarization. Inside-out: helpers, framework, then the app,
    # whose entitlements (the sandbox, Sparkle's mach-lookup exceptions) are kept as built.
    sign=(codesign --force --options runtime --timestamp --sign "Developer ID Application: Lachlan Collins ({{team}})")
    sparkle="{{app}}/Contents/Frameworks/Sparkle.framework"
    "${sign[@]}" "$sparkle/Versions/B/XPCServices/Installer.xpc"
    "${sign[@]}" --preserve-metadata=entitlements "$sparkle/Versions/B/XPCServices/Downloader.xpc"
    "${sign[@]}" "$sparkle/Versions/B/Autoupdate" "$sparkle/Versions/B/Updater.app" "$sparkle"
    "${sign[@]}" --preserve-metadata=entitlements,requirements,flags "{{app}}"

# The release build lockstep.sh notarizes: Developer ID, hardened runtime, secure timestamp
bundle: build

# Print the directory holding Sparkle's sign_update and generate_keys (resolving packages first)
sparkle-bin:
    @xcodebuild -resolvePackageDependencies -project Maccy.xcodeproj -scheme Maccy -derivedDataPath build -quiet >/dev/null
    @echo "{{justfile_directory()}}/build/SourcePackages/artifacts/sparkle/Sparkle/bin"

# Refuses while history under org.p0deje.Maccy awaits import: launching a local build first would
# create the new container and the installer would then (rightly) never import over it.
[private]
import-guard:
    @bash -c 'source ./install.sh; ! needs_import' || { echo "install: run ./install.sh first — it brings over your history; just install after that"; exit 1; }

# Build, then replace /Applications/Maccy.app and relaunch it
install: import-guard build
    -osascript -e 'quit app "Maccy"'
    for _ in $(seq 30); do pgrep -x Maccy >/dev/null || break; sleep 0.1; done
    pgrep -x Maccy >/dev/null && killall -9 Maccy || true
    while pgrep -x Maccy >/dev/null; do sleep 0.1; done
    rm -rf /Applications/Maccy.app
    ditto {{app}} /Applications/Maccy.app
    @# the commit this build came from: lets a later release (lockstep.sh) tell whether it is newer before replacing it
    xattr -w com.lockyc.build-commit "$(git rev-parse HEAD)$(git status --porcelain | grep -q . && echo -dirty)" /Applications/Maccy.app
    for _ in 1 2 3 4 5; do open /Applications/Maccy.app && break; sleep 1; done

# Pre-merge gate: the full unit-test suite, then the installer's lint and tests
gate: test
    shellcheck install.sh
    bats fork/install.bats

# Run the unit tests (ad-hoc signed; e.g. `just test MaccyTests/SharedStateTests/ClipboardTests` to narrow)
test only="MaccyTests":
    xcodebuild -project Maccy.xcodeproj -scheme Maccy -derivedDataPath build/test -quiet \
      DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- PROVISIONING_PROFILE_SPECIFIER= \
      -only-testing:{{only}} test

# Merge upstream master into dev (merge, never rebase: dev is pushed)
sync:
    @[ "$(git branch --show-current)" = dev ] || { echo "sync: run it on dev"; exit 1; }
    git fetch upstream
    git merge upstream/master

# List the upstream commits dev hasn't merged yet
upstream:
    @git fetch -q upstream
    @git log --oneline dev..upstream/master
