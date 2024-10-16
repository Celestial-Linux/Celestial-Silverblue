#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -euo pipefail

get_yaml_array FILES '.files[]' "$1"

shopt -s dotglob
 
if [[ ${#FILES[@]} -gt 0 ]]; then
    echo "Removing files from the image"
    for file in "${FILES[@]}"; do
      rm -f ${file}
    done
else
  echo "ERROR: You did not add any file to the module recipe for deletion,"
  echo "       Please assure that you performed this operation correctly"
  exit 1
fi

shopt -u dotglob