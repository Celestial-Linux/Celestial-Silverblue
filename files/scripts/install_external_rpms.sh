#!/usr/bin/env bash
# Install the upstream RPMs listed in external-rpms.txt after verifying each
# file against its pinned SHA-256. These RPMs are unsigned, so the hash is the
# only integrity check they get.
set -oue pipefail

list="$(dirname "$0")/external-rpms.txt"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

rpms=()
while read -r sha url; do
    [[ -z "$sha" || "$sha" == \#* ]] && continue
    file="$workdir/$(basename "$url")"
    curl -fsSL --retry 3 -o "$file" "$url"
    echo "$sha  $file" | sha256sum --check --strict -
    rpms+=("$file")
done <"$list"

dnf install -y "${rpms[@]}"
