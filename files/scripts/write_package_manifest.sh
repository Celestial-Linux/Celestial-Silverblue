#!/usr/bin/env bash
# Record every installed package with the repo it came from, so a deployed
# system can be checked against what the build pulled in.
set -oue pipefail

dest=/usr/share/celestial-linux
mkdir -p "$dest"
dnf repoquery --installed --queryformat '%{full_nevra}\t%{from_repo}\n' |
    sort >"$dest/package-manifest.tsv"
