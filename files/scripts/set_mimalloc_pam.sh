#!/usr/bin/env bash

set -oue pipefail

preload='libmimalloc.so.2 libno_rlimit_as.so'
pam_env='/etc/security/pam_env.conf'

if grep -q '^LD_PRELOAD DEFAULT=' "${pam_env}"; then
    sed -i "s|^LD_PRELOAD DEFAULT=.*$|LD_PRELOAD DEFAULT=\"${preload}\"|" "${pam_env}"
else
    printf 'LD_PRELOAD DEFAULT="%s"\n' "${preload}" >> "${pam_env}"
fi
