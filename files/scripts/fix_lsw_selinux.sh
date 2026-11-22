#!/usr/bin/env bash
# Let libvirt start LSW's bundled QEMU under SELinux.
#
# Even in session mode (qemu:///session), libvirt confines QEMU as svirt_t,
# and a process can only enter svirt_t by executing a qemu_exec_t file. The
# lsw RPM ships its QEMU as lib_t and points libvirt at a /usr/bin/sh wrapper
# labeled bin_t, so the exec fails with "cannot execute binary ...: Permission
# denied" before QEMU starts.
set -oue pipefail

qemu=/usr/lib/lsw/accel-virt/qemu/qemu-system-x86_64
wrapper=/usr/bin/lsw-qemu-system-x86_64

# Only the policy needs the rule: ostree labels files from the image's policy
# when it deploys them.
semanage fcontext -a -t qemu_exec_t "$qemu"

# The wrapper only execs $qemu by its resolved path. A symlink makes the kernel
# check the target's label, so svirt_t is entered straight from qemu_exec_t
# instead of through a shell it is not allowed to run.
ln -sf ../lib/lsw/accel-virt/qemu/qemu-system-x86_64 "$wrapper"
