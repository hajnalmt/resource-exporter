#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/release.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$file"; then
    echo "expected '$expected' in $file" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq "$unexpected" "$file"; then
    echo "did not expect '$unexpected' in $file" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_fails_with() {
  local expected="$1"
  shift
  if "$@" >"$tmpdir/out" 2>"$tmpdir/err"; then
    echo "command unexpectedly succeeded: $*" >&2
    exit 1
  fi
  assert_contains "$tmpdir/err" "$expected"
}

"$script" metadata "v1.2.3-rc.1" > "$tmpdir/prerelease.env"
assert_contains "$tmpdir/prerelease.env" "version=v1.2.3-rc.1"
assert_contains "$tmpdir/prerelease.env" "prerelease=true"
assert_contains "$tmpdir/prerelease.env" "image_tags=v1.2.3-rc.1"
assert_not_contains "$tmpdir/prerelease.env" "latest"

"$script" metadata "v1.2.3" > "$tmpdir/stable.env"
assert_contains "$tmpdir/stable.env" "prerelease=false"
assert_contains "$tmpdir/stable.env" "image_tags=v1.2.3 latest"

assert_fails_with "release tag must not be empty" "$script" metadata ""
assert_fails_with "invalid release tag" "$script" metadata "latest"
assert_fails_with "invalid release tag" "$script" metadata "v1.2.3-01"

echo "release helper tests passed"
