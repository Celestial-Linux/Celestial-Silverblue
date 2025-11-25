#!/usr/bin/env bash

# Copyright 2025 The Secureblue Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.

set -oue pipefail

NVIDIA_CONTAINER_TOOLKIT_VERSION=1.18.0-1
nvidia_packages_list=(nvidia-container-toolkit-${NVIDIA_CONTAINER_TOOLKIT_VERSION} nvidia-container-toolkit-base-${NVIDIA_CONTAINER_TOOLKIT_VERSION} libnvidia-container-tools-${NVIDIA_CONTAINER_TOOLKIT_VERSION} libnvidia-container1-${NVIDIA_CONTAINER_TOOLKIT_VERSION} 'nvidia-driver-cuda' 'libnvidia-fbc' 'libva-nvidia-driver' 'nvidia-driver' 'nvidia-modprobe' 'nvidia-persistenced' 'nvidia-settings')

curl -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
    -o /etc/yum.repos.d/nvidia-container-toolkit.repo
sed -i "s@gpgcheck=0@gpgcheck=1@" /etc/yum.repos.d/nvidia-container-toolkit.repo

curl -L https://negativo17.org/repos/fedora-nvidia.repo -o /etc/yum.repos.d/negativo17-fedora-nvidia.repo

echo "Installing NVIDIA packages"
sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/nvidia-container-toolkit.repo
sed -i '0,/enabled=0/{s/enabled=0/enabled=1\npriority=90/}' /etc/yum.repos.d/negativo17-fedora-nvidia.repo

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
rm -f /etc/yum.repos.d/negativo17-fedora-nvidia.repo
rm -f /etc/yum.repos.d/nvidia-container-toolkit.repo
