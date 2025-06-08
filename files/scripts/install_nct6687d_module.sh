#!/usr/bin/env bash

set -oue pipefail

git clone https://github.com/Fred78290/nct6687d.git
cd nct6687d
make akmod
cd ..
rm -rf nct6687d

./sign_modules.sh "nct6687d"
