#!/usr/bin/env bash
set -oue pipefail

NVIDIA_CONTAINER_TOOLKIT_VERSION=1.18.0-1
nvidia_packages_list=(nvidia-container-toolkit-${NVIDIA_CONTAINER_TOOLKIT_VERSION} nvidia-container-toolkit-base-${NVIDIA_CONTAINER_TOOLKIT_VERSION} libnvidia-container-tools-${NVIDIA_CONTAINER_TOOLKIT_VERSION} libnvidia-container1-${NVIDIA_CONTAINER_TOOLKIT_VERSION})

curl -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
    -o /etc/yum.repos.d/nvidia-container-toolkit.repo

# Disable verification
echo "%_pkgverify_level none" >/etc/rpm/macros.verify
dnf install -y --setopt=tsflags=nocrypto ${nvidia_packages_list[@]}
# Restore verification
rm /etc/rpm/macros.verify

echo "Downloading SELinux Policy"
curl -L https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp \
    -o nvidia-container.pp
echo "Installing SELinux Policy"
semodule -i nvidia-container.pp

echo "Cleaning up"
rm -f nvidia-container.pp
