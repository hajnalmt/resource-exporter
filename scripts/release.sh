#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  release.sh metadata <git-tag>
EOF
}

require_tag() {
  local tag="${1:-}"
  local pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?$'

  if [[ -z "$tag" ]]; then
    echo "release tag must not be empty" >&2
    exit 1
  fi
  if ! [[ "$tag" =~ $pattern ]]; then
    echo "invalid release tag: $tag" >&2
    exit 1
  fi

  local prerelease="${BASH_REMATCH[5]:-}"
  local identifier
  if [[ -n "$prerelease" ]]; then
    IFS='.' read -ra identifiers <<< "$prerelease"
    for identifier in "${identifiers[@]}"; do
      if [[ "$identifier" =~ ^[0-9]+$ && "$identifier" != "0" && "$identifier" == 0* ]]; then
        echo "invalid release tag: $tag" >&2
        exit 1
      fi
    done
  fi
}

command="${1:-}"

case "$command" in
  metadata)
    tag="${2:-}"
    require_tag "$tag"

    prerelease=false
    image_tags="$tag latest"
    if [[ "$tag" == *-* ]]; then
      prerelease=true
      image_tags="$tag"
    fi

    cat <<EOF
tag=$tag
version=$tag
prerelease=$prerelease
image_tags=$image_tags
EOF
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
