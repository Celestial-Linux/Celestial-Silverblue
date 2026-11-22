#!/usr/bin/env bash
# Build and install the SELinux module that lets libvirt run LSW's VMs
# confined as svirt_t. lsw-selinux/lsw.te explains each rule.
set -oue pipefail

src="$(dirname "$(readlink -f "$0")")/lsw-selinux"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cp "$src/lsw.te" "$src/lsw.fc" "$workdir/"
make -C "$workdir" -f /usr/share/selinux/devel/Makefile lsw.pp
semodule -i "$workdir/lsw.pp"

# libvirt execs /usr/bin/lsw-qemu-system-x86_64, a /usr/bin/sh wrapper that
# only execs the real binary by its resolved path. svirt_t can only be
# entered from a qemu_exec_t file and cannot run the shell, so a symlink
# makes the kernel check the binary's own label instead.
ln -sf ../lib/lsw/accel-virt/qemu/qemu-system-x86_64 /usr/bin/lsw-qemu-system-x86_64
