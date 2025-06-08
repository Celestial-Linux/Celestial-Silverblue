#!/usr/bin/env bash

set -oue pipefail

rm -rf nct6687d
git clone https://github.com/Fred78290/nct6687d.git
cd nct6687d

commitcount="$(git rev-list --all --count)"
commithash="$(git rev-parse --short HEAD)"

# Dependencies
echo "[*] Installing dependencies..."
# Capture currently installed packages to avoid removing pre-existing ones during cleanup
installed_before=$(rpm -qa --queryformat '%{NAME}\n' | sort)
dnf install -y @development-tools
dnf install -y rpmdevtools kmodtool
# Capture newly installed packages
installed_after=$(rpm -qa --queryformat '%{NAME}\n' | sort)
newly_installed=$(comm -13 <(echo "$installed_before") <(echo "$installed_after"))

# Setup directories
echo "[*] Preparing build directories..."
mkdir -p "$(pwd)/.tmp/nct6687d-1.0.${commitcount}/nct6687d"
cp LICENSE Makefile nct6687.c "$(pwd)/.tmp/nct6687d-1.0.${commitcount}/nct6687d"

# Create tarball
echo "[*] Creating source tarball..."
(
  mkdir -p .tmp
  cd .tmp
  tar -czvf "nct6687d-1.0.${commitcount}.tar.gz" "nct6687d-1.0.${commitcount}"
)

# Prepare RPM build tree
echo "[*] Preparing RPM build tree..."
mkdir -p "$(pwd)/.tmp/rpmbuild/"{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cp "$(pwd)/.tmp/nct6687d-1.0.${commitcount}.tar.gz" "$(pwd)/.tmp/rpmbuild/SOURCES/"
echo 'nct6687' | tee "$(pwd)/.tmp/rpmbuild/SOURCES/nct6687.conf"
cp fedora/*.spec "$(pwd)/.tmp/rpmbuild/SPECS/"

# Substitute variables in spec files
echo "[*] Patching spec files..."
sed -i "s/MAKEFILE_PKGVER/${commitcount}/g" "$(pwd)/.tmp/rpmbuild/SPECS/"*
sed -i "s/MAKEFILE_COMMITHASH/${commithash}/g" "$(pwd)/.tmp/rpmbuild/SPECS/"*

# Build RPM packages
echo "[*] Building RPM packages..."
rpmbuild -ba --define "_topdir $(pwd)/.tmp/rpmbuild" "$(pwd)/.tmp/rpmbuild/SPECS/nct6687d.spec"
rpmbuild -ba --define "_topdir $(pwd)/.tmp/rpmbuild" "$(pwd)/.tmp/rpmbuild/SPECS/nct6687d-kmod.spec"

# Install the resulting RPMs
echo "[*] Installing RPM packages..."
dnf install -y "$(pwd)/.tmp/rpmbuild/RPMS/"*/*.rpm

# Clean up
echo "[*] Cleaning up..."
if [ -n "$newly_installed" ]; then
    echo "[*] Removing newly installed development packages..."
    echo "$newly_installed" | xargs dnf remove -y
else
    echo "[*] No new packages to remove"
fi

echo "[✓] Build and installation complete!"
cd ..
rm -rf nct6687d

# ./sign_modules.sh "nct6687"
