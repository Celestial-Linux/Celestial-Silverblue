#!/usr/bin/env bash

# Copyright 2025 Universal Blue
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

MODULE_NAME="${1-}"
if [ -z "$MODULE_NAME" ]; then
  echo "MODULE_NAME is empty. Exiting..."
  exit 1
fi

KERNEL_VERSION="$(rpm -q "kernel-cachyos-lto" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

PUBLIC_KEY_DER_PATH="../system/etc/pki/akmods/certs/akmods-celestial-linux.der"
PUBLIC_KEY_CRT_PATH="./certs/public_key.crt"
PRIVATE_KEY_PATH="./certs/private_key.priv"
SIGNING_KEY="./certs/signing_key.pem"

if [ ! -f "$PUBLIC_KEY_CRT_PATH" ]; then
    openssl x509 -in "$PUBLIC_KEY_DER_PATH" -out "$PUBLIC_KEY_CRT_PATH"
fi

cat "$PRIVATE_KEY_PATH" <(echo) "$PUBLIC_KEY_CRT_PATH" >> "$SIGNING_KEY"

# Function to sign a module
sign_module() {
    local module_path="$1"
    local module_basename="${module_path%.*}"
    local module_name=$(basename -- "${module_basename%.ko}")

    # Remove old signature if present
    if grep -Eq "^signature:" < <(modinfo "${module_name}"); then
        echo "Removing old sig"
        strip "${module_basename}"
    fi

    # Sign the module
    openssl cms -sign -signer "${SIGNING_KEY}" -binary -in "$module_basename" -outform DER -out "${module_basename}.cms" -nocerts -noattr -nosmimecap
    /usr/src/kernels/"${KERNEL_VERSION}"/scripts/sign-file -s "${module_basename}.cms" sha256 "${PUBLIC_KEY_CRT_PATH}" "${module_basename}"
    /bin/bash ./sign_check.sh "${KERNEL_VERSION}" "${module_basename}" "${PUBLIC_KEY_CRT_PATH}"
}

# Function to decompress a module based on extension
decompress_module() {
    local module="$1"
    local extension="$2"

    case "$extension" in
        "xz")
            xz --decompress "$module"
            ;;
        "gz")
            gzip -d "$module"
            ;;
        "zst")
            zstd -d "$module"
            ;;
    esac
}

# Function to compress a module based on extension
compress_module() {
    local module_basename="$1"
    local extension="$2"

    case "$extension" in
        "xz")
            xz -C crc32 -f "${module_basename}"
            ;;
        "gz")
            gzip -9f "${module_basename}"
            ;;
        "zst")
            zstd -19f "${module_basename}"
            ;;
    esac
}

for module in /usr/lib/modules/"${KERNEL_VERSION}"/"${MODULE_NAME}"/*.ko*; do
    module_basename="${module%.*}"
    module_extension="${module##*.}"
    module_name=$(basename -- "${module_basename%.ko}")

    # Skip .cms files
    if [[ "$module_basename" == *.cms ]]; then
        continue
    fi

    # Handle compressed modules
    if [[ "$module_extension" == "xz" || "$module_extension" == "gz" || "$module_extension" == "zst" ]]; then
        decompress_module "$module" "$module_extension"
        sign_module "$module"
        compress_module "$module_basename" "$module_extension"
    else
        sign_module "$module"
    fi
done
