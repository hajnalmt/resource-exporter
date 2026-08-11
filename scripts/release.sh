#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  release.sh metadata <git-tag>
  release.sh generate-manifest <git-tag> <output-dir>
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
  generate-manifest)
    tag="${2:-}"
    output_dir="${3:-}"
    require_tag "$tag"
    if [[ -z "$output_dir" ]]; then
      echo "output directory must not be empty" >&2
      exit 1
    fi

    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    template="$repo_root/installer/numa-topo.yaml"
    output_file="$output_dir/resource-exporter-$tag.yaml"
    expected_image="volcanosh/numatopo:latest"
    replacement_image="volcanosh/numatopo:$tag"
    matches="$(awk -v needle="$expected_image" '
      {
        line = $0
        while ((position = index(line, needle)) > 0) {
          count++
          line = substr(line, position + length(needle))
        }
      }
      END { print count + 0 }
    ' "$template")"

    if [[ "$matches" -ne 1 ]]; then
      echo "expected exactly one '$expected_image' image in $template, found $matches" >&2
      exit 1
    fi

    mkdir -p "$output_dir"
    sed "s|$expected_image|$replacement_image|" "$template" > "$output_file"
    echo "$output_file"
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
