#!/usr/bin/env bash
# Install the SELinux policy the NVIDIA container toolkit needs. The toolkit
# packages themselves are installed by the dnf module in packages-nvidia.yml.
set -oue pipefail

echo "Downloading SELinux Policy"
# Pinned to a commit and hash so a change upstream cannot alter the policy.
curl -fL https://raw.githubusercontent.com/NVIDIA/dgx-selinux/b988ea65e7b43009a705eb5e5d7e94048f916734/bin/RHEL9/nvidia-container.pp \
    -o nvidia-container.pp
echo "d131ebd51b74e5aae881ae88ae9670426e584036347aa5f346bf8448fe0256c7  nvidia-container.pp" | sha256sum --check --strict -
echo "Installing SELinux Policy"
semodule -i nvidia-container.pp

echo "Cleaning up"
rm -f nvidia-container.pp
