#!/usr/bin/env bash

set -oue pipefail

policy_name='codex'
policy_source_dir='/usr/share/selinux/codex'
build_dir="$(mktemp -d)"

cleanup() {
    rm -rf "${build_dir}"
}
trap cleanup EXIT

selinux_policy_version="$(rpm -q --qf '%{version}-%{release}' selinux-policy)"

if ! rpm -q selinux-policy-devel >/dev/null 2>&1; then
    dnf install -y --setopt=install_weak_deps=False --enable-repo=updates-archive \
        "selinux-policy-devel-${selinux_policy_version}"
fi

cp "${policy_source_dir}/${policy_name}.te" "${build_dir}/${policy_name}.te"
cp "${policy_source_dir}/${policy_name}.fc" "${build_dir}/${policy_name}.fc"

(
    cd "${build_dir}"
    make -f /usr/share/selinux/devel/Makefile "${policy_name}.pp"
    semodule -v -X 300 -i "${policy_name}.pp"
)

restorecon -FRv /usr/bin/codex /usr/bin/codex-sandbox /usr/share/selinux/codex
