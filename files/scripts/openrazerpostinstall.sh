#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

echo '

omit_dracutmodules+=" razerkbd "

' > /usr/lib/dracut/dracut.conf.d/99-omit-razerkbd.conf


KERNEL_VERSION=$(skopeo inspect docker://ghcr.io/ublue-os/akmods:main-41 | jq -r '.Labels["ostree.linux"]')
depmod -a -v "${KERNEL_VERSION}"