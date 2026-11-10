#!/usr/bin/env bash

# The base image preloads libhardened_malloc.so through /etc/ld.so.preload.
# Removing the hardened_malloc package leaves that entry pointing at a missing
# library, so every later process in the build prints an ld.so error. Drop the
# entry before the package goes away; the files module later installs our own
# /etc/ld.so.preload with mimalloc.

set -oue pipefail

preload='/etc/ld.so.preload'

if [[ -f "${preload}" ]]; then
    sed -i '/libhardened_malloc/d' "${preload}"
fi
