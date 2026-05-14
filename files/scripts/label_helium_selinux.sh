#!/usr/bin/env bash
set -euo pipefail

helium_dir="/usr/lib/opt/helium"

if [[ ! -x "${helium_dir}/helium-wrapper" ]]; then
    echo "Helium is not installed; skipping SELinux labeling."
    exit 0
fi

add_or_update_fcontext() {
    local type="$1"
    local pattern="$2"

    if semanage fcontext -a -t "${type}" "${pattern}" 2>/dev/null; then
        return
    fi

    semanage fcontext -m -t "${type}" "${pattern}"
}

# Reuse secureblue's Trivalent browser domain so Helium can keep Chromium's
# namespace sandbox while harden_userns blocks generic unconfined processes.
add_or_update_fcontext trivalent_script_exec_t "${helium_dir}/helium-wrapper"
add_or_update_fcontext trivalent_exec_t "${helium_dir}/(chrome|helium|helium_crashpad_handler)"

restorecon -v \
    "${helium_dir}/helium-wrapper" \
    "${helium_dir}/chrome" \
    "${helium_dir}/helium" \
    "${helium_dir}/helium_crashpad_handler"
