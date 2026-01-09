#!/usr/bin/env bash

set -euo pipefail

sed -i '/^LD_PRELOAD DEFAULT="libhardened_malloc\.so libno_rlimit_as\.so"$/d' /etc/security/pam_env.conf
