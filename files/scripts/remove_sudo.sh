#!/usr/bin/env bash
set -oue pipefail

SUDO_PACKAGES_TO_REMOVE=('sudo-python-plugin' 'sudo')
rpm-ostree override remove "${SUDO_PACKAGES_TO_REMOVE[@]}"

rm -rf /usr/bin/sudo