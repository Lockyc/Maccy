#!/usr/bin/env bats
# The installer's one-time import decision (fork-only; `just gate` runs it).

setup() {
  root=$(mktemp -d)
  # Through the installer's own overrides: sourcing it assigns old_data/new_data/import_marker from them.
  export MACCY_OLD_DATA="$root/old/Data/Library" MACCY_NEW_DATA="$root/new/Data/Library"
  export MACCY_IMPORT_MARKER="$root/installer/import-pending"
  old_data=$MACCY_OLD_DATA
  new_data=$MACCY_NEW_DATA
  # shellcheck source=/dev/null
  source "$BATS_TEST_DIRNAME/../install.sh"
}

teardown() { rm -rf "$root"; }

@test "imports on a first install: old history, no new container" {
  mkdir -p "$old_data/Application Support/Maccy"
  needs_import
}

@test "no import without old history (a stranger's first install)" {
  run needs_import
  [ "$status" -ne 0 ]
}

@test "no import once the new container holds its own data" {
  mkdir -p "$old_data/Application Support/Maccy" "$new_data/Application Support/Maccy"
  run needs_import
  [ "$status" -ne 0 ]
}

@test "an import that stopped partway is retried" {
  mkdir -p "$old_data/Application Support/Maccy" "$new_data" "$(dirname "$import_marker")"
  touch "$import_marker"
  needs_import
}

@test "a run stopped after the launch created the container, before the copy, is retried" {
  # The hidden launch made the container and an empty store; the marker was written first.
  mkdir -p "$old_data/Application Support/Maccy" "$new_data/Application Support/Maccy" "$(dirname "$import_marker")"
  touch "$import_marker"
  needs_import
}
